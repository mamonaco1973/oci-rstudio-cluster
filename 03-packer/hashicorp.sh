#!/bin/bash
set -e

# ================================================================================
# HashiCorp Tools Installation Script (Terraform + Packer)
# ================================================================================

sudo apt-get update -y
sudo apt-get install -y gnupg software-properties-common curl

curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor \
  -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] "\
"https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

sudo apt-get update -y
sudo apt-get install -y terraform packer

echo "NOTE: HashiCorp tools installation complete."
terraform -version
packer -version
