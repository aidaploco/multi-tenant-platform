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
  database_encryption_key = "projects/runtime-dev/locations/europe-west4/keyRings/platform/cryptoKeys/gke-secrets"
  boot_disk_kms_key       = "projects/runtime-dev/locations/europe-west4/keyRings/platform/cryptoKeys/gke-disks"
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

run "substrate_cmek_is_wired" {
  command = plan

  assert {
    condition     = google_container_cluster.this.database_encryption[0].state == "ENCRYPTED"
    error_message = "etcd application-layer encryption must be ENCRYPTED with the platform key (ADR-0025 D25-1)."
  }

  assert {
    condition     = google_container_cluster.this.cluster_autoscaling[0].auto_provisioning_defaults[0].boot_disk_kms_key == var.boot_disk_kms_key
    error_message = "Node boot disks must use the platform CMEK key (ADR-0025 D25-1)."
  }
}

run "rejects_empty_substrate_keys" {
  command = plan

  variables {
    database_encryption_key = ""
    boot_disk_kms_key       = ""
  }

  expect_failures = [var.database_encryption_key, var.boot_disk_kms_key]
}
