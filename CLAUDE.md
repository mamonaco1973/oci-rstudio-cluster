# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

Deploys an RStudio Server cluster on OCI backed by a Samba 4 mini-AD domain and OCI File Storage Service (FSS). Four-phase build:

1. `01-directory` — VCN, subnets (vm, cluster, management), OCI Bastion, Samba 4 AD DC (module-oci-mini-ad), SSH keys, passwords
2. `02-servers` — FSS file system + mount target, Linux Samba gateway (Ubuntu, public IP), Windows Server 2022 AD client
3. `03-packer` — Builds `rstudio-image` custom OCI image: R (CRAN latest), RStudio Server, AD/NFS packages
4. `04-cluster` — OCI flexible Load Balancer (port 80), Instance Pool (E4.Flex 2c/8GB, private cluster-subnet), autoscaling

Supporting directories (not deployed by Terraform):
- `05-rsamples` — Sample R scripts demonstrating shared library usage
- `06-utils` — PowerShell/bat scripts for next available UID/GID from the AD

## Commands

```bash
./apply.sh               # validate env, run all 4 phases
./destroy.sh             # destroy 04-cluster, delete Packer image, destroy 02-servers, destroy 01-directory
./connect.sh             # OCI Bastion port-forward + SSH tunnel to DC
./get_password.sh <user> # print username + password from tfstate
./validate.sh            # print IPs, SSH command, LB URL
./check_env.sh           # validate oci/terraform/packer/jq in PATH + OCI CLI auth
```

## Architecture

```
01-directory/
  networking.tf    — VCN, IGW, NAT, route tables, security lists; subnets:
                     vm-subnet (10.0.0.64/26, public/IGW),
                     cluster-subnet (10.0.0.128/26, private/NAT)
  ad.tf            — module-oci-mini-ad invocation, users_json locals, outputs
                     including vm_subnet_ocid and cluster_subnet_ocid
  accounts.tf      — tls_private_key (RSA 4096), admin/windows random_password,
                     user passwords as memorable word-NNNNNN
  bastion.tf       — oci_bastion_bastion (STANDARD type, free)
  variables.tf     — compartment_ocid, tenancy_ocid, domain vars
  scripts/users.json.template — AD users/groups including rstudio-admins (gid 10005)

02-servers/
  main.tf          — OCI provider, remote_state from 01-directory, image data sources,
                     locals for compartment/vcn/subnet OCIDs and credentials
  fss.tf           — FSS file system (rstudio-fss), mount target in vm-subnet, /nfs export
                     output: mount_target_ip
  linux.tf         — Ubuntu E4.Flex 1c/4GB Samba gateway, public IP,
                     templatefile userdata.sh (admin_password/domain_fqdn/
                     domain_fqdn_upper/netbios/dc_ip/mt_ip)
  windows.tf       — Windows Server 2022 E4.Flex 2c/8GB, rdp_nsg,
                     templatefile userdata.ps1 (samba_server=linux private IP)
  security_groups.tf — ssh_nsg (22), rdp_nsg (3389), smb_nsg (445 from vm-subnet)
  outputs.tf       — linux_public_ip, linux_private_ip, mount_target_ip
  scripts/userdata.sh  — apt lock fix, FSS NFS mount, /home→/nfs/home symlink,
                         realm join (samba membership), SSSD, Samba ADS config,
                         /etc/skel/nfs symlink set BEFORE user creation loop,
                         git clone oci-rstudio-cluster.git to /nfs
  scripts/userdata.ps1 — NLA, local admin, IPv6 disable, RSAT, domain join,
                         DNS suffix, Z: drive bat to \\samba_server\nfs

03-packer/
  rstudio_image.pkr.hcl — oracle-oci source, E4.Flex 4c/16GB, 64 GB disk,
                           image_name=rstudio-image; 3 provisioners only
  packages.sh      — apt lock fix, AD/NFS packages, R dev libraries (phases 1-6)
  ocicli.sh        — OCI CLI into /opt/oci-venv (avoids urllib3 conflict)
  rstudio.sh       — CRAN repo, r-base, RStudio Server (jammy deb),
                     /etc/pam.d/rstudio (SSSD auth + mkhomedir helper),
                     /etc/skel/nfs symlink baked in

04-cluster/
  main.tf          — OCI provider, remote_state from BOTH 01-directory and 02-servers;
                     locals include mount_target_ip from servers state
  lb.tf            — OCI flexible LB (10-100 Mbps), lb_cookie sticky session
                     (RSTUDIO_SESSION, 86400s), health check return_code=302 port 8787,
                     HTTP listener port 80
  instance_pool.tf — Instance Configuration (E4.Flex 2c/8GB, cluster_subnet,
                     assign_public_ip=false), Instance Pool (size=2, ignore_changes=[size]),
                     LB attachment port 8787; autoscaling CPU>60% +1, CPU<10% -1,
                     min=2 max=4, cooldown=300s
  security_groups.tf — cluster_nsg (8787 from LB subnet, SSH from VCN CIDR)
  outputs.tf       — lb_public_ip
  scripts/rstudio_booter.sh — cloud-init for cluster instances: IPv6 disable,
                     apt lock fix, iptables open, FSS NFS mount, /home→/nfs/home,
                     realm join (adcli membership), SSSD tweaks (access_provider=simple,
                     force_group=rstudio-users), /etc/skel/nfs symlink,
                     RStudio restart+enable, Rprofile.site (/nfs/rlibs in .libPaths()),
                     chgrp rstudio-admins /nfs/rlibs
```

