output "name" {
  description = "Cluster name."
  value       = google_container_cluster.this.name
}

output "id" {
  description = "Cluster ID."
  value       = google_container_cluster.this.id
}

output "endpoint" {
  description = "Control-plane endpoint."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "workload_pool" {
  description = "The Workload Identity pool (agent-unit SAs bind to this)."
  value       = "${var.project_id}.svc.id.goog"
}

output "enable_autopilot" {
  description = "Whether Autopilot is enabled (always true for this module)."
  value       = google_container_cluster.this.enable_autopilot
}
