#!/bin/bash
# ==============================================================================
# apply.sh - Xubuntu XRDP Deployment Orchestration (OCI)
# ------------------------------------------------------------------------------
# Three-phase build:
#   1. Deploy Active Directory resources with Terraform.
#   2. Build a Xubuntu custom image with Packer (oracle-oci plugin).
#   3. Deploy OCI compute instances using the Packer-built image.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Optional: Override AD domain settings
# Uncomment and modify to use a custom domain instead of the defaults.
# ------------------------------------------------------------------------------
# export TF_VAR_dns_zone="lab.mikecloud.com"
# export TF_VAR_realm="LAB.MIKECLOUD.COM"
# export TF_VAR_netbios="LAB"
# export TF_VAR_user_base_dn="CN=Users,DC=lab,DC=mikecloud,DC=com"

# ------------------------------------------------------------------------------
# Environment Pre-Check
# ------------------------------------------------------------------------------
echo "NOTE: Running environment validation..."
./check_env.sh

# Resolve compartment — fall back to tenancy OCID if OCI_COMPARTMENT_ID is unset
if [ -z "${OCI_COMPARTMENT_ID:-}" ]; then
  OCI_COMPARTMENT_ID=$(awk -F'=' '/^tenancy[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)
fi
export TF_VAR_compartment_ocid="$OCI_COMPARTMENT_ID"

# Dynamic groups must live in the root tenancy — always extract from config
TENANCY_OCID=$(awk -F'=' '/^tenancy[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)
export TF_VAR_tenancy_ocid="$TENANCY_OCID"

# ------------------------------------------------------------------------------
# Phase 1: Active Directory Deployment
# ------------------------------------------------------------------------------
echo "NOTE: Deploying Active Directory resources..."

cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }

terraform init

# Apply credentials first so passwords and SSH keys are committed to state
# before the mini-AD module runs — allows get_password.sh and connect.sh
# to work even if the module times out on first attempt.
terraform apply -auto-approve \
  -target=tls_private_key.ssh \
  -target=local_file.private_key \
  -target=local_file.public_key \
  -target=random_password.admin_password \
  -target=random_password.jsmith_password \
  -target=random_password.edavis_password \
  -target=random_password.rpatel_password \
  -target=random_password.akumar_password \
  -target=random_password.windows_local_admin_password

terraform apply -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Phase 2: Build Xubuntu Custom Image with Packer
# ------------------------------------------------------------------------------
# Resolve the build parameters from OCI CLI + 01-directory outputs before
# invoking Packer so the build instance lands in the correct subnet.
# ------------------------------------------------------------------------------
echo "NOTE: Resolving Packer build parameters..."

SUBNET_OCID=$(cd 01-directory && terraform output -raw vm_subnet_ocid)

AD=$(oci iam availability-domain list \
  --compartment-id "$OCI_COMPARTMENT_ID" \
  --query 'data[0].name' \
  --raw-output)

# Get the latest Canonical Ubuntu 24.04 image OCID for E4.Flex
BASE_IMAGE_OCID=$(oci compute image list \
  --compartment-id "$OCI_COMPARTMENT_ID" \
  --operating-system "Canonical Ubuntu" \
  --operating-system-version "24.04" \
  --shape "VM.Standard.E4.Flex" \
  --lifecycle-state "AVAILABLE" \
  --sort-by TIMECREATED \
  --sort-order DESC \
  --query 'data[0].id' \
  --raw-output)

echo "NOTE: Availability domain : $AD"
echo "NOTE: Base image OCID     : $BASE_IMAGE_OCID"
echo "NOTE: Subnet OCID         : $SUBNET_OCID"

cd 02-packer || { echo "ERROR: Directory 02-packer not found"; exit 1; }

echo "NOTE: Building Xubuntu custom image with Packer..."

packer init ./xubuntu_ami.pkr.hcl
packer build \
  -var "compartment_ocid=$OCI_COMPARTMENT_ID" \
  -var "availability_domain=$AD" \
  -var "base_image_ocid=$BASE_IMAGE_OCID" \
  -var "subnet_ocid=$SUBNET_OCID" \
  ./xubuntu_ami.pkr.hcl || {
    echo "ERROR: Packer build failed. Aborting."
    cd ..
    exit 1
  }

cd ..

# Resolve the OCID of the image Packer just created
XUBUNTU_IMAGE_OCID=$(oci compute image list \
  --compartment-id "$OCI_COMPARTMENT_ID" \
  --lifecycle-state "AVAILABLE" \
  --all \
  --raw-output \
  | jq -r '[.data[] | select(."display-name" == "xubuntu-image")] | sort_by(."time-created") | last | .id')

if [ -z "$XUBUNTU_IMAGE_OCID" ] || [ "$XUBUNTU_IMAGE_OCID" = "null" ]; then
  echo "ERROR: Could not find xubuntu-image in OCI compute images after Packer build."
  exit 1
fi
export TF_VAR_xubuntu_image_ocid="$XUBUNTU_IMAGE_OCID"
echo "NOTE: Xubuntu image OCID  : $XUBUNTU_IMAGE_OCID"

# ------------------------------------------------------------------------------
# Phase 3: Deploy OCI Compute Instances
# ------------------------------------------------------------------------------
echo "NOTE: Deploying OCI compute instances..."

cd 03-servers || { echo "ERROR: Directory 03-servers not found"; exit 1; }

terraform init
terraform apply -auto-approve

cd ..

./validate.sh
