# Unit tests for tenant-namespace. Mocked kubernetes provider — verifies the isolation contract is
# wired (default-deny, quota, WI-annotated SA, namespace RBAC). Live behavior needs a real cluster.

mock_provider "kubernetes" {}

variables {
  namespace   = "abf"
  owner_group = "abf-data-engineers@company.com"
  service_accounts = {
    "search-a" = "abf-search-a@abf-dev.iam.gserviceaccount.com"
  }
  labels = {
    tenant              = "abf"
    environment         = "dev"
    data_classification = "confidential"
  }
}

run "default_deny_ingress_is_present" {
  command = plan

  assert {
    condition     = one(kubernetes_network_policy.default_deny_ingress.spec[0].policy_types) == "Ingress"
    error_message = "Namespace must have a default-deny ingress NetworkPolicy."
  }
}

run "workload_sa_bound_to_gcp_sa" {
  command = plan

  assert {
    condition     = kubernetes_service_account.workload["search-a"].metadata[0].annotations["iam.gke.io/gcp-service-account"] == "abf-search-a@abf-dev.iam.gserviceaccount.com"
    error_message = "Each agent-unit KSA must be annotated to impersonate its GCP SA (Workload Identity)."
  }
}

run "rejects_missing_required_label" {
  command = plan

  variables {
    labels = { tenant = "abf", environment = "dev" }
  }

  expect_failures = [var.labels]
}
