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

test_denies_primitive_role if {
	d := deny with input as {"resource_changes": [{
		"address": "google_project_iam_member.bad",
		"type": "google_project_iam_member",
		"change": {"actions": ["create"], "after": {"role": "roles/editor"}},
	}]}
	count(d) == 1
}

test_denies_sa_key_role_grant if {
	d := deny with input as {"resource_changes": [{
		"address": "module.identity.google_project_iam_member.roles[\"x\"]",
		"type": "google_project_iam_member",
		"change": {"actions": ["create"], "after": {"role": "roles/iam.serviceAccountKeyCreator"}},
	}]}
	count(d) == 1
}

# The read-only CI planner uses roles/viewer; it must NOT be denied.
test_allows_viewer_grant if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "google_project_iam_member.planner",
		"type": "google_project_iam_member",
		"change": {"actions": ["create"], "after": {"role": "roles/viewer"}},
	}]}
}

test_denies_alert_without_runbook if {
	d := deny with input as {"resource_changes": [{
		"address": "module.obs.google_monitoring_alert_policy.egress[0]",
		"type": "google_monitoring_alert_policy",
		"change": {"actions": ["create"], "after": {"documentation": []}},
	}]}
	count(d) == 1
}

test_allows_alert_with_runbook if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "module.obs.google_monitoring_alert_policy.egress[0]",
		"type": "google_monitoring_alert_policy",
		"change": {"actions": ["create"], "after": {"documentation": [{"content": "Runbook: https://x", "mime_type": "text/markdown"}]}},
	}]}
}

test_denies_world_open_ingress if {
	d := deny with input as {"resource_changes": [{
		"address": "google_compute_firewall.bad",
		"type": "google_compute_firewall",
		"change": {"actions": ["create"], "after": {
			"direction": "INGRESS",
			"allow": [{"protocol": "tcp", "ports": ["22"]}],
			"source_ranges": ["0.0.0.0/0"],
		}},
	}]}
	count(d) == 1
}

test_allows_iap_scoped_ingress if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "google_compute_firewall.iap",
		"type": "google_compute_firewall",
		"change": {"actions": ["create"], "after": {
			"direction": "INGRESS",
			"allow": [{"protocol": "tcp", "ports": ["22"]}],
			"source_ranges": ["35.235.240.0/20"],
		}},
	}]}
}

test_denies_subnet_without_pga if {
	d := deny with input as {"resource_changes": [{
		"address": "google_compute_subnetwork.bad",
		"type": "google_compute_subnetwork",
		"change": {"actions": ["create"], "after": {"private_ip_google_access": false}},
	}]}
	count(d) == 1
}

test_denies_public_gke if {
	d := deny with input as {"resource_changes": [{
		"address": "google_container_cluster.bad",
		"type": "google_container_cluster",
		"change": {"actions": ["create"], "after": {"private_cluster_config": []}},
	}]}
	count(d) == 1
}

test_allows_private_gke if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "google_container_cluster.ok",
		"type": "google_container_cluster",
		"change": {"actions": ["create"], "after": {"private_cluster_config": [{"enable_private_nodes": true}]}},
	}]}
}

test_denies_public_composer if {
	d := deny with input as {"resource_changes": [{
		"address": "google_composer_environment.bad",
		"type": "google_composer_environment",
		"change": {"actions": ["create"], "after": {"config": [{"private_environment_config": [{"enable_private_endpoint": false}]}]}},
	}]}
	count(d) == 1
}

test_allows_private_composer if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "google_composer_environment.ok",
		"type": "google_composer_environment",
		"change": {"actions": ["create"], "after": {"config": [{"private_environment_config": [{"enable_private_endpoint": true}]}]}},
	}]}
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

# The teardown pipeline's explicit override waives ONLY the destroy threshold...
test_allows_oversized_destroy_with_override if {
	deletions := [rc |
		some i in numbers.range(1, 6)
		rc := {
			"address": sprintf("google_storage_bucket.b%d", [i]),
			"type": "google_storage_bucket",
			"change": {"actions": ["delete"], "after": null},
		}
	]
	count(deny) == 0 with input as {"resource_changes": deletions}
		with data.exceptions.allow_destroy_over_threshold as true
}

# ...every other deny still applies during a teardown (an offboard must not smuggle in, say, a
# service-account key).
test_override_does_not_waive_other_denies if {
	d := deny with input as {"resource_changes": [{
		"address": "google_service_account_key.bad",
		"type": "google_service_account_key",
		"change": {"actions": ["create"], "after": {}},
	}]}
		with data.exceptions.allow_destroy_over_threshold as true
	count(d) == 1
}
