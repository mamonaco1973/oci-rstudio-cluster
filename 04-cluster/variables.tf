# ==============================================================================
# Active Directory Naming Inputs
# Must match the values used in 01-directory.
# ==============================================================================

variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., mcloud.mikecloud.com)"
  type        = string
  default     = "mcloud.mikecloud.com"
}

variable "realm" {
  description = "Kerberos realm (e.g., MCLOUD.MIKECLOUD.COM)"
  type        = string
  default     = "MCLOUD.MIKECLOUD.COM"
}

variable "netbios" {
  description = "NetBIOS short domain name (e.g., MCLOUD)"
  type        = string
  default     = "MCLOUD"
}

variable "user_base_dn" {
  description = "User base DN for LDAP (e.g., CN=Users,DC=mcloud,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=mcloud,DC=mikecloud,DC=com"
}

# ==============================================================================
# Packer Image
# OCID of the RStudio server image built by 03-packer.
# ==============================================================================

variable "rstudio_image_ocid" {
  description = "OCID of the Packer-built RStudio server image."
  type        = string
}
