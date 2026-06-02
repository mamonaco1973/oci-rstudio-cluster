#!/bin/bash
set -e

# ================================================================================
# Visual Studio Code Installation Script (Official Microsoft APT Repository)
# ================================================================================
# Description:
#   Installs Visual Studio Code on Ubuntu using Microsoft's official APT repo.
#   The script adds the Microsoft signing key, registers the repository, updates
#   the APT package index, and installs the 'code' package using apt-get.
#
# Notes:
#   - Uses apt-get for stable scripting behavior.
#   - Installs the DEB-based version, not the Snap package.
#   - Script exits on any error due to 'set -e'.
# ================================================================================

# ================================================================================
# Step 1: Install the Microsoft GPG signing key
# ================================================================================
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
  | sudo gpg --dearmor \
  -o /usr/share/keyrings/microsoft.gpg

# ================================================================================
# Step 2: Add the Visual Studio Code APT repository
# ================================================================================
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] "\
"https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

# ================================================================================
# Step 3: Update the package index
# ================================================================================
sudo apt-get update -y

# ================================================================================
# Step 4: Install Visual Studio Code
# ================================================================================
sudo apt-get install -y code
echo "NOTE: Visual Studio Code installation complete."