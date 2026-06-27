# Unit tests for the gcs module (mocked provider: no bucket, no cost).

mock_provider "google" {}

variables {
  project_id  = "abf-dev-7f3a"
  name        = "abf-dev-landing"
  location    = "europe-west4"
  cmek_key_id = "projects/company-keys-dev/locations/europe-west4/keyRings/abf-keyring/cryptoKeys/gcs"
  labels = {
    tenant              = "abf"
    environment         = "dev"
    data_classification = "confidential"
  }
}

run "private_and_cmek_encrypted_by_default" {
  command = plan

  assert {
    condition     = google_storage_bucket.this.uniform_bucket_level_access == true
    error_message = "Uniform bucket-level access must be on (no ACLs, ever)."
  }

  assert {
    condition     = google_storage_bucket.this.public_access_prevention == "enforced"
    error_message = "Public access prevention must be enforced."
  }

  assert {
    condition     = google_storage_bucket.this.encryption[0].default_kms_key_name == var.cmek_key_id
    error_message = "Bucket must be encrypted with the supplied CMEK key."
  }

  assert {
    condition     = google_storage_bucket.this.versioning[0].enabled == true
    error_message = "Versioning should default to enabled."
  }
}

run "fails_closed_without_cmek_key" {
  command = plan

  variables {
    cmek_key_id = null
  }

  expect_failures = [var.cmek_key_id]
}

run "rejects_invalid_storage_class" {
  command = plan

  variables {
    storage_class = "GLACIER" # AWS term; not a GCS class
  }

  expect_failures = [var.storage_class]
}

run "rejects_invalid_lifecycle_action" {
  command = plan

  variables {
    lifecycle_rules = [{ action_type = "Archive", age_days = 30 }]
  }

  expect_failures = [var.lifecycle_rules]
}
