# kms-tenant: per-tenant CMEK keys.
#
# Each tenant gets its own key ring and one key per service type, in a DEDICATED
# key-management project (not the tenant's data project) so the people who can
# read data and the people who control its keys are different principals.
#
# Rotation is GCP-native (rotation_period on the key). There is deliberately no
# rotation pipeline, cron job, or script -- that was a failure mode in the
# reference platform.

locals {
  labels = merge(var.labels, { "managed-by" = "terraform" })
}

resource "google_kms_key_ring" "this" {
  name     = var.keyring_name
  location = var.location
  project  = var.project_id
}

resource "google_kms_crypto_key" "this" {
  for_each = toset(var.keys)

  name     = each.value
  key_ring = google_kms_key_ring.this.id
  purpose  = "ENCRYPT_DECRYPT"

  # Native automatic rotation -- GCP creates a new key version on this cadence.
  rotation_period = var.rotation_period

  labels = local.labels

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.protection_level
  }

  lifecycle {
    # A crypto key with no rotation_period is a silent compliance gap; fail
    # closed rather than ship an un-rotating key.
    precondition {
      condition     = var.rotation_period != null && var.rotation_period != ""
      error_message = "rotation_period must be set on every CMEK key."
    }
  }
}
