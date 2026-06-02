#!/bin/bash
set -euo pipefail

# ================================================================================
# Azure CLI Installation Script
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

curl -sL https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor \
  | tee /etc/apt/keyrings/microsoft-azure-cli-archive-keyring.gpg \
    > /dev/null

AZ_REPO=$(lsb_release -cs)

echo "deb [signed-by=/etc/apt/keyrings/"\
"microsoft-azure-cli-archive-keyring.gpg] "\
"https://packages.microsoft.com/repos/azure-cli/ ${AZ_REPO} main" \
  | tee /etc/apt/sources.list.d/azure-cli.list

apt-get update -y
apt-get install -y azure-cli

echo "NOTE: Azure CLI installation complete."
az --version
