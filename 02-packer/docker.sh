#!/bin/bash
set -euo pipefail

# ================================================================================
# Docker Installation Script (Ubuntu) With Universal Socket Access
# ================================================================================
# Description:
#   Installs Docker Engine from the official Docker APT repository and configures
#   the system so *all* users can run Docker without group membership or sudo.
#   A systemd service override applies a chmod 777 to /var/run/docker.sock after
#   Docker starts, ensuring persistent world-writable permissions.
#
# Notes:
#   - apt-get is used to avoid unstable CLI warnings.
#   - Permissions are intentionally broad for lab, dev, and multi-user systems.
#   - For production, consider limiting access to trusted groups.
# ================================================================================

# ================================================================================
# Step 1: Install prerequisite packages
# ================================================================================
sudo apt-get update -y
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg

# ================================================================================
# Step 2: Add the Docker GPG signing key
# ================================================================================
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor \
  -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

# ================================================================================
# Step 3: Add the official Docker APT repository
# ================================================================================
echo "deb [arch=$(dpkg --print-architecture) "\
"signed-by=/etc/apt/keyrings/docker.gpg] "\
"https://download.docker.com/linux/ubuntu "\
"$(. /etc/os-release; echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

# ================================================================================
# Step 4: Install Docker Engine and components
# ================================================================================
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# ================================================================================
# Step 5: Create a systemd override to allow universal Docker access
# ================================================================================
sudo mkdir -p /etc/systemd/system/docker.service.d

cat <<'EOF' | sudo tee /etc/systemd/system/docker.service.d/permissions.conf
[Service]
# Make docker.sock world-writable after Docker starts
ExecStartPost=/bin/sh -c 'chmod 777 /var/run/docker.sock'
EOF

# ================================================================================
# Step 6: Reload systemd configuration and restart Docker
# ================================================================================
sudo systemctl daemon-reload
sudo systemctl enable --now docker
sudo systemctl restart docker

# ================================================================================
# Completion Message
# ================================================================================
echo "=============================================================================="
echo "Docker installation complete. All users can now run Docker without sudo."
echo "Test with: docker ps"
echo "=============================================================================="
