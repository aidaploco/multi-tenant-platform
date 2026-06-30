# Unit tests for config-sync. Mocked provider — verifies WIRING (reconciles gitops/, provisions
# the git secret). It cannot verify Config Sync actually syncs; that needs a live cluster + fleet.

mock_provider "google" {}

variables {
  project_id   = "runtime-dev"
  region       = "europe-west4"
  cluster_name = "runtime-cluster"
  cluster_id   = "projects/runtime-dev/locations/europe-west4/clusters/runtime-cluster"
  sync_repo    = "https://github.com/aidaploco/multi-tenant-config"
  labels = {
    tenant              = "platform"
    environment         = "dev"
    data_classification = "internal"
  }
}

run "reconciles_gitops_dir" {
  command = plan

  assert {
    condition     = google_gke_hub_feature_membership.this.configmanagement[0].config_sync[0].git[0].policy_dir == "gitops"
    error_message = "Config Sync must reconcile the gitops/ directory."
  }
}

run "token_auth_provisions_secret" {
  command = plan

  assert {
    condition     = length(google_secret_manager_secret.git_token) == 1
    error_message = "token auth must provision a Secret Manager secret for the git credential."
  }
}

run "no_secret_for_keyless" {
  command = plan

  variables {
    secret_type = "gcpserviceaccount"
  }

  assert {
    condition     = length(google_secret_manager_secret.git_token) == 0
    error_message = "Keyless (gcpserviceaccount) auth must not provision a token secret."
  }
}
