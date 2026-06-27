# Unit tests for the observability module (mocked provider: no cost).

mock_provider "google" {}

variables {
  project_id    = "abf-dev-7f3a"
  display_name  = "abf-dev-landing"
  metric_filter = "resource.type = \"gcs_bucket\" AND metric.type = \"storage.googleapis.com/network/sent_bytes_count\""
  labels = {
    tenant              = "abf"
    environment         = "dev"
    data_classification = "confidential"
  }
}

run "ships_alert_and_valid_dashboard_by_default" {
  command = plan

  assert {
    condition     = length(google_monitoring_alert_policy.egress) == 1
    error_message = "Baseline egress alert should be created by default."
  }

  assert {
    condition     = google_monitoring_alert_policy.egress[0].conditions[0].condition_threshold[0].threshold_value == 1073741824
    error_message = "Egress threshold should default to 1 GiB."
  }

  # The dashboard JSON must be valid JSON and carry the resource's display name.
  assert {
    condition     = jsondecode(google_monitoring_dashboard.this.dashboard_json).displayName == var.display_name
    error_message = "Templated dashboard JSON must be valid and titled with the display name."
  }
}

run "no_log_sink_without_bucket" {
  command = plan

  assert {
    condition     = length(google_logging_project_sink.this) == 0
    error_message = "No log sink should be created when log_bucket_id is null."
  }
}

run "log_sink_created_when_bucket_given" {
  command = plan

  variables {
    log_bucket_id = "projects/abf-dev-7f3a/locations/global/buckets/abf-dev-logs"
  }

  assert {
    condition     = length(google_logging_project_sink.this) == 1
    error_message = "A log sink should be created when log_bucket_id is set."
  }
}

run "baseline_alert_can_be_disabled" {
  command = plan

  variables {
    enable_egress_alert = false
  }

  assert {
    condition     = length(google_monitoring_alert_policy.egress) == 0
    error_message = "Disabling the flag should remove the alert policy."
  }
}

run "threshold_is_overridable" {
  command = plan

  variables {
    egress_threshold_bytes = 5368709120 # 5 GiB
  }

  assert {
    condition     = google_monitoring_alert_policy.egress[0].conditions[0].condition_threshold[0].threshold_value == 5368709120
    error_message = "Callers must be able to override the threshold."
  }
}
