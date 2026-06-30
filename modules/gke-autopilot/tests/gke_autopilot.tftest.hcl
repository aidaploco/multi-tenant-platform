# Unit tests for gke-autopilot. Mocked provider — verifies WIRING (private, autopilot, WI),
# NOT that a real cluster comes up healthy (that needs a live apply).

mock_provider "google" {}

variables {
  project_id          = "runtime-dev"
  region              = "europe-west4"
  network             = "projects/runtime-dev/global/networks/runtime-vpc"
  subnetwork          = "projects/runtime-dev/regions/europe-west4/subnetworks/runtime-vpc-europe-west4"
  pods_range_name     = "pods"
  services_range_name = "services"
  master_ipv4_cidr    = "172.16.0.0/28"
  labels = {
    tenant              = "platform"
    environment         = "dev"
    data_classification = "internal"
  }
}

run "is_private_autopilot_with_workload_identity" {
  command = plan

  assert {
    condition     = google_container_cluster.this.enable_autopilot == true
    error_message = "Cluster must be Autopilot."
  }

  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_nodes == true
    error_message = "Nodes must be private (no public node IPs)."
  }

  assert {
    condition     = output.workload_pool == "runtime-dev.svc.id.goog"
    error_message = "Workload Identity pool must be <project>.svc.id.goog (agent-unit SAs bind here)."
  }
}

run "rejects_bad_release_channel" {
  command = plan

  variables {
    release_channel = "BLEEDING_EDGE"
  }

  expect_failures = [var.release_channel]
}
