#!/bin/bash
set -euo pipefail

# ==============================================================================
# OCI CLI Installation
# ------------------------------------------------------------------------------
# Installs the OCI CLI into a Python venv at /opt/oci-venv and symlinks the
# binary to /usr/local/bin/oci.
#
# Ubuntu 24.04 ships urllib3 without a RECORD file, which blocks pip's
# dependency resolver. Installing into a venv isolates it from the
# Debian-managed packages and avoids the conflict entirely.
# ==============================================================================

python3 -m venv /opt/oci-venv
/opt/oci-venv/bin/pip install --quiet oci-cli
ln -sf /opt/oci-venv/bin/oci /usr/local/bin/oci
