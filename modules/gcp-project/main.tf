# gcp-project: the tenant isolation boundary.
#
# A GCP project is simultaneously the billing, IAM, and API-enablement boundary.
# This module creates exactly one project and enables exactly the APIs it is told
# to -- nothing implicit. It is the foundation every other module runs inside.

locals {
  # managed-by is enforced by the platform, not chosen by callers, so we inject
  # it here rather than trusting the input map to carry it.
  labels = merge(var.labels, { "managed-by" = "terraform" })
}

resource "google_project" "this" {
  name            = var.display_name
  project_id      = var.project_id
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = local.labels

  # Private by default starts here: never create the legacy default VPC, which
  # ships with permissive firewall rules and a public-facing posture. Tenant
  # networking is attached deliberately via the shared-vpc module instead.
  auto_create_network = false

  # PREVENT in prod stops `terraform destroy` (or a fat-fingered apply) from
  # deleting a live tenant project. Callers pass DELETE for ephemeral envs.
  deletion_policy = var.deletion_policy
}

resource "google_project_service" "this" {
  for_each = toset(var.activate_apis)

  project = google_project.this.project_id
  service = each.value

  # Do not let Terraform disable an API (and cascade to dependent services) on
  # destroy -- that has caused outages when one tenant's teardown disabled an
  # API another resource in the same project still depended on.
  disable_dependent_services = false
  disable_on_destroy         = false
}
