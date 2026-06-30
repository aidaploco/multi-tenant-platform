# shared-vpc: the private network for the shared runtime plane (ADR-0008 / ADR-0001 D13).
#
# One VPC per runtime-<env> project. Private by default: Private Google Access on, no external
# IPs, egress ONLY via Cloud NAT, ingress default-deny with admin access via Google IAP only.
# Pod-level east-west isolation between tenants is the Kubernetes default-deny NetworkPolicy
# (applied by Config Sync), NOT this module — this is the VPC perimeter + egress layer.

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  project       = var.project_id
  name          = "${var.network_name}-${var.region}"
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.subnet_cidr

  # Reach Google APIs privately — no external IP needed (ADR-0001 D4).
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Controlled egress: private nodes reach the internet (image pulls, etc.) only through NAT.
resource "google_compute_router" "this" {
  project = var.project_id
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Default-deny ingress, explicit and logged (the implicit GCP deny is silent).
resource "google_compute_firewall" "deny_ingress" {
  project   = var.project_id
  name      = "${var.network_name}-deny-all-ingress"
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 65534

  deny { protocol = "all" }

  source_ranges = ["0.0.0.0/0"]

  log_config { metadata = "INCLUDE_ALL_METADATA" }
}

# Allow intra-VPC traffic (nodes, pods, services talking to each other).
resource "google_compute_firewall" "allow_internal" {
  project   = var.project_id
  name      = "${var.network_name}-allow-internal"
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 1000

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]
}

# Admin access ONLY via Google IAP TCP forwarding — never a public IP.
resource "google_compute_firewall" "allow_iap" {
  project   = var.project_id
  name      = "${var.network_name}-allow-iap"
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  source_ranges = [var.iap_source_range]
}
