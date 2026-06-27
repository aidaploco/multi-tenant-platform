# Unit tests for the gcp-project module.
#
# These run with a MOCKED google provider: no GCP project, no billing account,
# no credentials, no cost. `terraform test` plans the module against fabricated
# provider responses and checks our own logic (label injection, private-by-
# default, input validation). Run with: terraform test

mock_provider "google" {}

variables {
  project_id      = "abf-dev-7f3a"
  display_name    = "ABF Analytics dev"
  folder_id       = "folders/123456789"
  billing_account = "0X0X0X-0X0X0X-0X0X0X"
  labels = {
    tenant              = "abf"
    environment         = "dev"
    data_classification = "confidential"
  }
}

run "private_by_default_and_labels_injected" {
  command = plan

  assert {
    condition     = google_project.this.auto_create_network == false
    error_message = "Default VPC must never be created (private-by-default)."
  }

  assert {
    condition     = output.labels["managed-by"] == "terraform"
    error_message = "managed-by label must be injected by the module, not the caller."
  }

  assert {
    condition     = google_project.this.deletion_policy == "PREVENT"
    error_message = "deletion_policy must default to the safe PREVENT value."
  }
}

run "rejects_missing_required_labels" {
  command = plan

  variables {
    labels = { tenant = "abf" } # missing environment + data_classification
  }

  expect_failures = [var.labels]
}

run "rejects_malformed_project_id" {
  command = plan

  variables {
    project_id = "BadID_With_Caps" # uppercase + underscores are invalid
  }

  expect_failures = [var.project_id]
}
