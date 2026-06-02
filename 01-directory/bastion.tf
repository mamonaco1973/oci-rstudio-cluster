# ==============================================================================
# OCI Bastion Service
# ------------------------------------------------------------------------------
# Purpose:
#   - Provides managed SSH access to the private AD DC instance without
#     exposing it to the public internet.
#   - Port-forwarding sessions require no OCI agent on the target instance.
#
# Usage (after apply):
#   See validate.sh for the full OCI CLI + SSH commands to connect.
# ==============================================================================

resource "oci_bastion_bastion" "ad_bastion" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_ocid
  # Targets the private subnet where the DC lives
  target_subnet_id = oci_core_subnet.ad_subnet.id
  name             = "mini-ad-bastion"

  # Restrict to your IP in production
  client_cidr_block_allow_list = ["0.0.0.0/0"]
}
