# ==============================================================================
# OCI Vault
# ------------------------------------------------------------------------------
# The resources below were originally active. They provisioned an OCI KMS Vault
# with an AES-256 encryption key and six versioned secrets (one per AD account).
# Each secret held a BASE64-encoded JSON blob: { username, password }. The Linux
# client fetched its domain-join credential at boot via instance principal auth
# (compartment-scoped dynamic group + IAM policy in 02-servers/roles.tf), so no
# plaintext password ever appeared in instance metadata. get_password.sh called
# the OCI Secrets API to retrieve credentials on demand.
#
# Why this was removed:
#   OCI enforces a mandatory 30-day pending-deletion hold on KMS vaults after
#   destroy. During that hold the vault still counts against the tenancy service
#   limit (default: 1 vault even on pay-as-you-go). This makes the vault
#   incompatible with destroy/rebuild IAC workflows — every fresh apply after a
#   destroy hits LimitExceeded because the prior vault is still in
#   PENDING_DELETION. Cancelling deletion and importing the vault back into state
#   is a manual workaround that defeats repeatable automation. AWS and Azure both
#   handle key vault deletion gracefully; this is an OCI design deficiency.
#
# Current approach:
#   Passwords live in terraform.tfstate as sensitive outputs. The admin password
#   is injected into the Linux client via templatefile at apply time, matching
#   the same pattern used for the Windows instance. get_password.sh reads
#   credentials directly from terraform output.
# ==============================================================================

# resource "random_id" "vault_suffix" {
#   byte_length = 4
# }
#
# resource "oci_kms_vault" "ad_vault" {
#   compartment_id = var.compartment_ocid
#   display_name   = "mini-ad-vault-${random_id.vault_suffix.hex}"
#   vault_type     = "DEFAULT"
# }
#
# resource "oci_kms_key" "ad_key" {
#   compartment_id      = var.compartment_ocid
#   display_name        = "mini-ad-key"
#   management_endpoint = oci_kms_vault.ad_vault.management_endpoint
#
#   key_shape {
#     algorithm = "AES"
#     length    = 32
#   }
# }
#
# resource "oci_vault_secret" "admin_password" {
#   compartment_id = var.compartment_ocid
#   vault_id       = oci_kms_vault.ad_vault.id
#   key_id         = oci_kms_key.ad_key.id
#   secret_name    = "admin_ad_credentials"
#
#   secret_content {
#     content_type = "BASE64"
#     content = base64encode(jsonencode({
#       username = "Admin@${var.dns_zone}"
#       password = random_password.admin_password.result
#     }))
#   }
# }
#
# resource "oci_vault_secret" "jsmith_password" {
#   compartment_id = var.compartment_ocid
#   vault_id       = oci_kms_vault.ad_vault.id
#   key_id         = oci_kms_key.ad_key.id
#   secret_name    = "jsmith_ad_credentials"
#
#   secret_content {
#     content_type = "BASE64"
#     content = base64encode(jsonencode({
#       username = "jsmith@${var.dns_zone}"
#       password = random_password.jsmith_password.result
#     }))
#   }
# }
#
# resource "oci_vault_secret" "edavis_password" {
#   compartment_id = var.compartment_ocid
#   vault_id       = oci_kms_vault.ad_vault.id
#   key_id         = oci_kms_key.ad_key.id
#   secret_name    = "edavis_ad_credentials"
#
#   secret_content {
#     content_type = "BASE64"
#     content = base64encode(jsonencode({
#       username = "edavis@${var.dns_zone}"
#       password = random_password.edavis_password.result
#     }))
#   }
# }
#
# resource "oci_vault_secret" "rpatel_password" {
#   compartment_id = var.compartment_ocid
#   vault_id       = oci_kms_vault.ad_vault.id
#   key_id         = oci_kms_key.ad_key.id
#   secret_name    = "rpatel_ad_credentials"
#
#   secret_content {
#     content_type = "BASE64"
#     content = base64encode(jsonencode({
#       username = "rpatel@${var.dns_zone}"
#       password = random_password.rpatel_password.result
#     }))
#   }
# }
#
# resource "oci_vault_secret" "akumar_password" {
#   compartment_id = var.compartment_ocid
#   vault_id       = oci_kms_vault.ad_vault.id
#   key_id         = oci_kms_key.ad_key.id
#   secret_name    = "akumar_ad_credentials"
#
#   secret_content {
#     content_type = "BASE64"
#     content = base64encode(jsonencode({
#       username = "akumar@${var.dns_zone}"
#       password = random_password.akumar_password.result
#     }))
#   }
# }
#
# resource "oci_vault_secret" "windows_local_admin_password" {
#   compartment_id = var.compartment_ocid
#   vault_id       = oci_kms_vault.ad_vault.id
#   key_id         = oci_kms_key.ad_key.id
#   secret_name    = "windows_local_admin_credentials"
#
#   secret_content {
#     content_type = "BASE64"
#     content = base64encode(jsonencode({
#       username = "windows_local_admin"
#       password = random_password.windows_local_admin_password.result
#     }))
#   }
# }
