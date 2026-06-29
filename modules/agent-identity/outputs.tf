output "email" {
  description = "The service account email."
  value       = google_service_account.this.email
}

output "member" {
  description = "IAM member string for this SA (serviceAccount:<email>), for granting it access elsewhere."
  value       = "serviceAccount:${google_service_account.this.email}"
}

output "account_id" {
  description = "Full resource name of the service account."
  value       = google_service_account.this.name
}

output "workload_identity_member" {
  description = "The Kubernetes SA bound to this identity, or null if no binding was requested."
  value       = local.wi_member
}
