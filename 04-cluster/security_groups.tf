# ==============================================================================
# Network Security Groups: RStudio Cluster Instances
# ------------------------------------------------------------------------------
# SSH NSG attached to instance pool instances for management access via
# the OCI Bastion. RStudio port 8787 is controlled at the security list
# level (cluster_sl in 01-directory/networking.tf).
# ==============================================================================

resource "oci_core_network_security_group" "ssh_nsg" {
  compartment_id = local.compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = "rstudio-ssh-nsg"
}

resource "oci_core_network_security_group_security_rule" "ssh_ingress" {
  network_security_group_id = oci_core_network_security_group.ssh_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "10.0.0.0/24"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "ssh_egress" {
  network_security_group_id = oci_core_network_security_group.ssh_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}
