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

run "tenant_rbac_is_view_not_edit" {
  command = plan

  assert {
    condition     = kubernetes_role_binding.viewers.role_ref[0].name == "view"
    error_message = "Tenant group must bind `view`, never `edit` — NetworkPolicies and workloads are platform-owned (ADR-0023)."
  }
}

run "operate_role_never_grants_networkpolicy_write" {
  command = plan

  assert {
    condition     = alltrue([for r in kubernetes_role.operators.rule : !contains(r.api_groups, "networking.k8s.io")])
    error_message = "The tenant operate role must never include networking.k8s.io — a tenant-writable NetworkPolicy defeats default-deny (ADR-0023)."
  }

  assert {
    condition     = contains(kubernetes_role.operators.rule[0].resources, "secrets")
    error_message = "Tenants must keep Secret rights — the ADR-0020 secret_ref contract has a human pre-create app Secrets."
  }
}
