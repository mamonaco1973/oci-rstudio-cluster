#!/bin/bash
set -euo pipefail

# ================================================================================
# AWS CLI v2 Installation Script (ZIP Bundle Installer)
# ================================================================================

cd /tmp

curl -s -o awscliv2.zip \
  "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"

unzip -q awscliv2.zip
sudo ./aws/install

rm -rf awscliv2.zip aws
echo "NOTE: AWS CLI v2 installation complete."
