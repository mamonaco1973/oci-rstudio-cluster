#!/bin/bash
set -euo pipefail

# ================================================================================
# Azure CLI Installation Script
# ================================================================================
# Description:
#   Installs the Microsoft Azure CLI on Ubuntu using Microsoft's official
#   package repository. The script configures a secure keyring, registers the
#   APT repository, updates the package index, and installs the azure-cli
#   package in a fully automated manner.
#
# Notes:
#   - DEBIAN_FRONTEND is set to noninteractive to avoid any prompts.
#   - apt-get is used instead of apt to ensure a stable scripting interface.
#   - Script exits immediately on errors due to 'set -euo pipefail'.
# ================================================================================

# ================================================================================
# Step 1: Configure environment for noninteractive installation
# ================================================================================
export DEBIAN_FRONTEND=noninteractive

# ================================================================================
# Step 2: Register Microsoft's GPG key for the Azure CLI repository
# ================================================================================
curl -sL https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor \
  | tee /etc/apt/keyrings/microsoft-azure-cli-archive-keyring.gpg \
    > /dev/null

# ================================================================================
# Step 3: Add the Azure CLI APT repository
# ================================================================================
AZ_REPO=$(lsb_release -cs)

echo "deb [signed-by=/etc/apt/keyrings/"\
"microsoft-azure-cli-archive-keyring.gpg] "\
"https://packages.microsoft.com/repos/azure-cli/ ${AZ_REPO} main" \
  | tee /etc/apt/sources.list.d/azure-cli.list

# ================================================================================
# Step 4: Update repository index and install Azure CLI
# ================================================================================
apt-get update -y
apt-get install -y azure-cli

echo "NOTE: Azure CLI installation complete."

# ================================================================================
# Step 5: Display Azure CLI version information
# ================================================================================
az --version
