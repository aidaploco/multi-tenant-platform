# gcs: a private, CMEK-encrypted object storage bucket.
#
# Security posture is NOT optional here -- uniform bucket-level access (no ACLs,
# ever) and enforced public-access-prevention are hardcoded, not inputs. The one
# thing the caller must supply is the encryption key, and the module fails closed
# if they don't (see the cmek_key_id validation).

locals {
  labels = merge(var.labels, { "managed-by" = "terraform" })
}

# The project's GCS service agent must be able to use the CMEK key, or bucket
# creation with that key fails. We look it up and grant exactly that one role.
data "google_storage_project_service_account" "gcs" {
  project = var.project_id
}

resource "google_kms_crypto_key_iam_member" "gcs_cmek" {
  crypto_key_id = var.cmek_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

resource "google_storage_bucket" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location

  storage_class = var.storage_class
  labels        = local.labels
  force_destroy = var.force_destroy

  # No ACLs, ever -- IAM is the only access model on this bucket.
  uniform_bucket_level_access = true
  # Belt-and-braces with the org policy: this bucket can never be made public.
  public_access_prevention = "enforced"

  versioning {
    enabled = var.versioning
  }

  encryption {
    default_kms_key_name = var.cmek_key_id
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action_type
        storage_class = lifecycle_rule.value.storage_class
      }
      condition {
        age        = lifecycle_rule.value.age_days
        with_state = lifecycle_rule.value.with_state
      }
    }
  }

  # Ensure the service agent holds the key permission before we try to create a
  # bucket encrypted with that key.
  depends_on = [google_kms_crypto_key_iam_member.gcs_cmek]
}
