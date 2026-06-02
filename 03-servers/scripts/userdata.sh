#!/bin/bash
set -euo pipefail

LOG=/root/userdata.log
mkdir -p /root
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t user-data -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

echo "user-data start: $(date -Is)"

# Disable IPv6 — OCI subnets are IPv4-only; leaving IPv6 enabled causes glibc
# to prefer AAAA records and waste time on unroutable connection attempts.
# Written to sysctl.d so the disable persists across reboots.
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
cat > /etc/sysctl.d/99-disable-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

# Disable automatic updates and kill any already-running apt processes —
# OCI fires cloud-init fast enough that apt-daily may have grabbed the lock
# before this script runs; disable alone does not kill an in-flight process.
systemctl disable --now apt-daily.service apt-daily-upgrade.service unattended-upgrades.service 2>/dev/null || true
pkill -9 -f unattended-upgrades 2>/dev/null || true
pkill -9 -f apt 2>/dev/null || true
sleep 2

# OCI Ubuntu images block all inbound ports via iptables by default.
# TODO: restrict source CIDR and open only required ports for production.
iptables -I INPUT -s 0.0.0.0/0 -j ACCEPT

# Credentials and config injected by Terraform via templatefile
ADMIN_USERNAME="Admin"
ADMIN_PASSWORD="${admin_password}"
DOMAIN_FQDN="${domain_fqdn}"
MT_IP="${mt_ip}"

# Set ubuntu password to match admin — allows password SSH as fallback
echo "ubuntu:$ADMIN_PASSWORD" | chpasswd

echo "Waiting for DNS resolution..."
until nslookup us.archive.ubuntu.com >/dev/null 2>&1; do
  echo "DNS not ready yet, retrying in 30s..."
  sleep 30
done
echo "DNS ready: $(date -Is)"

echo "Waiting for outbound internet connectivity..."
until curl -fsS --max-time 10 https://us.archive.ubuntu.com/ >/dev/null 2>&1; do
  echo "Internet not reachable yet, retrying in 30s..."
  sleep 30
done
echo "Network ready: $(date -Is)"

