# ==============================================================================
# Packer Build: Xubuntu Custom Image on OCI Ubuntu 24.04 (Noble)
# ------------------------------------------------------------------------------
# Purpose:
#   - Build a custom OCI compute image with Xubuntu + XRDP pre-installed.
#   - Start from the Canonical Ubuntu 24.04 base image in OCI.
#   - Run provisioning scripts to install the desktop, tools, and AD packages.
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
# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------
# Launches a temporary OCI instance, runs provisioners, then saves the result
# as a custom compute image in the compartment.
# ------------------------------------------------------------------------------

source "oracle-oci" "xubuntu" {
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  base_image_ocid     = var.base_image_ocid
  image_name          = "xubuntu-image"
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
# ------------------------------------------------------------------------------
# Runs scripts in order to install desktop components and developer tooling.
# Package installation happens here (baked into image) so userdata.sh at
# runtime only needs to handle domain join, FSS mounts, and Samba config.
# ------------------------------------------------------------------------------

build {
  sources = ["source.oracle-oci.xubuntu"]

  # Install base AD/NFS packages and OCI CLI.
  provisioner "shell" {
    script          = "./packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install OCI CLI into /opt/oci-venv.
  provisioner "shell" {
    script          = "./ocicli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Xubuntu desktop (xfce4 + xubuntu-core).
  provisioner "shell" {
    script          = "./xubuntu.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install XRDP (RDP server for remote desktop access).
  provisioner "shell" {
    script          = "./xrdp.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Google Chrome.
  provisioner "shell" {
    script          = "./chrome.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Firefox.
  provisioner "shell" {
    script          = "./firefox.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install VS Code.
  provisioner "shell" {
    script          = "./vscode.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install HashiCorp tools (Terraform, Packer, Consul).
  provisioner "shell" {
    script          = "./hashicorp.sh"
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

  # Install Docker.
  provisioner "shell" {
    script          = "./docker.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Postman.
  provisioner "shell" {
    script          = "./postman.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install KRDC (RDP client for connecting to other desktops).
  provisioner "shell" {
    script          = "./krdc.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install OnlyOffice.
  provisioner "shell" {
    script          = "./onlyoffice.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install desktop shortcuts and /etc/skel customizations.
  provisioner "shell" {
    script          = "./desktop.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
