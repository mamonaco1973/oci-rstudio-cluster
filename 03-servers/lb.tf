# ==============================================================================
# OCI Load Balancer: RStudio Cluster
# ------------------------------------------------------------------------------
# Purpose:
#   - Internet-facing flexible Load Balancer placed in vm-subnet.
#   - Backend set targets RStudio Server on port 8787 with sticky sessions
#     so each user's R session stays on the same instance.
#   - HTTP listener on port 80 forwards traffic to the backend set.
#
# Notes:
#   - vm-subnet security list allows TCP 80 inbound from 0.0.0.0/0.
#   - cluster-subnet security list allows TCP 8787 from vm-subnet (10.0.0.64/26).
#   - The instance pool registers/deregisters backends automatically.
# ==============================================================================

# ==============================================================================
# Load Balancer
# ==============================================================================

resource "oci_load_balancer_load_balancer" "rstudio_lb" {
  compartment_id = local.compartment_ocid
  display_name   = "rstudio-lb"

  # Flexible shape scales bandwidth with traffic — minimum prevents idle cost
  shape = "flexible"
  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 100
  }

  is_private = false
  subnet_ids = [local.vm_subnet_ocid]

  freeform_tags = { "Name" = "rstudio-lb" }
}

# ==============================================================================
# Backend Set — RStudio on port 8787
# ==============================================================================

resource "oci_load_balancer_backend_set" "rstudio_bs" {
  name             = "rstudio-backend-set"
  load_balancer_id = oci_load_balancer_load_balancer.rstudio_lb.id
  policy           = "ROUND_ROBIN"

  # Sticky sessions via LB cookie — RStudio R sessions are instance-local,
  # so users must return to the same backend for the duration of their work.
  lb_cookie_session_persistence_configuration {
    cookie_name        = "RSTUDIO_SESSION"
    disable_fallback   = false
    is_http_only       = true
    is_secure          = false
    max_age_in_seconds = 86400
  }

  # RStudio returns HTTP 302 to /auth-sign-in when healthy and unauthenticated
  health_checker {
    protocol          = "HTTP"
    url_path          = "/"
    port              = 8787
    interval_ms       = 10000
    retries           = 3
    return_code       = 302
    timeout_in_millis = 5000
  }
}

# ==============================================================================
# HTTP Listener — port 80 → backend set
# ==============================================================================

resource "oci_load_balancer_listener" "http" {
  name                     = "rstudio-listener"
  load_balancer_id         = oci_load_balancer_load_balancer.rstudio_lb.id
  default_backend_set_name = oci_load_balancer_backend_set.rstudio_bs.name
  port                     = 80
  protocol                 = "HTTP"
}
