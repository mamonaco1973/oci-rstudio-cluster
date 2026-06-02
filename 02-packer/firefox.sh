#!/bin/bash
set -euo pipefail

# ================================================================================
# Firefox Installation Script (Official Mozilla APT Repository, No Snap)
# ================================================================================
# Description:
#   Installs Firefox directly from Mozilla's official APT repository while
#   disabling the Ubuntu Snap-based Firefox package. APT pinning prevents the
#   Snap version from being installed automatically. The script configures
#   secure keyrings, repository definitions, and priority rules for Mozilla's
#   packages.
#
# Notes:
#   - This fully eliminates the Ubuntu Snap version of Firefox.
#   - Uses apt-get for stable scripting behavior.
#   - /etc/apt/preferences.d ensures proper package pinning.
# ================================================================================

# ================================================================================
# Step 1: Disable Ubuntu Snap version of Firefox via APT pinning
# ================================================================================
sudo mkdir -p /etc/apt/preferences.d

sudo tee /etc/apt/preferences.d/firefox-no-snap.pref >/dev/null <<EOF
Package: firefox
Pin: release o=Ubuntu*
Pin-Priority: -1
EOF

# ================================================================================
# Step 2: Install prerequisite packages
# ================================================================================
sudo apt-get update -y
sudo apt-get install -y \
  software-properties-common \
  curl \
  gnupg

# ================================================================================
# Step 3: Install Mozilla's APT signing key
# ================================================================================
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
  | sudo gpg --dearmor \
  -o /usr/share/keyrings/packages.mozilla.org.gpg

# ================================================================================
# Step 4: Add the official Mozilla Firefox APT repository
# ================================================================================
echo "deb [signed-by=/usr/share/keyrings/packages.mozilla.org.gpg] "\
"https://packages.mozilla.org/apt mozilla main" \
  | sudo tee /etc/apt/sources.list.d/firefox.list >/dev/null

# ================================================================================
# Step 5: Pin Mozilla packages with highest priority
# ================================================================================
sudo tee /etc/apt/preferences.d/mozilla-firefox.pref >/dev/null <<EOF
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

# ================================================================================
# Step 6: Update package index and install Firefox
# ================================================================================
sudo apt-get update -y
sudo apt-get install -y firefox

# ================================================================================
# Completion Message
# ================================================================================
echo "NOTE: Firefox installed from the official Mozilla APT repository."
