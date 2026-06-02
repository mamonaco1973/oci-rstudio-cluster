output "xubuntu_public_ip" {
  description = "Public IP of the Xubuntu desktop instance."
  value       = oci_core_instance.xubuntu_instance.public_ip
}

output "xubuntu_private_ip" {
  description = "Private IP of the Xubuntu instance (Samba gateway for Z: drive)."
  value       = oci_core_instance.xubuntu_instance.private_ip
}

output "mount_target_ip" {
  description = "Private IP of the FSS mount target (NFS endpoint)."
  value       = oci_file_storage_mount_target.fss_mt.ip_address
}

