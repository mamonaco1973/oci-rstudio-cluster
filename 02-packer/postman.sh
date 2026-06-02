#!/bin/bash

# Fixed Non-Snap Postman installer for Xubuntu / Ubuntu
# Downloads the official Linux 64-bit version and installs it to /opt

set -e

echo "=============================================="
echo "  Installing Postman (official non-snap version)"
echo "=============================================="

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "[1/5] Detecting latest Postman version..."
# Get the latest download URL properly (follow redirects, head only to avoid binary)
LATEST_URL=$(curl -s -L -I https://dl.pstmn.io/download/latest/linux64 | grep -i '^location:' | sed 's/.*: //' | tr -d '\r\n')

if [ -z "$LATEST_URL" ]; then
    echo "Error: Could not detect latest version. Falling back to direct link."
    DOWNLOAD_URL="https://dl.pstmn.io/download/latest/linux64"
else
    DOWNLOAD_URL="$LATEST_URL"
    echo "Detected URL: $DOWNLOAD_URL"
fi

echo "[2/5] Downloading Postman..."
curl -L -o postman.tar.gz "$DOWNLOAD_URL"

if [ ! -f postman.tar.gz ] || [ ! -s postman.tar.gz ]; then
    echo "Error: Download failed. Check your internet connection."
    exit 1
fi

echo "[3/5] Extracting to /opt/Postman..."
sudo mkdir -p /opt/Postman
sudo tar -xzf postman.tar.gz -C /opt/Postman --strip-components=1

echo "[4/5] Creating symlink..."
sudo ln -sf /opt/Postman/Postman /usr/bin/postman

echo "[5/5] Creating desktop entry..."
cat | sudo tee /usr/share/applications/postman.desktop << EOF
[Desktop Entry]
Name=Postman
Comment=API Client and Development Environment
Exec=/opt/Postman/Postman
Icon=/opt/Postman/app/resources/app/assets/icon.png
Terminal=false
Type=Application
Categories=Development;Utility;
StartupWMClass=Postman
EOF

# Clean up
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "=============================================="
echo "Postman installed successfully! (non-snap)"
echo "You can now launch it from the menu or by typing 'postman' in terminal"
echo "Location: /opt/Postman"
echo "=============================================="