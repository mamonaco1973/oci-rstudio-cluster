#!/bin/bash
set -euo pipefail

# ================================================================================
# Xubuntu Minimal Desktop + XFCE Enhancements Installation Script
# ================================================================================
# Description:
#   Installs the Xubuntu minimal desktop environment along with clipboard tools,
#   terminal emulator utilities, and XFCE enhancements. The script also sets the
#   system-wide default terminal emulator and updates the default background
#   image by modifying the XFCE wallpaper assets. Desktop shortcuts are enabled
#   for all future users by preparing /etc/skel/Desktop.
#
# Notes:
#   - Uses apt-get for stable automation behavior.
#   - XFCE background modification replaces the shapes wallpaper with leaves.
#   - Script exits immediately on any error due to 'set -euo pipefail'.
# ================================================================================

# ================================================================================
# Step 1: Install Xubuntu minimal desktop environment
# ================================================================================
sudo apt-get update -y
sudo apt-get install -y xubuntu-desktop-minimal

# ================================================================================
# Step 2: Install clipboard utilities and XFCE enhancements
# ================================================================================
sudo apt-get install -y \
  xfce4-clipman \
  xfce4-clipman-plugin \
  xsel \
  xclip

sudo apt-get install -y \
  xfce4-terminal \
  xfce4-goodies \
  xdg-utils

# ================================================================================
# Step 3: Set XFCE Terminal as the system-wide default terminal emulator
# ================================================================================
sudo update-alternatives --install \
  /usr/bin/x-terminal-emulator \
  x-terminal-emulator \
  /usr/bin/xfce4-terminal \
  50

# ================================================================================
# Step 4: Ensure new users receive a Desktop folder
# ================================================================================
sudo mkdir -p /etc/skel/Desktop

# ================================================================================
# Step 5: Replace default XFCE background image
# ================================================================================
cd /usr/share/backgrounds/xfce

# Backup the original wallpaper to preserve system assets
sudo mv xfce-shapes.svg xfce-shapes.svg.bak

# Replace wallpaper with a known-good XFCE SVG file
sudo cp xfce-leaves.svg xfce-shapes.svg
echo "NOTE: Xubuntu minimal desktop and XFCE enhancements installation complete."

