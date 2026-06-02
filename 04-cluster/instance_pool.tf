# ==============================================================================
# RStudio Instance Pool
# ------------------------------------------------------------------------------
# Instance Configuration uses the Packer rstudio-image; injects
# rstudio_booter.sh via cloud-init to handle domain join, FSS mounts
# (using mount_target_ip from 02-servers remote state), and R libs config.
# Instance Pool registers instances with the LB backend set on port 8787.
# Autoscaling: CPU threshold — scale out when average > 60%.
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
          mt_ip             = local.mount_target_ip
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

  # Autoscaling takes control of size after first apply
  size = 2
  lifecycle {
    ignore_changes = [size]
  }

  placement_configurations {
    availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
    primary_subnet_id   = local.cluster_subnet_ocid
  }

  # Register with LB backend set on port 8787 — instances join rotation once
  # they pass health checks and are removed when the pool scales in
  load_balancers {
    load_balancer_id = oci_load_balancer_load_balancer.rstudio_lb.id
    backend_set_name = oci_load_balancer_backend_set.rstudio_bs.name
    port             = 8787
    vnic_selection   = "PrimaryVnic"
  }
}

# ==============================================================================
# Autoscaling Configuration
# 300s cool-down (OCI minimum) prevents rapid repeated scaling actions.
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
