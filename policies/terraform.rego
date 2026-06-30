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

# Approved GCP locations. Update here when adding a new region.
approved_locations := {"europe-west4", "eu"}

# Resource types that carry a top-level location field.
location_checked_types := {
	"google_storage_bucket",
	"google_kms_key_ring",
}

# --- Keyless identity: no service-account keys, ever. ---
deny contains msg if {
	some rc in resource_changes
	rc.type == "google_service_account_key"
	msg := sprintf("%s: service-account keys are forbidden (keyless identity only)", [rc.address])
}

# IAM member types that carry a single `role` and `member`.
iam_member_types := {
	"google_project_iam_member",
	"google_folder_iam_member",
	"google_organization_iam_member",
	"google_service_account_iam_member",
}

# --- Least-privilege: primitive roles are never granted (they are project-wide power). ---
# (viewer is allowed — the read-only CI planner legitimately uses it; owner/editor are not.)
deny contains msg if {
	some rc in upserts
	rc.type in iam_member_types
	rc.change.after.role in {"roles/owner", "roles/editor"}
	msg := sprintf("%s: primitive role %q is forbidden (grant least-privilege roles)", [rc.address, rc.change.after.role])
}

# --- Keyless backstop: never grant the power to mint service-account keys (D5). ---
deny contains msg if {
	some rc in upserts
	rc.type in iam_member_types
	rc.change.after.role in {"roles/iam.serviceAccountKeyAdmin", "roles/iam.serviceAccountKeyCreator"}
	msg := sprintf("%s: granting %q is forbidden (no service-account keys, ever)", [rc.address, rc.change.after.role])
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

# --- Observability: every alert must link a runbook. The observability module always ships one;
#     this blocks any hand-written alert that doesn't (ADR-0006). ---
deny contains msg if {
	some rc in upserts
	rc.type == "google_monitoring_alert_policy"
	not has_runbook(rc)
	msg := sprintf("%s: alert policy must link a runbook (documentation.content required)", [rc.address])
}

has_runbook(rc) if {
	some doc in rc.change.after.documentation
	doc.content != ""
	doc.content != null
}

# --- Required labels on labelled resource types. ---
deny contains msg if {
	some rc in upserts
	rc.type in labelled_types
	some key in required_labels
	not rc.change.after.labels[key]
	msg := sprintf("%s: missing required label %q", [rc.address, key])
}

# --- Approved regions only (data residency). ---
deny contains msg if {
	some rc in upserts
	rc.type in location_checked_types
	loc := lower(rc.change.after.location)
	not loc in approved_locations
	msg := sprintf("%s: location %q is not approved (allowed: %v)", [rc.address, rc.change.after.location, approved_locations])
}

# --- Destroy threshold: large teardowns must be explicit. ---
deny contains msg if {
	deletions := [rc | some rc in resource_changes; "delete" in rc.change.actions]
	count(deletions) > max_destroyed
	msg := sprintf("plan destroys %d resources (max %d) -- add an explicit override label to proceed", [count(deletions), max_destroyed])
}
