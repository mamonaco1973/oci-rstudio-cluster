#!/bin/bash
set -euo pipefail

# ================================================================================
# Google Cloud SDK Installation Script (Conditional Install)
# ================================================================================
# Description:
#   Checks whether the Google Cloud SDK (gcloud) is already installed. If not,
#   the script adds the official Google Cloud APT repository, installs the
#   public signing key, updates the package index, and installs the SDK.
#
# Notes:
#   - apt-get is used for stable automation behavior.
#   - Keyrings are stored securely under /usr/share/keyrings.
#   - No action is taken if gcloud is already present in the PATH.
# ================================================================================

# ================================================================================
# Step 1: Check for gcloud; install only if missing
# ================================================================================
if ! command -v gcloud >/dev/null 2>&1; then
  echo "NOTE: gcloud not found. Installing Google Cloud SDK..."

  # ============================================================================
  # Step 2: Add Google Cloud APT repository
  # ============================================================================
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] "\
"https://packages.cloud.google.com/apt cloud-sdk main" \
    | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null

  # ============================================================================
  # Step 3: Import Google Cloud public signing key
  # ============================================================================
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | sudo gpg --dearmor \
    -o /usr/share/keyrings/cloud.google.gpg

  # ============================================================================
  # Step 4: Update package index and install the SDK
  # ============================================================================
  sudo apt-get update -y
  sudo apt-get install -y google-cloud-sdk

  echo "NOTE: Google Cloud SDK installation complete."
else
  echo "NOTE: gcloud already installed."
fi

# ================================================================================
# Step 5: Display version information
# ================================================================================
gcloud --version
