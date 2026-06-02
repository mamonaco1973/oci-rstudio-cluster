#!/bin/bash
set -euo pipefail

# ================================================================================
# Docker Installation Script (Ubuntu)
# ================================================================================

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor \
  -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) "\
"signed-by=/etc/apt/keyrings/docker.gpg] "\
"https://download.docker.com/linux/ubuntu "\
"$(. /etc/os-release; echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

sudo mkdir -p /etc/systemd/system/docker.service.d

cat <<'EOF' | sudo tee /etc/systemd/system/docker.service.d/permissions.conf
[Service]
# Make docker.sock world-writable after Docker starts
ExecStartPost=/bin/sh -c 'chmod 777 /var/run/docker.sock'
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now docker
sudo systemctl restart docker

echo "Docker installation complete."
