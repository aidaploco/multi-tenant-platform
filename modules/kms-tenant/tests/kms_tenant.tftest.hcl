# Unit tests for the kms-tenant module (mocked provider: no KMS, no cost).

mock_provider "google" {}

variables {
  project_id   = "company-keys-prod"
  keyring_name = "abf-keyring"
  location     = "europe-west4"
  labels = {
    tenant              = "abf"
    environment         = "prod"
    data_classification = "confidential"
  }
}

run "creates_one_key_per_service_with_rotation" {
  command = plan

  assert {
    condition     = length(output.key_ids) == 4
    error_message = "Default key set should create gcs, sql, bq, secret."
  }

  assert {
    condition     = alltrue([for k in ["gcs", "sql", "bq", "secret"] : contains(keys(output.key_ids), k)])
    error_message = "All four default service keys must be present."
  }

  assert {
    condition     = google_kms_crypto_key.this["gcs"].rotation_period == "7776000s"
    error_message = "Keys must default to 90-day native rotation."
  }

  assert {
    condition     = google_kms_crypto_key.this["gcs"].version_template[0].protection_level == "SOFTWARE"
    error_message = "Default protection level should be SOFTWARE."
  }
}

run "rejects_non_seconds_rotation" {
  command = plan

  variables {
    rotation_period = "90d" # must be a seconds string like "7776000s"
  }

  expect_failures = [var.rotation_period]
}

run "rejects_sub_one_day_rotation" {
  command = plan

  variables {
    rotation_period = "3600s" # below the 86400s (1 day) minimum
  }

  expect_failures = [var.rotation_period]
}

run "rejects_invalid_protection_level" {
  command = plan

  variables {
    protection_level = "PAPER"
  }

  expect_failures = [var.protection_level]
}
