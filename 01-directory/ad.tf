# ==============================================================================
# Mini Active Directory (mini-ad) - Module Invocation
# ------------------------------------------------------------------------------
# Purpose:
#   - Invokes the reusable OCI mini-ad module to deploy a Samba 4 AD DC.
#
# Notes:
#   - Ensure NAT gateway and route table associations exist before provisioning
#     (depends_on) — the DC bootstrap needs outbound internet for apt packages.
# ==============================================================================

module "mini_ad" {
  source = "github.com/mamonaco1973/module-oci-mini-ad"

  compartment_id = var.compartment_ocid
  tenancy_ocid   = var.tenancy_ocid

  # Domain identity
  netbios      = var.netbios
  realm        = var.realm
  dns_zone     = var.dns_zone
  user_base_dn = var.user_base_dn
  users_json   = local.users_json

  # Authentication
  ad_admin_password = local.admin_password

  # Networking — DC placed in private subnet; module updates VCN default DHCP
  vcn_id                      = oci_core_vcn.ad_vcn.id
  vcn_default_dhcp_options_id = oci_core_vcn.ad_vcn.default_dhcp_options_id
  subnet_ocid                 = oci_core_subnet.ad_subnet.id

  # SSH key for management access
  ssh_public_key = tls_private_key.ssh.public_key_openssh

  depends_on = [
    oci_core_nat_gateway.ad_nat,
    oci_core_route_table.private_rt,
  ]
}

# ==============================================================================
# Seed user JSON — injected into the DC bootstrap to create demo accounts
# ==============================================================================

locals {
  users_json = templatefile("./scripts/users.json.template", {
    USER_BASE_DN = var.user_base_dn
    DNS_ZONE     = var.dns_zone
    REALM        = var.realm
    NETBIOS      = var.netbios

    jsmith_password = local.jsmith_password
    edavis_password = local.edavis_password
    rpatel_password = local.rpatel_password
    akumar_password = local.akumar_password
  })
}

# ==============================================================================
# Outputs consumed by 02-servers via terraform_remote_state
# ==============================================================================

output "compartment_ocid" {
  description = "Compartment OCID for 02-servers to provision into."
  value       = var.compartment_ocid
}

output "vcn_id" {
  description = "VCN OCID for NSG and subnet lookups in 02-servers."
  value       = oci_core_vcn.ad_vcn.id
}

output "vm_subnet_ocid" {
  description = "OCID of vm-subnet for client instance placement."
  value       = oci_core_subnet.vm_subnet.id
}

output "admin_password" {
  description = "AD admin password for domain join in 02-servers userdata."
  value       = local.admin_password
  sensitive   = true
}

output "jsmith_password" {
  value     = local.jsmith_password
  sensitive = true
}

output "edavis_password" {
  value     = local.edavis_password
  sensitive = true
}

output "rpatel_password" {
  value     = local.rpatel_password
  sensitive = true
}

output "akumar_password" {
  value     = local.akumar_password
  sensitive = true
}

output "ssh_public_key" {
  description = "SSH public key for authorizing on client instances."
  value       = tls_private_key.ssh.public_key_openssh
}

output "dc_private_ip" {
  description = "Private IP of the AD DC — used as the bastion session target."
  value       = module.mini_ad.dns_server
}

output "bastion_id" {
  description = "OCID of the OCI Bastion for creating SSH sessions."
  value       = oci_bastion_bastion.ad_bastion.id
}

output "dns_zone" {
  description = "AD DNS zone — used by get_password.sh to display fully-qualified usernames."
  value       = var.dns_zone
}

output "netbios" {
  description = "NetBIOS domain name — used by validate.sh for RDP connection hints."
  value       = var.netbios
}

output "windows_local_admin_password" {
  description = "Local admin password for the Windows instance — RDP fallback."
  value       = local.windows_local_admin_password
  sensitive   = true
}
