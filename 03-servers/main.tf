# ==============================================================================
# Provider and Data Sources
# ------------------------------------------------------------------------------
# Purpose:
#   - Configures the OCI provider.
#   - Reads outputs from 01-directory via terraform_remote_state.
#   - Resolves Ubuntu and Windows images for compute instance provisioning.
# ==============================================================================

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Unique 4-hex suffix so each deploy gets fresh computer account names —
# prevents domain join conflicts if old accounts still exist in AD after destroy.
resource "random_id" "server_suffix" {
  byte_length = 2
}

provider "oci" {
  region = "us-ashburn-1"
}

# ==============================================================================
# Remote State: 01-directory
# Reads compartment, VCN, subnet, admin credentials, and SSH key outputs.
# ==============================================================================

data "terraform_remote_state" "directory" {
  backend = "local"
  config = {
    path = "../01-directory/terraform.tfstate"
  }
}

locals {
  compartment_ocid = data.terraform_remote_state.directory.outputs.compartment_ocid
  vcn_id           = data.terraform_remote_state.directory.outputs.vcn_id
  vm_subnet_ocid   = data.terraform_remote_state.directory.outputs.vm_subnet_ocid
  admin_password               = data.terraform_remote_state.directory.outputs.admin_password
  ssh_public_key               = data.terraform_remote_state.directory.outputs.ssh_public_key
  dc_private_ip                = data.terraform_remote_state.directory.outputs.dc_private_ip
  windows_local_admin_password = data.terraform_remote_state.directory.outputs.windows_local_admin_password
  xubuntu_hostname = "xubuntu-${random_id.server_suffix.hex}"
  windows_hostname = "win-${random_id.server_suffix.hex}"
}

# ==============================================================================
# Availability Domain
# ==============================================================================

data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_ocid
}

# ==============================================================================
# Windows Server 2022 Image
# ==============================================================================

data "oci_core_images" "windows" {
  compartment_id           = local.compartment_ocid
  operating_system         = "Windows"
  operating_system_version = "Server 2022 Standard"
  shape                    = "VM.Standard.E4.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
