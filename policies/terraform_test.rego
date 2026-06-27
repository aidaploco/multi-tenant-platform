# Unit tests for the policy gate. Run with: conftest verify -p policies
#
# Each test feeds a synthetic plan-JSON fragment via `with input as` and asserts
# the deny set. No Terraform plan or cloud access is needed.

package main

import rego.v1

compliant_bucket := {
	"address": "module.landing.google_storage_bucket.this",
	"type": "google_storage_bucket",
	"change": {
		"actions": ["create"],
		"after": {
			"location": "europe-west4",
			"uniform_bucket_level_access": true,
			"public_access_prevention": "enforced",
			"encryption": [{"default_kms_key_name": "projects/p/locations/l/keyRings/r/cryptoKeys/gcs"}],
			"labels": {
				"tenant": "abf",
				"environment": "dev",
				"data_classification": "confidential",
				"managed-by": "terraform",
			},
		},
	},
}

test_compliant_bucket_passes if {
	count(deny) == 0 with input as {"resource_changes": [compliant_bucket]}
}

test_denies_service_account_key if {
	d := deny with input as {"resource_changes": [{
		"address": "google_service_account_key.bad",
		"type": "google_service_account_key",
		"change": {"actions": ["create"], "after": {}},
	}]}
	count(d) == 1
}

test_denies_non_uniform_bucket if {
	bucket := json.patch(compliant_bucket, [{"op": "replace", "path": "/change/after/uniform_bucket_level_access", "value": false}])
	d := deny with input as {"resource_changes": [bucket]}
	count(d) == 1
}

test_denies_public_bucket if {
	bucket := json.patch(compliant_bucket, [{"op": "replace", "path": "/change/after/public_access_prevention", "value": "inherited"}])
	d := deny with input as {"resource_changes": [bucket]}
	count(d) == 1
}

test_denies_bucket_without_cmek if {
	bucket := json.patch(compliant_bucket, [{"op": "replace", "path": "/change/after/encryption", "value": []}])
	d := deny with input as {"resource_changes": [bucket]}
	count(d) == 1
}

test_denies_missing_label if {
	bucket := json.patch(compliant_bucket, [{"op": "remove", "path": "/change/after/labels/data_classification"}])
	d := deny with input as {"resource_changes": [bucket]}
	count(d) == 1
}

test_denies_kms_key_without_rotation if {
	d := deny with input as {"resource_changes": [{
		"address": "module.keys.google_kms_crypto_key.this[\"gcs\"]",
		"type": "google_kms_crypto_key",
		"change": {"actions": ["create"], "after": {
			"labels": {
				"tenant": "abf", "environment": "dev",
				"data_classification": "confidential", "managed-by": "terraform",
			},
			# no rotation_period
		}},
	}]}
	count(d) == 1
}

test_denies_unapproved_region if {
	bucket := json.patch(compliant_bucket, [{"op": "replace", "path": "/change/after/location", "value": "us-central1"}])
	d := deny with input as {"resource_changes": [bucket]}
	count(d) == 1
}

test_approved_region_passes if {
	bucket := json.patch(compliant_bucket, [{"op": "replace", "path": "/change/after/location", "value": "EU"}])
	count(deny) == 0 with input as {"resource_changes": [bucket]}
}

test_denies_oversized_destroy if {
	deletions := [rc |
		some i in numbers.range(1, 6)
		rc := {
			"address": sprintf("google_storage_bucket.b%d", [i]),
			"type": "google_storage_bucket",
			"change": {"actions": ["delete"], "after": null},
		}
	]
	d := deny with input as {"resource_changes": deletions}
	count(d) >= 1
}
