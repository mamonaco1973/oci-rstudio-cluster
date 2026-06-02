# ==============================================================================
# Network Baseline: mini-AD VCN
# ------------------------------------------------------------------------------
# Purpose:
#   - Builds the VCN for the RStudio cluster.
#
# Scope:
#   - One VCN with:
#       - One public "vm" subnet for client workloads and the Load Balancer.
#       - One private "cluster" subnet for RStudio instance pool instances.
#       - One private "ad" subnet for the Samba 4 domain controller.
#   - Internet egress:
#       - Public subnet routes to an Internet Gateway.
#       - Private subnets route to a NAT Gateway for outbound-only access.
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
# NAT Gateway — outbound-only internet access for private subnets
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
# Public VM subnet (10.0.0.64/26):
#   - Port 80 for the Load Balancer listener (internet → LB).
#   - SSH (22) for direct management.
#   - NFS ports from vm-subnet itself (FSS mount target lives here).
#   - NFS ports from cluster-subnet (10.0.0.128/26) for instance pool access.
# Private Cluster subnet (10.0.0.128/26):
#   - Port 8787 from vm-subnet (LB health checks and traffic → RStudio).
#   - SSH from VCN CIDR for management via Bastion.
# Private AD subnet (10.0.0.0/26):
#   - Open ingress within VCN CIDR; NSG on DC handles granular port control.
# ==============================================================================

resource "oci_core_security_list" "vm_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ad_vcn.id
  display_name   = "vm-security-list"

  # Load Balancer HTTP listener — internet clients reach the LB on port 80
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  # NFS portmapper (TCP) from vm-subnet — required by FSS mount target
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.64/26"
    stateless = false
    tcp_options {
      min = 111
      max = 111
    }
  }

  # NFS portmapper (UDP) from vm-subnet
  ingress_security_rules {
    protocol  = "17"
    source    = "10.0.0.64/26"
    stateless = false
    udp_options {
      min = 111
      max = 111
    }
  }

  # NFS lockd/mountd/statd (TCP) from vm-subnet — FSS uses ports 2048-2050
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.64/26"
    stateless = false
    tcp_options {
      min = 2048
      max = 2050
    }
  }

  # NFS (UDP) from vm-subnet — FSS port 2048
  ingress_security_rules {
    protocol  = "17"
    source    = "10.0.0.64/26"
    stateless = false
    udp_options {
      min = 2048
      max = 2048
    }
  }

  # NFS portmapper (TCP) from cluster-subnet — instance pool mounts FSS here
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.128/26"
    stateless = false
    tcp_options {
      min = 111
      max = 111
    }
  }

  # NFS portmapper (UDP) from cluster-subnet
  ingress_security_rules {
    protocol  = "17"
    source    = "10.0.0.128/26"
    stateless = false
    udp_options {
      min = 111
      max = 111
    }
  }

  # NFS lockd/mountd/statd (TCP) from cluster-subnet
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.128/26"
    stateless = false
    tcp_options {
      min = 2048
      max = 2050
    }
  }

  # NFS (UDP) from cluster-subnet
  ingress_security_rules {
    protocol  = "17"
    source    = "10.0.0.128/26"
    stateless = false
    udp_options {
      min = 2048
      max = 2048
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

# Security list for cluster instances — restricts inbound to LB traffic + SSH
resource "oci_core_security_list" "cluster_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ad_vcn.id
  display_name   = "cluster-security-list"

  # RStudio port — LB health checks and proxied traffic from vm-subnet
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.64/26"
    stateless = false
    tcp_options {
      min = 8787
      max = 8787
    }
  }

  # SSH management from within the VCN (Bastion or DC jump)
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.0/24"
    stateless = false
    tcp_options {
      min = 22
      max = 22
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
#   - vm-subnet (10.0.0.64/26): Load Balancer and management instances.
#
# Private Subnets:
#   - cluster-subnet (10.0.0.128/26): RStudio instance pool (no public IPs).
#   - ad-subnet (10.0.0.0/26): Domain controller with NAT egress only.
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

# Private subnet for RStudio instance pool — NAT provides outbound-only access
resource "oci_core_subnet" "cluster_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.ad_vcn.id
  cidr_block                 = "10.0.0.128/26"
  display_name               = "cluster-subnet"
  dns_label                  = "clustersubnet"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_rt.id
  security_list_ids          = [oci_core_security_list.cluster_sl.id]
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
