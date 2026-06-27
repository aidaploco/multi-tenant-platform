output "name" {
  description = "The bucket name."
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "The gs:// URL of the bucket."
  value       = google_storage_bucket.this.url
}

output "self_link" {
  description = "The bucket's self link."
  value       = google_storage_bucket.this.self_link
}
