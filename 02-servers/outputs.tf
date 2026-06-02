output "linux_public_ip" {
  description = "Public IP of the Linux Samba gateway instance."
  value       = oci_core_instance.linux_ad_instance.public_ip
}

output "linux_private_ip" {
  description = "Private IP of the Linux instance (Samba gateway for Z: drive)."
  value       = oci_core_instance.linux_ad_instance.private_ip
}

output "mount_target_ip" {
  description = "Private IP of the FSS mount target — consumed by 04-cluster via remote state."
  value       = oci_file_storage_mount_target.fss_mt.ip_address
}
