output "lb_public_ip" {
  description = "Public IP of the RStudio Load Balancer."
  value       = oci_load_balancer_load_balancer.rstudio_lb.ip_address_details[0].ip_address
}
