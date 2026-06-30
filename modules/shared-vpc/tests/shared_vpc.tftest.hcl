# Unit tests for shared-vpc. Mocked provider — no cloud, no cost.

mock_provider "google" {}

variables {
  project_id    = "runtime-dev"
  region        = "europe-west4"
  subnet_cidr   = "10.0.0.0/20"
  pods_cidr     = "10.4.0.0/14"
  services_cidr = "10.8.0.0/20"
}

run "private_google_access_enabled" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.this.private_ip_google_access == true
    error_message = "Private Google Access must be enabled (no external IPs needed for Google APIs)."
  }
}

run "secondary_ranges_present" {
  command = plan

  assert {
    condition     = length(google_compute_subnetwork.this.secondary_ip_range) == 2
    error_message = "Subnet must declare the pods and services secondary ranges for a VPC-native cluster."
  }
}

run "no_world_open_allow_rules" {
  command = plan

  assert {
    condition     = !contains(google_compute_firewall.allow_internal.source_ranges, "0.0.0.0/0")
    error_message = "The internal allow rule must not be world-open."
  }

  assert {
    condition     = !contains(google_compute_firewall.allow_iap.source_ranges, "0.0.0.0/0")
    error_message = "Admin access must be IAP-scoped, never world-open."
  }
}
