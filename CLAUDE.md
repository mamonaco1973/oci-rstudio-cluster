# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

Deploys a Xubuntu XRDP cloud desktop on OCI. Three-phase build:

1. `01-directory` — VCN, subnets, OCI Bastion, Samba 4 AD DC (module-oci-mini-ad), SSH keys, passwords
2. `02-packer` — Builds a custom OCI compute image (`xubuntu-image`) with Xfce4, XRDP, and a full dev toolchain
3. `03-servers` — FSS (NFS), Xubuntu E4.Flex desktop (Packer image), Windows Server 2022 client

The Xubuntu instance mounts FSS at `/home` (AD user home dirs) and `/nfs` (shared data), then re-exports `/nfs` as a Samba SMB share. The Windows client domain-joins and maps `Z:` to `\\<xubuntu-private-ip>\nfs`.

## Commands

```bash
./apply.sh               # validate env, run all 3 phases
./destroy.sh             # destroy 03-servers, delete Packer image, destroy 01-directory
./connect.sh             # OCI Bastion port-forward + SSH tunnel to DC
./get_password.sh <user> # print username + password from tfstate
./validate.sh            # print public IPs and connection hints
./check_env.sh           # validate oci/terraform/packer/jq in PATH + OCI CLI auth
```

## Architecture

```
01-directory/
  networking.tf    — VCN, IGW, NAT, route tables, security lists (NFS/SMB/AD rules)
  ad.tf            — module-oci-mini-ad invocation, users_json locals, all outputs
  accounts.tf      — tls_private_key (RSA 4096), admin/windows random_password,
                     user passwords as memorable word-NNNNNN via random_shuffle/integer
  bastion.tf       — oci_bastion_bastion (STANDARD type, free)
  variables.tf     — compartment_ocid, tenancy_ocid, domain vars
  vault.tf         — (placeholder, vault removed due to PENDING_DELETION limit)

02-packer/
  xubuntu_ami.pkr.hcl — oracle-oci source, E4.Flex 4c/16GB, 64 GB disk, image_name=xubuntu-image
  packages.sh      — AD/NFS/Samba packages (no snap, no amazon-efs-utils)
  ocicli.sh        — OCI CLI into /opt/oci-venv (avoids urllib3 conflict)
  xubuntu.sh       — Xfce4 + xubuntu-core desktop
  xrdp.sh          — XRDP RDP server + session fixes
  chrome.sh / firefox.sh / vscode.sh — browsers and editor
  hashicorp.sh     — Terraform + Packer
  awscli.sh / azcli.sh / gcloudcli.sh — cloud CLIs
  docker.sh        — Docker CE
  postman.sh / krdc.sh / onlyoffice.sh — desktop apps
  desktop.sh       — /etc/skel shortcuts, wallpaper, terminal defaults

03-servers/
  main.tf          — OCI provider, terraform_remote_state from 01-directory,
                     Windows image data source, xubuntu/windows hostname locals
  fss.tf           — FSS file system, mount target (vm-subnet), exports /nfs and /home
  linux.tf         — xubuntu_instance E4.Flex 4c/16GB, source_id=var.xubuntu_image_ocid,
                     NSGs: ssh+smb; templates admin_password/domain/dc_ip/mt_ip
  windows.tf       — windows_ad_instance E4.Flex 2c/8GB, rdp_nsg,
                     templates samba_server=xubuntu private_ip
  security_groups.tf — ssh_nsg (22), rdp_nsg (3389), smb_nsg (445 scoped to vm-subnet)
  roles.tf         — empty (no vault; passwords injected via templatefile)
  outputs.tf       — xubuntu_public_ip, xubuntu_private_ip, mount_target_ip
  variables.tf     — domain vars + xubuntu_image_ocid (required, set by apply.sh)
  scripts/userdata.sh  — IPv6 disable, apt lock kill, iptables open, FSS mount,
                         /home → /nfs/home symlink, realm join (10 retries), Samba config
  scripts/userdata.ps1 — NLA, local account, IPv6 disable, RSAT, domain join,
                         DNS SearchList fix, Z: drive bat to \\samba_server\nfs
```

Module source: `github.com/mamonaco1973/module-oci-mini-ad`

## Auth and Variable Wiring

- OCI auth: `~/.oci/config` DEFAULT profile — no credentials in code
- Compartment: `OCI_COMPARTMENT_ID` env var → `TF_VAR_compartment_ocid`
- Tenancy: extracted from `~/.oci/config` → `TF_VAR_tenancy_ocid`
- Packer image OCID: resolved by `apply.sh` after Packer build → `TF_VAR_xubuntu_image_ocid`
- Passwords: sensitive outputs in tfstate — retrieve with `./get_password.sh <user>`
- Valid users: `admin`, `jsmith`, `edavis`, `rpatel`, `akumar`, `windows_local_admin`, `ubuntu`

