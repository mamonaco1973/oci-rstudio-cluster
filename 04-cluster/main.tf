# ==============================================================================
# Provider and Data Sources
# ------------------------------------------------------------------------------
# Reads outputs from both 01-directory (credentials, subnets) and
# 02-servers (FSS mount target IP) via terraform_remote_state.
# ==============================================================================

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  region = "us-ashburn-1"
}

# ==============================================================================
# Remote State: 01-directory
# ==============================================================================

data "terraform_remote_state" "directory" {
  backend = "local"
  config = {
    path = "../01-directory/terraform.tfstate"
  }
}

# ==============================================================================
# Remote State: 02-servers
# Provides the FSS mount target IP so cluster instances can mount /nfs.
# ==============================================================================

data "terraform_remote_state" "servers" {
  backend = "local"
  config = {
    path = "../02-servers/terraform.tfstate"
  }
}

locals {
  compartment_ocid    = data.terraform_remote_state.directory.outputs.compartment_ocid
  vcn_id              = data.terraform_remote_state.directory.outputs.vcn_id
  vm_subnet_ocid      = data.terraform_remote_state.directory.outputs.vm_subnet_ocid
  cluster_subnet_ocid = data.terraform_remote_state.directory.outputs.cluster_subnet_ocid
  admin_password      = data.terraform_remote_state.directory.outputs.admin_password
  ssh_public_key      = data.terraform_remote_state.directory.outputs.ssh_public_key
  mount_target_ip     = data.terraform_remote_state.servers.outputs.mount_target_ip
}

# ==============================================================================
# Availability Domain
# ==============================================================================

data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_ocid
}
