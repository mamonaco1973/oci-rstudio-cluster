#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

cd /tmp
wget -q https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb
apt-get install -y ./onlyoffice-desktopeditors_amd64.deb
rm onlyoffice-desktopeditors_amd64.deb

