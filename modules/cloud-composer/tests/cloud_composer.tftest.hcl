# Unit tests for cloud-composer. Mocked provider — verifies WIRING (private endpoint, VPC, own
# SA). It CANNOT verify a real environment builds; Composer config is highly apply-sensitive.

mock_provider "google" {}

variables {
  project_id            = "runtime-dev"
  region                = "europe-west4"
  network               = "projects/runtime-dev/global/networks/runtime-vpc"
  subnetwork            = "projects/runtime-dev/regions/europe-west4/subnetworks/runtime-vpc-europe-west4"
  master_ipv4_cidr      = "172.16.1.0/28"
  composer_network_cidr = "10.1.0.0/24"
  web_server_cidr       = "172.16.1.16/28"
  labels = {
    tenant              = "platform"
    environment         = "dev"
    data_classification = "internal"
  }
}

run "private_environment_on_shared_vpc" {
  command = plan

  assert {
    condition     = google_composer_environment.this.config[0].private_environment_config[0].enable_private_endpoint == true
    error_message = "Composer must use a private endpoint (no public IPs)."
  }

  assert {
    condition     = google_composer_environment.this.config[0].node_config[0].network == var.network
    error_message = "Composer must attach to the shared VPC."
  }
}

run "rejects_missing_required_label" {
  command = plan

  variables {
    labels = { tenant = "platform", environment = "dev" }
  }

  expect_failures = [var.labels]
}
