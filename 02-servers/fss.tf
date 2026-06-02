# ==============================================================================
# OCI File Storage Service (FSS)
# ------------------------------------------------------------------------------
# Purpose:
#   - Provisions a managed NFS file system equivalent to AWS EFS.
#   - Exposes a /nfs export path shared across all instances.
#   - Linux instance mounts /nfs and re-exports via Samba (SMB)
#     so Windows clients can map Z: to \\<linux-ip>\nfs.
#   - 04-cluster RStudio instances also mount /nfs for shared home dirs
#     and the /nfs/rlibs shared R package library.
#
# Scope:
#   - FSS file system (encrypted at rest by default in OCI)
#   - Mount target in vm-subnet (gets a private IP from 10.0.0.64/26)
#   - One export: /nfs
#
# Notes:
#   - OCI FSS requires 3 resources: file_system + mount_target + export(s).
#   - NFS ports (111, 2048-2050) must be open in the vm-subnet security list.
#   - Mount target IP is output so 04-cluster can reference it via remote state.
# ==============================================================================

resource "oci_file_storage_file_system" "fss" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = local.compartment_ocid
  display_name        = "rstudio-fss"
}

# Lives in vm-subnet so the Linux gateway and FSS mount target share the
# same subnet security list rules for NFS traffic.
resource "oci_file_storage_mount_target" "fss_mt" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = local.compartment_ocid
  subnet_id           = local.vm_subnet_ocid
  display_name        = "rstudio-fss-mt"
}

# /nfs — shared data directory; Linux gateway re-exports via Samba to Windows.
# /nfs/home is symlinked to /home so AD user homes live on FSS.
# /nfs/rlibs is the shared R library created by 04-cluster's rstudio_booter.sh.
resource "oci_file_storage_export" "nfs_export" {
  export_set_id  = oci_file_storage_mount_target.fss_mt.export_set_id
  file_system_id = oci_file_storage_file_system.fss.id
  path           = "/nfs"
}
