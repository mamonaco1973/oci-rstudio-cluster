#!/bin/bash
set -e

# ================================================================================
# KRDC Installation Script (Ubuntu 24.04)
# ================================================================================
# Description:
#   Installs the KDE Remote Desktop Client (KRDC) on Ubuntu 24.04 for use as a
#   lightweight, stable RDP client alternative to Remmina on Xfce/Xubuntu builds.
#
# Notes:
#   - Installs only APT-based packages (no Snap, no PPAs required).
#   - KRDC supports native RDP and VNC connections.
#   - Script exits immediately on any error due to 'set -e'.
# ================================================================================

# ================================================================================
# Step 1: Update the APT package index
# ================================================================================
sudo apt-get update -y

# ================================================================================
# Step 2: Install KRDC and dependencies
# ================================================================================
sudo apt-get install -y krdc 

# ================================================================================
# Step 3: Completion message
# ================================================================================
echo "NOTE: KRDC installation complete."
