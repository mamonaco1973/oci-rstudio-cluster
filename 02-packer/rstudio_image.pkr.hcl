# ==============================================================================
# Packer Build: RStudio Server Custom Image on OCI Ubuntu 24.04 (Noble)
# ------------------------------------------------------------------------------
# Purpose:
#   - Build a custom OCI compute image with R and RStudio Server pre-installed.
#   - Start from the Canonical Ubuntu 24.04 base image in OCI.
#   - Run provisioning scripts to bake in R dev libraries, RStudio, AD packages.
#   - Output a named custom image for Terraform to reference in 03-servers.
#
# Notes:
#   - compartment_ocid, availability_domain, base_image_ocid, and subnet_ocid
#     are passed in from apply.sh after resolving them via the OCI CLI.
#   - The build instance requires outbound internet access (vm-subnet has IGW).
# ==============================================================================

packer {
  required_plugins {
    oracle = {
      source  = "github.com/hashicorp/oracle"
      version = "~> 1"
    }
  }
}

# ------------------------------------------------------------------------------
# Variables: Build-Time Inputs
# Resolved by apply.sh from OCI CLI + 01-directory terraform outputs.
# ------------------------------------------------------------------------------

variable "compartment_ocid" {
  description = "OCI compartment OCID for the build instance."
  default     = ""
}

variable "availability_domain" {
  description = "Availability domain for the temporary build instance."
  default     = ""
}

variable "base_image_ocid" {
  description = "OCID of the base Ubuntu 24.04 image to build from."
  default     = ""
}

variable "subnet_ocid" {
  description = "OCID of the vm-subnet — build instance needs public internet access."
  default     = ""
}

# ------------------------------------------------------------------------------
# Oracle-OCI Source Block
# Launches a temporary OCI instance, runs provisioners, then saves the result
# as a custom compute image in the compartment.
# ------------------------------------------------------------------------------

source "oracle-oci" "rstudio" {
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  base_image_ocid     = var.base_image_ocid
  image_name          = "rstudio-image"
  shape               = "VM.Standard.E4.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 16
  }

  create_vnic_details {
    subnet_id        = var.subnet_ocid
    assign_public_ip = true
  }

  disk_size    = 64
  ssh_username = "ubuntu"
}

# ------------------------------------------------------------------------------
# Build Block: Provisioning Scripts
# Packages are baked here so rstudio_booter.sh at runtime only handles
# domain join, FSS mounts, and R library path configuration.
# ------------------------------------------------------------------------------

build {
  sources = ["source.oracle-oci.rstudio"]

  # Install base AD/NFS packages and R development libraries.
  provisioner "shell" {
    script          = "./packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install OCI CLI into /opt/oci-venv.
  provisioner "shell" {
    script          = "./ocicli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install R base and RStudio Server with PAM/AD config.
  provisioner "shell" {
    script          = "./rstudio.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install AWS CLI v2.
  provisioner "shell" {
    script          = "./awscli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Azure CLI.
  provisioner "shell" {
    script          = "./azcli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Google Cloud CLI.
  provisioner "shell" {
    script          = "./gcloudcli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install HashiCorp tools (Terraform, Packer).
  provisioner "shell" {
    script          = "./hashicorp.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Docker CE.
  provisioner "shell" {
    script          = "./docker.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
