# agent-identity: a workload's runtime identity — the "agent-unit" archetype (ADR-0002 D2-4).
#
# Identity ONLY: a service account (distinct from the CI SAs), an optional Workload Identity
# binding so a pod in the shared runtime can act AS this SA (ADR-0001 D13), and least-privilege
# IAM. No data resources. No keys, ever (D5) — a workload authenticates via Workload Identity,
# never a downloaded JSON key.

locals {
  iam_project = coalesce(var.iam_project, var.project_id)

  # The Kubernetes SA (in the shared runtime cluster's identity pool) permitted to impersonate
  # this GSA. Built purely from inputs, so it is known at plan time even before the cluster
  # exists — the binding is valid IAM ahead of the workload landing.
  wi_member = var.workload_identity == null ? null : "serviceAccount:${var.workload_identity.runtime_project_id}.svc.id.goog[${var.workload_identity.namespace}/${var.workload_identity.ksa_name}]"
}

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
  description  = "Runtime identity managed by the platform (agent-unit). Keyless — no JSON keys."
}

# Least-privilege grants. Primitive and key-minting roles are blocked by variable validation
# (variables.tf) and by the OPA gate.
resource "google_project_iam_member" "roles" {
  for_each = toset(var.iam_roles)

  project = local.iam_project
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

# Workload Identity binding (optional). The named Kubernetes SA may impersonate this GSA, so the
# pod acts as the tenant's identity and can only ever touch the tenant's own data.
resource "google_service_account_iam_member" "workload_identity" {
  count = var.workload_identity == null ? 0 : 1

  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wi_member
}
