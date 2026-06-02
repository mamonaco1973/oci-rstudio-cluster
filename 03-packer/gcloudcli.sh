#!/bin/bash
set -euo pipefail

# ================================================================================
# Google Cloud SDK Installation Script (Conditional Install)
# ================================================================================

if ! command -v gcloud >/dev/null 2>&1; then
  echo "NOTE: gcloud not found. Installing Google Cloud SDK..."

  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] "\
"https://packages.cloud.google.com/apt cloud-sdk main" \
    | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null

  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | sudo gpg --dearmor \
    -o /usr/share/keyrings/cloud.google.gpg

  sudo apt-get update -y
  sudo apt-get install -y google-cloud-sdk

  echo "NOTE: Google Cloud SDK installation complete."
else
  echo "NOTE: gcloud already installed."
fi

gcloud --version