## Password Design

- Admin and `windows_local_admin`: 24-char random with `override_special="_-."`, prefixed `"A${...}"` for AD uppercase requirement
- AD users (`jsmith`, `edavis`, `rpatel`, `akumar`): `word-NNNNNN` format via `random_shuffle` + `random_integer` — memorable, meets AD complexity (lowercase + digit + special `-`)

## Packer Image

- Plugin: `hashicorp/oracle` (`oracle-oci` source)
- Base: latest Canonical Ubuntu 24.04 for VM.Standard.E4.Flex — resolved by `apply.sh` via OCI CLI
- Build subnet: vm-subnet (public IP assigned — needs internet for apt)
- Image name: `xubuntu-image` (fixed name — `apply.sh` finds it by exact display-name match via jq)
- Rebuilding overwrites the previous image; `destroy.sh` deletes it explicitly via OCI CLI

## FSS Architecture

```
vm-subnet (10.0.0.64/26)
  ├── Xubuntu instance  ──NFS──▶  Mount Target (FSS)
  │     └── Samba [nfs] share         ├── export /nfs
  │                                   └── export /home
  └── Windows instance  ──SMB──▶  \\<xubuntu-private-ip>\nfs  →  Z:
```

- FSS NFS security rules on vm-subnet: TCP/UDP 111, TCP 2048-2050, UDP 2048, TCP 445
- `/home` on FSS — AD user homedirs persist; `mkhomedir` writes there after `realm join`
- Samba: `security = ADS`, machine keytab from `realm join` (no separate `net ads join`)
- `map_drives.bat` placed in All Users startup folder — runs at every Windows login

## Samba / Winbind Notes

- SSSD handles Linux PAM/NSS (login, ssh). Winbind handles SMB auth for Windows clients.
- `nsswitch.conf`: `passwd: files sss winbind`, `group: files sss winbind`
- `idmap config MCLOUD : backend = sss` — Winbind delegates UID/GID to SSSD
- Samba NetBIOS name derived from hostname (uppercase, dashes stripped, ≤15 chars)

## Known OCI Quirks

- **cloud-init timing**: OCI fires cloud-init before DNS/NAT are stable. `userdata.sh` loops on `nslookup` + `curl` before `apt-get`.
- **apt lock race**: `apt-daily` grabs the lock before userdata runs. Fix: kill apt processes and retry loop on `apt-get update`.
- **IPv6 / NAT gateway**: OCI NAT silently drops IPv6. Fix: `sysctl disable_ipv6` + `Acquire::ForceIPv4 "true"`.
- **OCI CLI / urllib3**: Ubuntu 24.04 ships urllib3 without a RECORD file. Fix: install OCI CLI into `/opt/oci-venv`.
- **ARM64 apt sources**: DC is A1.Flex (ARM64) — uses `ports.ubuntu.com`.
- **Bastion RSA only**: OCI Bastion rejects ECDSA keys — RSA 4096 required.
- **Bastion ACTIVE lag**: Key not propagated immediately after ACTIVE state. `sleep 5` before opening tunnel.
- **FSS before domain join**: NFS mounts must happen before `realm join` so mkhomedir writes to FSS `/home`.
- **SSSD offline at boot**: Fixed with `offline_timeout = 60` in sssd.conf.
- **DC bootstrap time**: ~6 minutes. Module `time_sleep` is 600s before DHCP options update.

## Keys

RSA 4096 key pair in `01-directory/accounts.tf` → written to `01-directory/keys/Private_Key` (0600) and `01-directory/keys/Private_Key.pub`. Gitignored.

## SSH to Xubuntu

```bash
ssh -i 01-directory/keys/Private_Key -o StrictHostKeyChecking=no ubuntu@<xubuntu_public_ip>
```

No bastion needed — Xubuntu is in the public subnet.

## SSH to Domain Controller

```bash
./connect.sh
```

OCI Bastion PORT_FORWARDING session. Requires `~/.oci/config` and the RSA key in `01-directory/keys/`.

## Domain Configuration

Default: `mcloud.mikecloud.com` / `MCLOUD.MIKECLOUD.COM` / `MCLOUD`

To override, set `dns_zone`, `realm`, `netbios`, `user_base_dn` in both `01-directory/variables.tf` and `03-servers/variables.tf`.

## Windows RDP Fallback

If domain join fails, RDP as local account: `./get_password.sh windows_local_admin`
