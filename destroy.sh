#!/bin/bash
# ==============================================================================
# destroy.sh - RStudio Cluster Infrastructure Teardown (OCI)
# ------------------------------------------------------------------------------
# Destroys the environment in controlled reverse order:
#   1. RStudio cluster (04-cluster): LB and Instance Pool.
#   2. Packer-built custom RStudio image.
#   3. Servers (02-servers): FSS, Linux gateway, Windows client.
#   4. Active Directory resources and networking (01-directory).
#
# WARNING: This action is destructive and irreversible.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Optional: Override AD domain settings (must match apply.sh values)
# ------------------------------------------------------------------------------
# export TF_VAR_dns_zone="lab.mikecloud.com"
# export TF_VAR_realm="LAB.MIKECLOUD.COM"
# export TF_VAR_netbios="LAB"
# export TF_VAR_user_base_dn="CN=Users,DC=lab,DC=mikecloud,DC=com"

# Resolve compartment — fall back to tenancy OCID if OCI_COMPARTMENT_ID is unset
if [ -z "${OCI_COMPARTMENT_ID:-}" ]; then
  OCI_COMPARTMENT_ID=$(awk -F'=' '/^tenancy[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)
fi
export TF_VAR_compartment_ocid="$OCI_COMPARTMENT_ID"

TENANCY_OCID=$(awk -F'=' '/^tenancy[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)
export TF_VAR_tenancy_ocid="$TENANCY_OCID"

# TF_VAR_rstudio_image_ocid must be set for terraform destroy to parse the plan
export TF_VAR_rstudio_image_ocid="ocid1.image.placeholder"

# ------------------------------------------------------------------------------
# Phase 1: Destroy RStudio Cluster
# ------------------------------------------------------------------------------
echo "NOTE: Destroying RStudio cluster (LB, Instance Pool)..."

cd 04-cluster || { echo "ERROR: Directory 04-cluster not found"; exit 1; }

terraform init
terraform destroy -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Phase 2: Delete Packer-Built Custom Image
# ------------------------------------------------------------------------------
# The rstudio-image is not managed by Terraform — must be deleted via OCI CLI.
# ------------------------------------------------------------------------------
echo "NOTE: Deleting Packer-built RStudio custom image..."

IMAGE_IDS=$(oci compute image list \
  --compartment-id "$OCI_COMPARTMENT_ID" \
  --lifecycle-state "AVAILABLE" \
  --all \
  --raw-output \
  | jq -r '.data[] | select(."display-name" == "rstudio-image") | .id')

if [ -z "$IMAGE_IDS" ]; then
  echo "NOTE: No rstudio-image custom images found."
else
  for IMAGE_ID in $IMAGE_IDS; do
    echo "NOTE: Deleting image: $IMAGE_ID"
    oci compute image delete --image-id "$IMAGE_ID" --force
  done
fi

# ------------------------------------------------------------------------------
# Phase 3: Destroy Servers (FSS, Linux gateway, Windows client)
# ------------------------------------------------------------------------------
echo "NOTE: Destroying servers (FSS, Linux gateway, Windows client)..."

cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }

terraform init
terraform destroy -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Phase 4: Destroy Active Directory Infrastructure
# ------------------------------------------------------------------------------
echo "NOTE: Destroying Active Directory resources and networking..."

cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }

terraform init
terraform destroy -auto-approve

cd ..

# Remove generated key pair so next apply produces a fresh one
rm -f 01-directory/keys/Private_Key 01-directory/keys/Private_Key.pub

echo "NOTE: Infrastructure destruction complete."
