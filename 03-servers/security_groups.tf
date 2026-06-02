# ==============================================================================
# Network Security Groups: Remote Access (Lab Defaults)
# ------------------------------------------------------------------------------
# Purpose:
#   - NSG for Linux instances: SSH (22), SMB (445).
#   - NSG for Windows instances: RDP (3389).
# NOTE: Open to 0.0.0.0/0 for lab convenience — restrict in production.
# SMB ingress is scoped to vm-subnet CIDR — only Windows (same subnet) connects.
# ==============================================================================

# ==============================================================================
# NSG: SSH (Linux)
# ==============================================================================

resource "oci_core_network_security_group" "ssh_nsg" {
  compartment_id = local.compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = "ad-ssh-nsg"
}

resource "oci_core_network_security_group_security_rule" "ssh_ingress" {
  network_security_group_id = oci_core_network_security_group.ssh_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
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

# ==============================================================================
# NSG: SMB (Linux Samba gateway — Windows maps Z: to \\<linux-ip>\efs)
# ==============================================================================

resource "oci_core_network_security_group" "smb_nsg" {
  compartment_id = local.compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = "ad-smb-nsg"
}

resource "oci_core_network_security_group_security_rule" "smb_ingress" {
  network_security_group_id = oci_core_network_security_group.smb_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  # Scoped to vm-subnet — only Windows instance (same subnet) connects
  source                    = "10.0.0.64/26"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 445
      max = 445
    }
  }
}

resource "oci_core_network_security_group_security_rule" "smb_egress" {
  network_security_group_id = oci_core_network_security_group.smb_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# ==============================================================================
# NSG: RDP (Windows)
# ==============================================================================

resource "oci_core_network_security_group" "rdp_nsg" {
  compartment_id = local.compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = "ad-rdp-nsg"
}

resource "oci_core_network_security_group_security_rule" "rdp_ingress" {
  network_security_group_id = oci_core_network_security_group.rdp_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 3389
      max = 3389
    }
  }
}

resource "oci_core_network_security_group_security_rule" "rdp_egress" {
  network_security_group_id = oci_core_network_security_group.rdp_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}
