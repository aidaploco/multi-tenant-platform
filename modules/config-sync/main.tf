# config-sync: installs Config Sync on the shared runtime cluster via Fleet, pointed at the
# platform-config gitops/ directory (ADR-0012). This is the GitOps reconciliation loop that keeps
# the cluster's tenant-isolation policy applied and self-healing.
#
# What this module does NOT do: create the in-cluster `git-creds` secret (needs cluster access —
# operational), or the per-tenant namespaces (Terraform tenant composition does that, data-driven).

locals {
  labels = merge(var.labels, {
    "managed-by"    = "terraform"
    "rotation_days" = tostring(var.rotation_days)
  })
}

# Register the cluster into the project's Fleet.
resource "google_gke_hub_membership" "this" {
  membership_id = "${var.cluster_name}-membership"
  project       = var.project_id
  location      = var.region

  endpoint {
    gke_cluster {
      resource_link = var.cluster_id
    }
  }
}

# Enable the Config Management (Config Sync) feature at the fleet level.
resource "google_gke_hub_feature" "configmanagement" {
  name     = "configmanagement"
  project  = var.project_id
  location = "global"
}

# Point Config Sync at the gitops/ directory and reconcile continuously.
resource "google_gke_hub_feature_membership" "this" {
  project             = var.project_id
  location            = "global"
  feature             = google_gke_hub_feature.configmanagement.name
  membership          = google_gke_hub_membership.this.membership_id
  membership_location = var.region

  configmanagement {
    config_sync {
      source_format = "unstructured"

      git {
        sync_repo   = var.sync_repo
        sync_branch = var.sync_branch
        policy_dir  = var.policy_dir
        secret_type = var.secret_type
      }
    }
  }
}

# The git read credential Config Sync uses — the platform's FIRST long-lived secret (ADR-0006).
# The rotation cadence is recorded as a label; the secret VALUE and the in-cluster git-creds secret
# are populated out-of-band by the platform team. Preferred hardening: OCI + Workload Identity
# (keyless), see ADR-0012 D12-4.
resource "google_secret_manager_secret" "git_token" {
  count     = var.secret_type == "token" ? 1 : 0
  project   = var.project_id
  secret_id = "configsync-git-token"
  labels    = local.labels

  replication {
    auto {}
  }
}
