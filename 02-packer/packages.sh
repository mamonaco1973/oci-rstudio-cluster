#!/bin/bash
set -euo pipefail

# ==============================================================================
# Base Package Installation for AD Join + FSS NFS (OCI)
# ------------------------------------------------------------------------------
# Installs packages baked into the Xubuntu OCI image so userdata.sh at
# runtime can skip package installation and go straight to domain join.
#
# Packages:
#   - realmd / adcli / krb5-user     : Domain discovery and Kerberos auth
#   - sssd-ad / libnss-sss / libpam-sss : Identity + PAM auth via SSSD
#   - samba / winbind                : AD membership + SMB gateway for Windows
#   - oddjob / oddjob-mkhomedir      : Auto-create home dirs for AD users
#   - nfs-common                     : Required for OCI FSS NFS v3 mounts
#   - iptables-persistent            : Persists iptables rules across reboots
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

# Snap seeds asynchronously on boot — removing before seed completes returns
# exit code 10 and fails the Packer build under set -euo pipefail.
snap wait system seed.loaded

# XRDP has known issues with snap packages interfering with the session.
# Remove snap entirely so it cannot reinstall during the image lifetime.
snap remove --purge core22 || true
snap remove --purge snapd  || true
apt-get purge -y snapd
echo -e "Package: snapd\nPin: release *\nPin-Priority: -10" \
  | tee /etc/apt/preferences.d/nosnap.pref

apt-get update -y

apt-get install -y \
  less curl unzip jq python3-venv \
  realmd sssd-ad sssd-tools libnss-sss libpam-sss \
  adcli samba samba-common-bin samba-libs \
  winbind libpam-winbind libnss-winbind \
  oddjob oddjob-mkhomedir packagekit krb5-user \
  nfs-common \
  nano vim iptables-persistent
