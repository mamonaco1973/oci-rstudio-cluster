# ==============================================================================
# OCI Compute Instance: Windows AD Client
# ------------------------------------------------------------------------------
# Purpose:
#   - Deploys a Windows Server 2022 instance joined to the mini-AD domain.
#   - Bootstrapped via cloudbase-init PowerShell user_data.
#   - Launched into the public subnet for RDP access.
# ==============================================================================

resource "oci_core_instance" "windows_ad_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = local.compartment_ocid
  shape               = "VM.Standard.E4.Flex"
  display_name        = local.windows_hostname

  shape_config {
    ocpus         = 2
    memory_in_gbs = 8
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.windows.images[0].id
  }

  create_vnic_details {
    subnet_id        = local.vm_subnet_ocid
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.rdp_nsg.id]
  }

  metadata = {
    user_data = base64encode(templatefile("./scripts/userdata.ps1", {
      admin_password               = local.admin_password
      windows_local_admin_password = local.windows_local_admin_password
      domain_fqdn                  = var.dns_zone
      netbios                      = var.netbios
      # Linux instance private IP — Windows maps Z: to \\<samba_server>\efs
      samba_server                 = oci_core_instance.xubuntu_instance.private_ip
    }))
  }

  depends_on = [oci_core_instance.xubuntu_instance]
}

output "windows_public_ip" {
  description = "Public IP of the Windows AD client instance."
  value       = oci_core_instance.windows_ad_instance.public_ip
}
