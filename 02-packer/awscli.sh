#!/bin/bash
set -euo pipefail

# ================================================================================
# AWS CLI v2 Installation Script (ZIP Bundle Installer)
# ================================================================================
# Description:
#   Installs the AWS CLI v2 on Linux using the official ZIP bundle provided by
#   Amazon. The installer contains all required binaries and dependencies, and
#   places the aws and aws_completer commands under /usr/local/bin.
#
# Notes:
#   - Suitable for automation and provisioning workflows.
#   - Provides access to AWS APIs for Secrets Manager, S3, and general tasks.
#   - Requires unzip to be installed; the script does not install it.
#   - Script exits on any error due to 'set -euo pipefail'.
# ================================================================================

# ================================================================================
# Step 1: Download the AWS CLI v2 ZIP bundle
# ================================================================================
cd /tmp

curl -s -o awscliv2.zip \
  "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"

# ================================================================================
# Step 2: Unpack and install the AWS CLI
# ================================================================================
unzip -q awscliv2.zip
sudo ./aws/install

# ================================================================================
# Step 3: Clean up installation artifacts
# ================================================================================
rm -rf awscliv2.zip aws
echo "NOTE: AWS CLI v2 installation complete."