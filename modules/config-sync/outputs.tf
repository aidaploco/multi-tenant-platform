output "membership_id" {
  description = "Fleet membership ID for the cluster."
  value       = google_gke_hub_membership.this.membership_id
}

output "policy_dir" {
  description = "The directory Config Sync reconciles."
  value       = var.policy_dir
}

output "git_token_secret_id" {
  description = "Secret Manager secret holding the git read token, or null if not token auth."
  value       = var.secret_type == "token" ? google_secret_manager_secret.git_token[0].secret_id : null
}