# Rewrite apt sources — avoids ubuntu.com DDoS issues on OCI
sed -i 's|http://archive.ubuntu.com|http://us.archive.ubuntu.com|g' /etc/apt/sources.list.d/*.sources 2>/dev/null || true
sed -i 's|http://security.ubuntu.com|http://us.archive.ubuntu.com|g' /etc/apt/sources.list.d/*.sources 2>/dev/null || true

export DEBIAN_FRONTEND=noninteractive
# OCI NAT gateway does not route IPv6 — force IPv4 for all apt traffic
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean false" | debconf-set-selections
# APT::Update::Error-Mode=any makes apt-get update exit non-zero when any
# source fails — without it, W: warnings still exit 0 and fool the retry loop.
for i in {1..20}; do
  apt-get update -y -o APT::Update::Error-Mode=any && break
  echo "apt-get update failed (attempt $i/20), killing apt and retrying in 30s..."
  pkill -9 -f apt 2>/dev/null || true
  sleep 30
done
apt-get install -y \
  less curl jq python3-venv \
  realmd sssd-ad sssd-tools libnss-sss libpam-sss \
  adcli samba samba-common-bin samba-libs \
  winbind libpam-winbind libnss-winbind \
  oddjob oddjob-mkhomedir packagekit krb5-user \
  nfs-common \
  nano vim iptables-persistent

# Install OCI CLI into a venv — avoids conflict with Debian-managed urllib3
# which has no RECORD file and blocks pip's dependency resolution.
python3 -m venv /opt/oci-venv
/opt/oci-venv/bin/pip install --quiet oci-cli
ln -sf /opt/oci-venv/bin/oci /usr/local/bin/oci

# ==============================================================================
# FSS NFS Mounts
# ------------------------------------------------------------------------------
# Mount before domain join so mkhomedir creates AD user home dirs on FSS,
# matching the AWS EFS pattern where /home is shared across instances.
# ==============================================================================

echo "Mounting FSS /nfs from $MT_IP"
mkdir -p /nfs
mount -o nfsvers=3 "$MT_IP":/nfs /nfs
echo "$MT_IP:/nfs  /nfs  nfs  _netdev,nfsvers=3  0  0" >> /etc/fstab

mkdir -p /nfs/data /nfs/home

# Symlink /home -> /nfs/home so AD user homes live on FSS without a
# separate export or fstab entry — same pattern as azure-rstudio-cluster.
mv /home /home.local
ln -s /nfs/home /home
cp -a /home.local/. /nfs/home/

systemctl daemon-reload
echo "FSS mounts complete: $(date -Is)"
echo "DEBUG: active NFS mounts:"
mount | grep nfs || echo "WARNING: no NFS mounts found"
df -h /nfs || true

# Wait for DC Kerberos — DNS resolving the domain is not enough; the full AD
# stack (Kerberos, LDAP) takes longer after the DC reboots post-provision.
echo "Waiting for DC Kerberos on $DOMAIN_FQDN..."
until echo "$ADMIN_PASSWORD" | kinit "$ADMIN_USERNAME@${domain_fqdn_upper}" 2>/dev/null; do
  echo "Kerberos not ready yet, retrying in 30s..."
  sleep 30
done
kdestroy 2>/dev/null || true
echo "DC Kerberos ready: $(date -Is)"

# Join AD domain — retry loop in case LDAP/SMB are still initialising
echo "Joining domain $DOMAIN_FQDN as $ADMIN_USERNAME"
for i in {1..10}; do
  if echo "$ADMIN_PASSWORD" | realm join --membership-software=samba -U "$ADMIN_USERNAME" "$DOMAIN_FQDN" --verbose; then
    echo "Domain join succeeded on attempt $i"
    break
  fi
  if [ "$i" -eq 10 ]; then
    echo "ERROR: domain join failed after 10 attempts"
    exit 1
  fi
  echo "Domain join failed (attempt $i/10), retrying in 30s..."
  sleep 30
done
echo "DEBUG: realm list output:"
realm list || true

# SSH: allow password authentication for AD users
if [ -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf ]; then
  sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
else
  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/g' /etc/ssh/sshd_config || true
fi

# SSSD tweaks
if [ -f /etc/sssd/sssd.conf ]; then
  sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' /etc/sssd/sssd.conf || true
  sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' /etc/sssd/sssd.conf || true
  sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|g' /etc/sssd/sssd.conf || true
  sed -i '/^\[nss\]/a entry_negative_timeout = 0' /etc/sssd/sssd.conf || true
  sed -i '/^\[domain\//a offline_timeout = 60' /etc/sssd/sssd.conf || true
  # Allow all authenticated AD users — GPO access control blocks xrdp PAM service
  sed -i '/^access_provider = ad/a ad_gpo_access_control = permissive' /etc/sssd/sssd.conf || true
  chmod 600 /etc/sssd/sssd.conf || true
fi

# Avoid XAuthority warning for new users
touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

pam-auth-update --enable mkhomedir || true
systemctl restart sssd || true
systemctl restart ssh || systemctl restart sshd || true

# Sudoers for linux-admins group (idempotent)
SUDO_FILE=/etc/sudoers.d/10-linux-admins
if [ ! -f "$SUDO_FILE" ]; then
  echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" > "$SUDO_FILE"
  chmod 440 "$SUDO_FILE"
fi

# ==============================================================================
# Samba SMB Gateway
# ------------------------------------------------------------------------------
# Samba uses the machine keytab written by realm join (adcli) at
# /etc/krb5.keytab — no separate "net ads join" needed.
# Windows clients map Z: to \\<this-ip>\efs via the [efs] share.
# ==============================================================================

systemctl stop sssd || true

# Derive NetBIOS name from hostname (max 15 chars, no dashes, uppercase)
RAW_HOSTNAME=$(head /etc/hostname -c 15)
NETBIOS_NAME=$(echo "$RAW_HOSTNAME" | tr '[:lower:]' '[:upper:]')

cat > /etc/samba/smb.conf <<EOF
[global]
workgroup = ${netbios}
security = ads

strict sync = no
sync always = no
aio read size = 1
aio write size = 1
use sendfile = yes

passdb backend = tdbsam

printing = cups
printcap name = cups
load printers = yes
cups options = raw

# Uses the machine keytab created by realm join — no net ads join needed
kerberos method = secrets and keytab

netbios name = $NETBIOS_NAME

template homedir = /home/%U
template shell = /bin/bash

create mask = 0770
force create mode = 0770
directory mask = 0770
force group = ${lower(netbios)}-users

realm = ${domain_fqdn_upper}

idmap config ${domain_fqdn_upper} : backend = sss
idmap config ${domain_fqdn_upper} : range = 10000-1999999999
idmap config * : backend = tdb
idmap config * : range = 1-9999
min domain uid = 0

winbind use default domain = yes
winbind normalize names = yes
winbind refresh tickets = yes
winbind offline logon = yes
winbind enum groups = yes
winbind enum users = yes
winbind cache time = 30
idmap cache time = 60

[homes]
browseable = no
read only = no
inherit acls = yes

[nfs]
path = /nfs
read only = no
guest ok = no
EOF

# NSS: add winbind alongside sssd so Samba can resolve AD users for SMB auth
cat > /etc/nsswitch.conf <<EOF
passwd:     files sss winbind
group:      files sss winbind
automount:  files sss winbind
shadow:     files sss winbind
hosts:      files dns myhostname
services:   files sss
netgroup:   files sss
EOF

systemctl restart winbind smb nmb sssd || true
systemctl restart ssh || systemctl restart sshd || true

echo "DEBUG: testparm output:"
testparm -s 2>&1 || true
echo "DEBUG: wbinfo -u:"
wbinfo -u 2>&1 || true
echo "DEBUG: wbinfo -g:"
wbinfo -g 2>&1 || true
echo "DEBUG: getent group ${lower(netbios)}-users:"
getent group "${lower(netbios)}-users" 2>&1 || true

# ==============================================================================
# Permissions and Seed Content
# ==============================================================================

# Pre-create home dirs for domain users on FSS so permissions are correct
# before first login — mkhomedir handles subsequent users automatically.
for user in rpatel jsmith akumar edavis; do
  su -c "exit" "$user" 2>/dev/null || true
done

chgrp "${lower(netbios)}-users" /nfs /nfs/data
chmod 775 /nfs /nfs/data
chmod 700 /home/* 2>/dev/null || true
echo "DEBUG: /nfs ownership:"
ls -la /nfs || true

cd /nfs
git clone https://github.com/mamonaco1973/oci-xubuntu-xrdp.git
chmod -R 775 oci-fss
chgrp -R "${lower(netbios)}-users" oci-fss

netfilter-persistent save

realm list || true

ln -sf /nfs /etc/skel/nfs
mkdir -p /home/ubuntu
chown -R ubuntu:ubuntu /home/ubuntu || true

echo "user-data complete: $(date -Is)"
