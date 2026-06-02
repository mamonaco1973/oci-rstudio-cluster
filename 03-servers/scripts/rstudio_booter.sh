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
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
cat > /etc/sysctl.d/99-disable-ipv6.conf <<'SYSCTL'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
SYSCTL

# Disable automatic updates — apt-daily may hold the lock before cloud-init
systemctl disable --now apt-daily.service apt-daily-upgrade.service unattended-upgrades.service 2>/dev/null || true
pkill -9 -f unattended-upgrades 2>/dev/null || true
pkill -9 -f apt 2>/dev/null || true
sleep 2

# OCI Ubuntu images block all inbound ports via iptables by default.
iptables -I INPUT -s 0.0.0.0/0 -j ACCEPT

# Credentials and config injected by Terraform via templatefile
ADMIN_USERNAME="Admin"
ADMIN_PASSWORD="${admin_password}"
DOMAIN_FQDN="${domain_fqdn}"
MT_IP="${mt_ip}"

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

# ==============================================================================
# FSS NFS Mounts
# ------------------------------------------------------------------------------
# Mount before domain join so mkhomedir creates AD user home dirs on FSS,
# persisting home directories across instance pool scale events.
# ==============================================================================

echo "Mounting FSS /nfs from $MT_IP"
mkdir -p /nfs
mount -o nfsvers=3 "$MT_IP":/nfs /nfs
echo "$MT_IP:/nfs  /nfs  nfs  _netdev,nfsvers=3  0  0" >> /etc/fstab

mkdir -p /nfs/data /nfs/home /nfs/rlibs

# Symlink /home → /nfs/home so AD user home dirs are shared across all
# RStudio instances — a user lands on any instance but sees their own files
mv /home /home.local
ln -s /nfs/home /home
cp -a /home.local/. /nfs/home/ 2>/dev/null || true

systemctl daemon-reload
echo "FSS mounts complete: $(date -Is)"

# ==============================================================================
# Active Directory Join
# ==============================================================================

# Wait for DC Kerberos — DNS resolving the domain is not enough; the full AD
# stack takes longer after the DC boots post-provision.
echo "Waiting for DC Kerberos on $DOMAIN_FQDN..."
until echo "$ADMIN_PASSWORD" | kinit "$ADMIN_USERNAME@${domain_fqdn_upper}" 2>/dev/null; do
  echo "Kerberos not ready yet, retrying in 30s..."
  sleep 30
done
kdestroy 2>/dev/null || true
echo "DC Kerberos ready: $(date -Is)"

echo "Joining domain $DOMAIN_FQDN as $ADMIN_USERNAME"
for i in {1..10}; do
  if echo "$ADMIN_PASSWORD" | realm join --membership-software=adcli \
      -U "$ADMIN_USERNAME" "$DOMAIN_FQDN" --verbose; then
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

# ==============================================================================
# SSH and SSSD Configuration
# ==============================================================================

if [ -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf ]; then
  sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
else
  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/g' /etc/ssh/sshd_config || true
fi

if [ -f /etc/sssd/sssd.conf ]; then
  sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' /etc/sssd/sssd.conf || true
  sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' /etc/sssd/sssd.conf || true
  sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|g' /etc/sssd/sssd.conf || true
  sed -i '/^\[nss\]/a entry_negative_timeout = 0' /etc/sssd/sssd.conf || true
  sed -i '/^\[domain\//a offline_timeout = 60' /etc/sssd/sssd.conf || true
  # Restrict RStudio cluster access to domain users in the primary group
  sed -i 's/^access_provider = ad$/access_provider = simple\nsimple_allow_groups = ${force_group}/' \
    /etc/sssd/sssd.conf || true
  chmod 600 /etc/sssd/sssd.conf || true
fi

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

# Restrict home directory permissions for new users
sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

# ==============================================================================
# RStudio Server
# ==============================================================================

systemctl restart rstudio-server || true
systemctl enable rstudio-server || true

# Inject shared R library path — adds /nfs/rlibs to .libPaths() for all users.
# Packages installed by rstudio-admins into /nfs/rlibs are available cluster-wide.
cat <<'RPROFILE' | tee /usr/lib/R/etc/Rprofile.site > /dev/null
local({
  userlib <- Sys.getenv("R_LIBS_USER")
  if (!dir.exists(userlib)) {
    dir.create(userlib, recursive = TRUE, showWarnings = FALSE)
  }
  shared <- "/nfs/rlibs"
  .libPaths(c(userlib, shared, .libPaths()))
})
RPROFILE

# rstudio-admins members can install packages into the shared library
chgrp rstudio-admins /nfs/rlibs 2>/dev/null || true
chmod 775 /nfs/rlibs 2>/dev/null || true

# ==============================================================================
# Final Permissions
# ==============================================================================

# Pre-create home dirs for domain users so permissions are correct
# before first login — mkhomedir handles subsequent users automatically
for user in rpatel jsmith akumar edavis; do
  su -c "exit" "$user" 2>/dev/null || true
done

chmod 700 /home/* 2>/dev/null || true

mkdir -p /home/ubuntu
chown -R ubuntu:ubuntu /home/ubuntu || true

netfilter-persistent save 2>/dev/null || true

realm list || true

echo "user-data complete: $(date -Is)"
