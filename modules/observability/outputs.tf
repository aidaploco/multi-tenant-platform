output "dashboard_id" {
  description = "The created Monitoring dashboard ID."
  value       = google_monitoring_dashboard.this.id
}

output "alert_policy_ids" {
  description = "IDs of the alert policies actually created (respects the _enable flags)."
  value       = google_monitoring_alert_policy.egress[*].id
}

output "log_sink_writer_identity" {
  description = "Writer identity of the log sink (grant it access to the log bucket). Empty if no sink was created."
  value       = try(google_logging_project_sink.this[0].writer_identity, null)
}
