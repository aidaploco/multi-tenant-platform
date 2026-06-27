# Pre-flight policy gate for the platform.
#
# Runs in CI against `terraform show -json <plan>` output. A plan that trips any
# `deny` rule never reaches apply -- not even in dev. This is the OPA half of the
# defence; Org Policy is the runtime half.
#
# These policies are authored here (platform-modules) as the single source of
# truth and consumed by platform-config's CI -- they are not duplicated.

package main

import rego.v1

resource_changes := input.resource_changes

# Resources being created or updated (pure deletes are handled by the destroy gate).
upserts contains rc if {
	some rc in resource_changes
	some action in rc.change.actions
	action in {"create", "update"}
}

required_labels := {"tenant", "environment", "data_classification", "managed-by"}

# Resource types that carry labels and must therefore be fully labelled.
labelled_types := {
	"google_storage_bucket",
	"google_project",
	"google_kms_crypto_key",
}

# Maximum resources a single plan may destroy before requiring explicit override.
max_destroyed := 5

# --- Keyless identity: no service-account keys, ever. ---
deny contains msg if {
	some rc in resource_changes
	rc.type == "google_service_account_key"
	msg := sprintf("%s: service-account keys are forbidden (keyless identity only)", [rc.address])
}

# --- GCS: uniform bucket-level access (no ACLs). ---
deny contains msg if {
	some rc in upserts
	rc.type == "google_storage_bucket"
	not rc.change.after.uniform_bucket_level_access
	msg := sprintf("%s: uniform_bucket_level_access must be true (no ACLs)", [rc.address])
}

# --- GCS: public access prevention enforced. ---
deny contains msg if {
	some rc in upserts
	rc.type == "google_storage_bucket"
	rc.change.after.public_access_prevention != "enforced"
	msg := sprintf("%s: public_access_prevention must be \"enforced\"", [rc.address])
}

# --- CMEK required on GCS buckets. ---
deny contains msg if {
	some rc in upserts
	rc.type == "google_storage_bucket"
	not has_cmek(rc)
	msg := sprintf("%s: encryption.default_kms_key_name is required (CMEK, no Google-managed keys)", [rc.address])
}

has_cmek(rc) if {
	some enc in rc.change.after.encryption
	enc.default_kms_key_name != ""
	enc.default_kms_key_name != null
}

# --- KMS keys must rotate. ---
deny contains msg if {
	some rc in upserts
	rc.type == "google_kms_crypto_key"
	not rc.change.after.rotation_period
	msg := sprintf("%s: CMEK key must set rotation_period", [rc.address])
}

# --- Required labels on labelled resource types. ---
deny contains msg if {
	some rc in upserts
	rc.type in labelled_types
	some key in required_labels
	not rc.change.after.labels[key]
	msg := sprintf("%s: missing required label %q", [rc.address, key])
}

# --- Destroy threshold: large teardowns must be explicit. ---
deny contains msg if {
	deletions := [rc | some rc in resource_changes; "delete" in rc.change.actions]
	count(deletions) > max_destroyed
	msg := sprintf("plan destroys %d resources (max %d) -- add an explicit override label to proceed", [count(deletions), max_destroyed])
}
