# Unit tests for the agent-identity (agent-unit) archetype. Mocked provider — no cloud, no cost.

mock_provider "google" {}

variables {
  project_id   = "abf-dev"
  account_id   = "abf-search-a"
  display_name = "ABF Analytics search-a"
}

run "creates_identity_with_wi_binding" {
  command = plan

  variables {
    iam_roles = ["roles/storage.objectViewer"]
    workload_identity = {
      runtime_project_id = "runtime-dev"
      namespace          = "abf"
      ksa_name           = "search-a"
    }
  }

  assert {
    condition     = output.workload_identity_member == "serviceAccount:runtime-dev.svc.id.goog[abf/search-a]"
    error_message = "WI member must be built from the runtime project, namespace, and KSA name."
  }
}

run "no_binding_when_workload_identity_omitted" {
  command = plan

  variables {
    iam_roles = ["roles/storage.objectViewer"]
  }

  assert {
    condition     = output.workload_identity_member == null
    error_message = "With no workload_identity, no binding member should be produced."
  }
}

run "primitive_role_is_rejected" {
  command = plan

  variables {
    iam_roles = ["roles/editor"]
  }

  expect_failures = [var.iam_roles]
}

run "sa_key_role_is_rejected" {
  command = plan

  variables {
    iam_roles = ["roles/iam.serviceAccountKeyCreator"]
  }

  expect_failures = [var.iam_roles]
}
