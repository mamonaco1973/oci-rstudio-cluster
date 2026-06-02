#!/bin/bash
# ==============================================================================
# check_env.sh - Environment Validation
# ==============================================================================

set -euo pipefail

echo "NOTE: Validating required commands in PATH."

commands=("oci" "terraform" "jq" "packer")

for cmd in "${commands[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${cmd}"
    exit 1
  fi
  echo "NOTE: Found required command: ${cmd}"
done

echo "NOTE: All required commands are available."

# ------------------------------------------------------------------------------
# OCI Auth Check
# ------------------------------------------------------------------------------
echo "NOTE: Checking OCI_COMPARTMENT_ID environment variable."
if [ -z "${OCI_COMPARTMENT_ID:-}" ]; then
  tenancy=$(awk -F'=' '/^tenancy[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)
  if [ -z "$tenancy" ]; then
    echo "ERROR: OCI_COMPARTMENT_ID is not set and tenancy could not be read from ~/.oci/config."
    exit 1
  fi
  echo "WARNING: OCI_COMPARTMENT_ID not set — will use tenancy OCID from ~/.oci/config."
else
  echo "NOTE: OCI_COMPARTMENT_ID is set."
fi

echo "NOTE: Checking OCI CLI connection."
if ! oci os ns get > /dev/null 2>&1; then
  echo "ERROR: Failed to connect to OCI. Check your ~/.oci/config."
  exit 1
fi

echo "NOTE: OCI CLI authentication successful."
