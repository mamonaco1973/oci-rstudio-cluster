#!/bin/bash
set -euo pipefail

# ==============================================================================
# Base Package Installation for AD Join + FSS NFS + R Development (OCI)
# ------------------------------------------------------------------------------
# Bakes packages into the RStudio OCI image so rstudio_booter.sh at runtime
# can skip package installation and go straight to domain join and config.
#
# Packages:
#   - realmd / adcli / krb5-user       : Domain discovery and Kerberos auth
#   - sssd-ad / libnss-sss / libpam-sss: Identity + PAM auth via SSSD
#   - oddjob / oddjob-mkhomedir        : Auto-create home dirs for AD users
#   - nfs-common                       : Required for OCI FSS NFS v3 mounts
#   - iptables-persistent              : Persists iptables rules across reboots
#   - build-essential + R dev libs     : Compile R packages from source
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1

# Kill and permanently mask all automatic update services so they can
# never grab the dpkg lock during or after this Packer build.
systemctl stop apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service 2>/dev/null || true
systemctl mask apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service 2>/dev/null || true
pkill -9 -f unattended-upgrades 2>/dev/null || true
pkill -9 -f apt 2>/dev/null || true
sleep 2
DEBIAN_FRONTEND=noninteractive apt-get purge -y unattended-upgrades needrestart 2>/dev/null || true

# OCI NAT gateway does not route IPv6 — force IPv4 for all apt traffic
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

for i in {1..20}; do
  apt-get update -y -o APT::Update::Error-Mode=any && break
  echo "apt-get update failed (attempt $i/20), killing apt and retrying in 30s..."
  pkill -9 -f apt 2>/dev/null || true
  sleep 30
done

echo "=== Phase 1: Base utilities and AD join tools ==="
apt-get install -y \
  less curl unzip jq python3-venv \
  realmd sssd-ad sssd-tools libnss-sss libpam-sss \
  adcli samba-common-bin \
  oddjob oddjob-mkhomedir packagekit krb5-user \
  nfs-common \
  nano vim iptables-persistent

echo "=== Phase 2: Core build chain for R ==="
apt-get install -y build-essential gfortran python3-pip \
    libxml2-dev libcurl4-openssl-dev libssl-dev cmake

echo "=== Phase 3: Math and compression libraries ==="
apt-get install -y libgsl-dev libblas-dev liblapack-dev \
    zlib1g-dev libbz2-dev liblzma-dev

echo "=== Phase 4: Graphics and text stack ==="
apt-get install -y libcairo2-dev libxt-dev libx11-dev libxpm-dev \
    libfreetype6-dev libharfbuzz-dev libfribidi-dev \
    libglu1-mesa-dev freeglut3-dev mesa-common-dev libabsl-dev

echo "=== Phase 5: Database and spatial libraries ==="
apt-get install -y libsqlite3-dev libpq-dev libmariadb-dev \
    libmariadb-dev-compat libudunits2-dev libgeos-dev libproj-dev

echo "=== Phase 6: Extra formats and science libs ==="
apt-get install -y libmagick++-dev libpoppler-cpp-dev \
    libhdf5-dev libnetcdf-dev default-jdk

echo "=== Phase 7: Clean up ==="
apt-get autoremove -y
apt-get clean

echo "=== packages.sh completed successfully ==="
