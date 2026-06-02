# ==============================================================================
# RStudio Instance Pool
# ------------------------------------------------------------------------------
# Purpose:
#   - Instance Configuration: blueprint for each RStudio pool instance.
#     Uses the Packer-built rstudio-image; injects rstudio_booter.sh via
#     cloud-init metadata to handle domain join, FSS mounts, and R libs config.
#   - Instance Pool: maintains desired capacity in cluster-subnet, registers
#     instances with the LB backend set as they pass health checks.
#   - Autoscaling: CPU threshold policy — scale out when average > 60%.
#
# Notes:
#   - cluster-subnet prohibits public IPs; outbound via NAT gateway.
#   - FSS mount target IP is injected at plan time from fss.tf output.
#   - Autoscaling takes over pool size after first apply — ignore_changes
#     prevents Terraform from fighting the autoscaler on subsequent runs.
# ==============================================================================

# ==============================================================================
# Instance Configuration — blueprint for pool instances
# ==============================================================================

resource "oci_core_instance_configuration" "rstudio" {
  compartment_id = local.compartment_ocid
  display_name   = "rstudio-instance-config"

  instance_details {
    instance_type = "compute"

    launch_details {
      compartment_id = local.compartment_ocid
      display_name   = "rstudio-instance"
      shape          = "VM.Standard.E4.Flex"

      shape_config {
        ocpus         = 2
        memory_in_gbs = 8
      }

      source_details {
        source_type = "image"
        image_id    = var.rstudio_image_ocid
      }

      # Private subnet — no public IPs; all traffic arrives via Load Balancer
      create_vnic_details {
        subnet_id        = local.cluster_subnet_ocid
        assign_public_ip = false
        nsg_ids          = [oci_core_network_security_group.ssh_nsg.id]
      }

      metadata = {
        ssh_authorized_keys = local.ssh_public_key
        user_data = base64encode(templatefile("${path.module}/scripts/rstudio_booter.sh", {
          admin_password    = local.admin_password
          domain_fqdn       = var.dns_zone
          domain_fqdn_upper = upper(var.dns_zone)
          netbios           = var.netbios
          mt_ip             = oci_file_storage_mount_target.fss_mt.ip_address
          force_group       = "${lower(var.netbios)}-users"
        }))
      }
    }
  }
}

# ==============================================================================
# Instance Pool — desired capacity + LB backend registration
# ==============================================================================

resource "oci_core_instance_pool" "rstudio" {
  compartment_id            = local.compartment_ocid
  instance_configuration_id = oci_core_instance_configuration.rstudio.id
  display_name              = "rstudio-pool"

  # Autoscaling configuration takes control of size after first apply
  size = 2
  lifecycle {
    ignore_changes = [size]
  }

  placement_configurations {
    availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
    primary_subnet_id   = local.cluster_subnet_ocid
  }

  # Register with LB backend set on port 8787 — instances are added to rotation
  # once they pass health checks and removed when the pool scales in
  load_balancers {
    load_balancer_id = oci_load_balancer_load_balancer.rstudio_lb.id
    backend_set_name = oci_load_balancer_backend_set.rstudio_bs.name
    port             = 8787
    vnic_selection   = "PrimaryVnic"
  }

  # FSS must be fully exported before any instance boots and runs the booter
  depends_on = [oci_file_storage_export.nfs_export]
}

# ==============================================================================
# Autoscaling Configuration
# ------------------------------------------------------------------------------
# OCI threshold policies fire when the metric crosses the threshold.
# 300s cool-down (OCI minimum) prevents rapid repeated scaling actions.
#
# | Rule              | Condition   | Action      |
# |-------------------|-------------|-------------|
# | rstudio-scale-out | CPU > 60%   | +1 instance |
# | rstudio-scale-in  | CPU < 10%   | -1 instance |
# ==============================================================================

resource "oci_autoscaling_auto_scaling_configuration" "rstudio" {
  compartment_id       = local.compartment_ocid
  display_name         = "rstudio-autoscaling"
  is_enabled           = true
  cool_down_in_seconds = 300

  auto_scaling_resources {
    id   = oci_core_instance_pool.rstudio.id
    type = "instancePool"
  }

  policies {
    display_name = "rstudio-cpu-policy"
    policy_type  = "threshold"

    capacity {
      initial = 2
      min     = 2
      max     = 4
    }

    rules {
      display_name = "rstudio-scale-in"
      action {
        type  = "CHANGE_COUNT_BY"
        value = -1
      }
      metric {
        metric_type = "CPU_UTILIZATION"
        threshold {
          operator = "LT"
          value    = 10
        }
      }
    }

    rules {
      display_name = "rstudio-scale-out"
      action {
        type  = "CHANGE_COUNT_BY"
        value = 1
      }
      metric {
        metric_type = "CPU_UTILIZATION"
        threshold {
          operator = "GT"
          value    = 60
        }
      }
    }
  }
}
