#!/bin/bash
set -euo pipefail

# ================================================================================
# Desktop Icon Provisioning Script (System-Wide Defaults)
# ================================================================================
# Description:
#   Creates trusted symlinks for selected applications inside /etc/skel/Desktop.
#   These symlinks ensure that all newly created users receive desktop icons
#   without the XFCE "untrusted application launcher" warning dialog.
#
# Notes:
#   - Works for XFCE, MATE, and most desktop environments using .desktop files.
#   - Only affects *new* users created after this script runs.
#   - Symlinks are used instead of copied launchers to preserve trust flags.
# ================================================================================

# ================================================================================
# Configuration: Applications to appear on every new user's desktop
# ================================================================================
APPS=(
  /usr/share/applications/google-chrome.desktop
  /usr/share/applications/firefox.desktop
  /usr/share/applications/code.desktop
  /usr/share/applications/postman.desktop
  /usr/share/applications/onlyoffice-desktopeditors.desktop
)

SKEL_DESKTOP="/etc/skel/Desktop"

# ================================================================================
# Step 1: Ensure the skeleton Desktop directory exists
# ================================================================================
echo "NOTE: Ensuring /etc/skel/Desktop exists..."
mkdir -p "$SKEL_DESKTOP"

# ================================================================================
# Step 2: Create trusted symlinks for all selected applications
# ================================================================================
echo "NOTE: Creating trusted symlinks in /etc/skel/Desktop..."

for src in "${APPS[@]}"; do
  if [[ -f "$src" ]]; then
    filename=$(basename "$src")
    ln -sf "$src" "$SKEL_DESKTOP/$filename"
    echo "NOTE: Added $filename (trusted symlink)"
  else
    echo "WARNING: $src not found, skipping"
  fi
done

echo "NOTE: All new users will receive these desktop icons without trust prompts."

# ================================================================================================
# XFCE Screensaver Default (NEW USERS ONLY)
# -----------------------------------------------------------------------------------------------
# - Writes xfce4-screensaver.xml into /etc/skel so only NEW accounts inherit it.
# - Does NOT modify any existing user home directories.
# - Sets idle timeout (delay) to 60 minutes.
# ================================================================================================

SKEL_DIR="/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
SKEL_FILE="${SKEL_DIR}/xfce4-screensaver.xml"

# Create the skeleton config directory
sudo mkdir -p "${SKEL_DIR}"

# Create the 60-minute default screensaver config
sudo tee "${SKEL_FILE}" >/dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="mode" type="int" value="2"/>
    <property name="idle-activation" type="empty">
      <property name="delay" type="int" value="60"/>
    </property>
    <property name="themes" type="empty">
      <property name="list" type="array">
        <value type="string" value="screensavers-xfce-floaters"/>
      </property>
    </property>
  </property>
</channel>
EOF

echo "NOTE: Default XFCE screensaver timeout set to 60 minutes for NEW users."