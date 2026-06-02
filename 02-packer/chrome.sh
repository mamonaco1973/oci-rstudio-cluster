#!/bin/bash
set -e

# ================================================================================
# Google Chrome Installation Script (DEB Package, No Snap)
# ================================================================================
# Description:
#   Installs Google Chrome Stable on Ubuntu 24.04 using Google's official
#   APT repository. The script installs prerequisite packages, registers the
#   signing key, configures the repository, updates the package index, and
#   installs Chrome using a stable scripting interface (apt-get).
#
# Notes:
#   - This method installs the official DEB-based Chrome package.
#   - Snap is not used to avoid confinement, update delays, and profile
#     integration issues.
#   - Script exits on errors due to 'set -e'.
# ================================================================================

# ================================================================================
# Step 1: Update the package index
# ================================================================================
echo "NOTE: Updating package index..."
sudo apt-get update -y

# ================================================================================
# Step 2: Install required dependencies
# ================================================================================
echo "NOTE: Installing required dependencies..."
sudo apt-get install -y wget apt-transport-https ca-certificates gnupg

# ================================================================================
# Step 3: Download and store Google's signing key
# ================================================================================
echo "NOTE: Downloading Google signing key..."
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor \
  -o /usr/share/keyrings/google-linux-keyring.gpg

# ================================================================================
# Step 4: Add Google Chrome APT repository
# ================================================================================
echo "NOTE: Adding Google Chrome APT repository..."
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-keyring.gpg] "\
"https://dl.google.com/linux/chrome/deb/ stable main" \
  | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null

# ================================================================================
# Step 5: Update package index to load Chrome repo
# ================================================================================
echo "NOTE: Updating package index again..."
sudo apt-get update -y

# ================================================================================
# Step 6: Install Google Chrome Stable
# ================================================================================
echo "NOTE: Installing Google Chrome Stable (DEB)..."
sudo apt-get install -y google-chrome-stable

# ================================================================================
# Step 7: Confirm installation
# ================================================================================
echo "NOTE: Chrome installation complete."
google-chrome --version
