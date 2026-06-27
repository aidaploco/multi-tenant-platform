# observability: platform-shipped monitoring for one resource.
#
# The platform ships observability; tenants do not configure it. They may disable
# a specific baseline alert (the _enable flags) or ADD their own, but they cannot
# remove this module's invocation. Thresholds are hardcoded-but-overridable.
#
# What this module does NOT do: create the log bucket (tenant bootstrap owns it)
# or create notification channels (one set per tenant, passed in here).

locals {
  labels = merge(var.labels, { "managed-by" = "terraform" })
}

# Route this resource's logs to the tenant's (WORM) log bucket, when one is given.
resource "google_logging_project_sink" "this" {
  count = var.log_bucket_id != null ? 1 : 0

  name        = "${var.display_name}-sink"
  project     = var.project_id
  destination = "logging.googleapis.com/${var.log_bucket_id}"
  filter      = var.log_filter

  unique_writer_identity = true
}

# Baseline alert. Optional resources use count, never dynamic blocks (per the
# module rules). Adding the rest of the per-type alerts follows this same shape.
resource "google_monitoring_alert_policy" "egress" {
  count = var.enable_egress_alert ? 1 : 0

  project      = var.project_id
  display_name = "${var.display_name} - egress spike"
  combiner     = "OR"

  conditions {
    display_name = "egress above threshold"
    condition_threshold {
      filter          = var.metric_filter
      comparison      = "COMPARISON_GT"
      threshold_value = var.egress_threshold_bytes
      duration        = var.alert_duration

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.notification_channels

  # Every alert must link a runbook (enforced by an OPA policy on the plan).
  documentation {
    content   = "Runbook: ${var.runbook_url}"
    mime_type = "text/markdown"
  }

  user_labels = local.labels
}

# Dashboard rendered from a JSON template. Dashboard JSON is not Terraform-native,
# so templatefile() is the sanctioned tool here (and the only place it's allowed).
resource "google_monitoring_dashboard" "this" {
  project = var.project_id

  dashboard_json = templatefile("${path.module}/templates/dashboard.json.tftpl", {
    display_name  = var.display_name
    metric_filter = var.metric_filter
  })
}