Module source: `github.com/mamonaco1973/module-oci-mini-ad`

## Auth and Variable Wiring

- OCI auth: `~/.oci/config` DEFAULT profile — no credentials in code
- Compartment: `OCI_COMPARTMENT_ID` env var → `TF_VAR_compartment_ocid`
- Tenancy: extracted from `~/.oci/config` → `TF_VAR_tenancy_ocid`
- Packer image OCID: resolved by `apply.sh` after Packer build → `TF_VAR_rstudio_image_ocid`
- Passwords: sensitive outputs in tfstate — retrieve with `./get_password.sh <user>`
- Valid users: `admin`, `jsmith`, `edavis`, `rpatel`, `akumar`, `windows_local_admin`, `ubuntu`

## Password Design

- Admin and `windows_local_admin`: 24-char random with `override_special="_-."`, prefixed `"A${...}"` for AD uppercase requirement
- AD users (`jsmith`, `edavis`, `rpatel`, `akumar`): `word-NNNNNN` format via `random_shuffle` + `random_integer` — memorable, meets AD complexity

## Packer Image

- Plugin: `hashicorp/oracle` (`oracle-oci` source)
- Base: latest Canonical Ubuntu 24.04 for VM.Standard.E4.Flex — resolved by `apply.sh` via OCI CLI
- Build subnet: vm-subnet (public IP assigned — needs internet for apt)
- Image name: `rstudio-image` (fixed name — `apply.sh` finds it by exact display-name match via jq)
- Rebuilding overwrites the previous image; `destroy.sh` deletes it explicitly via OCI CLI

## FSS Architecture

```
vm-subnet (10.0.0.64/26, public)
  ├── Linux Samba gateway ──NFS──▶  Mount Target (FSS)
  │     └── Samba [nfs] share            └── /nfs export
  └── Windows AD client   ──SMB──▶  \\<linux-private-ip>\nfs → Z:

cluster-subnet (10.0.0.128/26, private/NAT)
  └── Instance Pool (RStudio nodes) ──NFS──▶  same Mount Target
        └── /home → /nfs/home (AD user homes persist across scale events)
```

- FSS NFS security rules: TCP/UDP 111, TCP 2048-2050, UDP 2048 from vm-subnet and cluster-subnet
- `/home` → `/nfs/home` symlink on both Samba gateway and cluster instances
- `/nfs/rlibs` — shared R library; `chgrp rstudio-admins`, `chmod 775`
- `Rprofile.site` injects `/nfs/rlibs` into `.libPaths()` at RStudio startup

