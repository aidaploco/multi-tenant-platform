output "name" {
  description = "Composer environment name."
  value       = google_composer_environment.this.name
}

output "service_account_email" {
  description = "The Composer environment's runtime service account."
  value       = google_service_account.composer.email
}

output "airflow_uri" {
  description = "Airflow web UI URI."
  value       = google_composer_environment.this.config[0].airflow_uri
}

output "dag_gcs_prefix" {
  description = "GCS prefix where DAGs are uploaded (per-tenant DAG folders live under this)."
  value       = google_composer_environment.this.config[0].dag_gcs_prefix
}
