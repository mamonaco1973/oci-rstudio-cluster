#!/bin/bash
set -euo pipefail

# ================================================================================
# XRDP Installation and XFCE Session Configuration Script
# ================================================================================
# Description:
#   Installs XRDP and replaces the default /etc/xrdp/startwm.sh script so that
#   all XRDP logins launch XFCE without the untrusted launcher dialog or the
#   default Ubuntu session. The script also ensures the file has correct
#   permissions and enables the XRDP service at boot.
#
# Notes:
#   - Uses apt-get for predictable automation behavior.
#   - Writes a clean startwm.sh that invokes startxfce4.
#   - Script exits on any error due to 'set -euo pipefail'.
# ================================================================================

# ================================================================================
# Step 1: Install XRDP
# ================================================================================
sudo apt-get update -y
sudo apt-get install -y xrdp

# ================================================================================
# Step 2: Replace /etc/xrdp/startwm.sh with XFCE session launcher
# ================================================================================
sudo tee /etc/xrdp/startwm.sh >/dev/null <<'EOF'
#!/bin/sh
# xrdp X session start script (c) 2015, 2017, 2021 mirabilos
# published under The MirOS Licence
#
# Rely on /etc/pam.d/xrdp-sesman using pam_env to load both
# /etc/environment and /etc/default/locale to initialise the
# locale and the user environment properly.

if test -r /etc/profile; then
    . /etc/profile
fi

if test -r ~/.profile; then
    . ~/.profile
fi

startxfce4
EOF

# ================================================================================
# Step 3: Correct permissions on startwm.sh
# ================================================================================
sudo chmod 755 /etc/xrdp/startwm.sh
echo "NOTE: /etc/xrdp/startwm.sh replaced and permissions set."

# ================================================================================
# Step 4: Enable XRDP service
# ================================================================================
sudo sed -i 's/^max_bpp=32/max_bpp=16/' /etc/xrdp/xrdp.ini
sudo systemctl enable xrdp
echo "NOTE: XRDP installation and configuration complete."

# ---------------------------------------------------------------------------------
# Deploy PAM script to create home directories on first xrdp login
# ---------------------------------------------------------------------------------

cat <<'EOF' | tee /etc/pam.d/xrdp-mkhomedir.sh > /dev/null
#!/bin/bash
echo "NOTE: Creating home directory for user $PAM_USER" 
su -c "exit" $PAM_USER
chmod 700 /home/*
EOF

chmod +x /etc/pam.d/xrdp-mkhomedir.sh

# Create /etc/pam.d/xrdp-sesman with required PAM configuration
cat >/etc/pam.d/xrdp-sesman <<'EOF'
#%PAM-1.0
auth optional pam_exec.so debug /etc/pam.d/xrdp-mkhomedir.sh
auth required pam_env.so readenv=1
auth required pam_env.so readenv=1 envfile=/etc/default/locale
@include common-auth
@include common-account
@include common-session
@include common-password
EOF

echo "NOTE: Created /etc/pam.d/xrdp-sesman successfully."

# ================================================================================
# Step 5: Persist IPv6 disable so xrdp-sesman binds to 127.0.0.1 at boot
# ================================================================================
# Without this, xrdp-sesman binds to [::1]:3350 and xrdp cannot reach it
# because OCI disables IPv6 routing — the two services can't communicate.
cat > /etc/sysctl.d/99-disable-ipv6.conf <<'SYSCTL'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
SYSCTL
echo "NOTE: IPv6 disable persisted to /etc/sysctl.d/99-disable-ipv6.conf."