## /etc/skel/nfs Symlink

Both `02-servers/scripts/userdata.sh` and `04-cluster/scripts/rstudio_booter.sh` set
`ln -sf /nfs /etc/skel/nfs` **before** the user creation loop. This ensures every AD
user gets `~/nfs → /nfs` when mkhomedir creates their home directory, making shared
data and R samples immediately visible in the RStudio file browser. It is also baked
into the Packer image via `03-packer/rstudio.sh` for new users who log in after boot.

## RStudio LB Health Check

OCI LB health check uses `return_code=302` on port 8787 — RStudio redirects unauthenticated
requests to its login page rather than returning 200, so 302 is the correct healthy status.

## Samba / Winbind Notes

- SSSD handles Linux PAM/NSS (login, ssh). Winbind handles SMB auth for Windows clients.
- `nsswitch.conf`: `passwd: files sss winbind`, `group: files sss winbind`
- `idmap config MCLOUD : backend = sss` — Winbind delegates UID/GID to SSSD
- Samba NetBIOS name derived from hostname (uppercase, ≤15 chars)
- Samba gateway uses `--membership-software=samba`; cluster instances use `--membership-software=adcli`

## SSSD Access Restriction on Cluster Nodes

`rstudio_booter.sh` sets `access_provider = simple` with `simple_allow_groups = rstudio-users`
in sssd.conf. Only members of `rstudio-users` can log in to cluster instances. The Samba
gateway has no access restriction — all domain users can SSH there.

## Known OCI Quirks

- **cloud-init timing**: OCI fires cloud-init before DNS/NAT are stable. Scripts loop on `nslookup` + `curl` before `apt-get`.
- **apt lock race**: `apt-daily` grabs the lock before cloud-init/Packer runs. Fix: disable services, pkill apt, sleep 2, retry loop on `apt-get update` (up to 20 attempts, 30s between).
- **IPv6 / NAT gateway**: OCI NAT silently drops IPv6. Fix: `sysctl disable_ipv6` + `Acquire::ForceIPv4 "true"`.
- **OCI CLI / urllib3**: Ubuntu 24.04 ships urllib3 without a RECORD file. Fix: install OCI CLI into `/opt/oci-venv`.
- **ARM64 apt sources**: DC is A1.Flex (ARM64) — uses `ports.ubuntu.com`.
- **Bastion RSA only**: OCI Bastion rejects ECDSA keys — RSA 4096 required.
- **Bastion ACTIVE lag**: Key not propagated immediately after ACTIVE state. `sleep 5` before opening tunnel.
- **FSS before domain join**: NFS mounts must happen before `realm join` so mkhomedir writes home dirs to FSS.
- **SSSD offline at boot**: Fixed with `offline_timeout = 60` in sssd.conf.
- **DC bootstrap time**: ~6 minutes. Module `time_sleep` is 600s before DHCP options update.
- **Instance Pool size drift**: `lifecycle { ignore_changes = [actual_state] }` prevents Terraform from resetting pool size to 2 after autoscaling events.

## Keys

RSA 4096 key pair in `01-directory/accounts.tf` → written to `01-directory/keys/Private_Key` (0600) and `01-directory/keys/Private_Key.pub`. Gitignored.

## SSH to Linux Samba Gateway

```bash
ssh -i 01-directory/keys/Private_Key -o StrictHostKeyChecking=no ubuntu@<linux_public_ip>
```

## SSH to Domain Controller

```bash
./connect.sh
```

OCI Bastion PORT_FORWARDING session. Requires `~/.oci/config` and the RSA key in `01-directory/keys/`.

## Domain Configuration

Default: `mcloud.mikecloud.com` / `MCLOUD.MIKECLOUD.COM` / `MCLOUD`

To override, set `dns_zone`, `realm`, `netbios`, `user_base_dn` in both `01-directory/variables.tf` and `02-servers/variables.tf` and `04-cluster/variables.tf`.

## Windows RDP Fallback

If domain join fails, RDP as local account: `./get_password.sh windows_local_admin`
