# ==============================================================================
# Network Baseline: mini-AD VCN
# ------------------------------------------------------------------------------
# Purpose:
#   - Builds the VCN for the mini-AD quick start.
#
# Scope:
#   - One VCN with:
#       - Two public "vm" subnets for client workloads.
#       - One private "ad" subnet for the Samba 4 domain controller.
#   - Internet egress:
#       - Public subnets route to an Internet Gateway.
#       - Private subnet routes to a NAT Gateway for outbound-only access.
#
# Notes:
#   - OCI security lists attach at the subnet level (unlike AWS SGs per instance).
#   - NSGs on the DC instance handle AD-specific port control (see module).
# ==============================================================================

# ==============================================================================
# VCN
# ==============================================================================

resource "oci_core_vcn" "ad_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/24"
  display_name   = var.vcn_name
  # dns_label must be alphanumeric <= 15 chars
  dns_label      = "miniadvcn"
}

# ==============================================================================
# Internet Gateway
# ==============================================================================

resource "oci_core_internet_gateway" "ad_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ad_vcn.id
  display_name   = "ad-igw"
  enabled        = true
}

# ==============================================================================
# NAT Gateway – outbound-only internet access for the private AD subnet
# ==============================================================================

resource "oci_core_nat_gateway" "ad_nat" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ad_vcn.id
  display_name   = "ad-nat"
}

# ==============================================================================
# Route Tables
# ==============================================================================

resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ad_vcn.id
  display_name   = "public-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.ad_igw.id
  }
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ad_vcn.id
  display_name   = "private-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.ad_nat.id
  }
}

# ==============================================================================
# Security Lists
# ------------------------------------------------------------------------------
# Public VM subnet: SSH (22), RDP (3389), NFS (111/2048-2050), SMB (445).
#   NFS rules allow the Linux instance to reach the FSS mount target
#   (both in vm-subnet). SMB allows Windows to reach the Samba gateway.
# Private AD subnet: Open ingress within VCN CIDR so clients can reach AD ports.
#   The module NSG handles granular port control on the DC instance itself.
# ==============================================================================

resource "oci_core_security_list" "vm_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ad_vcn.id
  display_name   = "vm-security-list"

  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 3389
      max = 3389
    }
  }

  # NFS portmapper (TCP) — required by FSS mount target
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.64/26"
    stateless = false
    tcp_options {
      min = 111
      max = 111
    }
  }

  # NFS portmapper (UDP) — required by FSS mount target
  ingress_security_rules {
    protocol  = "17"
    source    = "10.0.0.64/26"
    stateless = false
    udp_options {
      min = 111
      max = 111
    }
  }

  # NFS lockd/mountd/statd (TCP) — FSS uses ports 2048-2050
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.64/26"
    stateless = false
    tcp_options {
      min = 2048
      max = 2050
    }
  }

  # NFS (UDP) — FSS port 2048
  ingress_security_rules {
    protocol  = "17"
    source    = "10.0.0.64/26"
    stateless = false
    udp_options {
      min = 2048
      max = 2048
    }
  }

  # SMB — Windows clients connect to the Linux Samba gateway on 445
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.64/26"
    stateless = false
    tcp_options {
      min = 445
      max = 445
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

resource "oci_core_security_list" "ad_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ad_vcn.id
  display_name   = "ad-security-list"

  # Allow all ingress from within the VCN — AD ports are further controlled by NSG
  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/24"
    stateless = false
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

# ==============================================================================
# Subnets
# ------------------------------------------------------------------------------
# Public Subnet:
#   - vm-subnet: Client workloads with public IP (Linux + Windows instances).
#
# Private Subnet:
#   - ad-subnet: Domain controller with NAT egress only.
# ==============================================================================

resource "oci_core_subnet" "vm_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.ad_vcn.id
  cidr_block        = "10.0.0.64/26"
  display_name      = "vm-subnet"
  dns_label         = "vmsubnet"
  route_table_id    = oci_core_route_table.public_rt.id
  security_list_ids = [oci_core_security_list.vm_sl.id]
}

resource "oci_core_subnet" "ad_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.ad_vcn.id
  cidr_block        = "10.0.0.0/26"
  display_name      = "ad-subnet"
  dns_label         = "adsubnet"
  # Prevent public IP assignment on DC VNIC
  prohibit_public_ip_on_vnic = true
  route_table_id    = oci_core_route_table.private_rt.id
  security_list_ids = [oci_core_security_list.ad_sl.id]
}
