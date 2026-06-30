# cloud-composer: the shared managed-Airflow orchestration plane (ADR-0010 / ADR-0001 D13).
#
# Private environment on the shared VPC, running as its own least-privilege service account.
# Per-tenant DAG folders, Airflow RBAC, and KubernetesPodOperator-as-the-tenant's-WI-SA (so a
# task touches only its own tenant's data) are operational config layered on top, not created
# here. This module stands up the private environment + its identity.

locals {
  labels = merge(var.labels, { "managed-by" = "terraform" })
}

# The environment's own runtime identity (distinct from the CI SAs and from tenant agent SAs).
resource "google_service_account" "composer" {
  project      = var.project_id
  account_id   = "${var.name}-sa"
  display_name = "Composer environment ${var.name}"
}

resource "google_project_iam_member" "composer_worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer.email}"
}

resource "google_composer_environment" "this" {
  project = var.project_id
  name    = var.name
  region  = var.region
  labels  = local.labels

  config {
    software_config {
      image_version = var.image_version
    }

    node_config {
      network         = var.network
      subnetwork      = var.subnetwork
      service_account = google_service_account.composer.email
    }

    # Private: no public IPs on the environment; the control plane is private.
    private_environment_config {
      enable_private_endpoint                = true
      master_ipv4_cidr_block                 = var.master_ipv4_cidr
      cloud_composer_network_ipv4_cidr_block = var.composer_network_cidr
      web_server_ipv4_cidr_block             = var.web_server_cidr
    }

    environment_size = var.environment_size
  }

  depends_on = [google_project_iam_member.composer_worker]
}
