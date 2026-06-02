#!/bin/bash
set -e

# ================================================================================
# HashiCorp Tools Installation Script (Terraform + Packer)
# ================================================================================
# Description:
#   Installs Terraform and Packer from the official HashiCorp APT repository.
#   The script configures a secure keyring, registers the HashiCorp repository,
#   updates the package index, and installs both tools using apt-get.
#
# Notes:
#   - apt-get is used instead of apt to ensure stable automation behavior.
#   - Keyrings are stored in /usr/share/keyrings for secure repository trust.
#   - Script exits immediately on error due to 'set -e'.
# ================================================================================

# ================================================================================
# Step 1: Install prerequisite packages
# ================================================================================
sudo apt-get update -y
sudo apt-get install -y \
  gnupg \
  software-properties-common \
  curl

# ================================================================================
# Step 2: Add the HashiCorp GPG signing key
# ================================================================================
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor \
  -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# ================================================================================
# Step 3: Add the HashiCorp APT repository
# ================================================================================
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] "\
"https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

# ================================================================================
# Step 4: Update package index and install Terraform / Packer
# ================================================================================
sudo apt-get update -y
sudo apt-get install -y terraform packer

echo "NOTE: HashiCorp tools installation complete."

# ================================================================================
# Step 5: Display version information
# ================================================================================
terraform -version
packer -version
