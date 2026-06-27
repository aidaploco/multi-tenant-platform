output "project_id" {
  description = "The created project's ID. Pass this to every other module targeting this tenant."
  value       = google_project.this.project_id
}

output "project_number" {
  description = "The created project's numeric ID. Needed for IAM principals and Workload Identity Federation bindings."
  value       = google_project.this.number
}

output "enabled_apis" {
  description = "The set of APIs enabled on the project."
  value       = keys(google_project_service.this)
}

output "labels" {
  description = "The effective labels applied (including the injected managed-by key)."
  value       = local.labels
}
