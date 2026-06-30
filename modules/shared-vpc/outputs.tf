output "network_id" {
  description = "The VPC network ID."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "The VPC network name."
  value       = google_compute_network.this.name
}

output "subnetwork_id" {
  description = "The subnetwork ID (for attaching the GKE cluster)."
  value       = google_compute_subnetwork.this.id
}

output "subnetwork_name" {
  description = "The subnetwork name."
  value       = google_compute_subnetwork.this.name
}

output "pods_range_name" {
  description = "Secondary range name for GKE pods (VPC-native cluster config)."
  value       = "pods"
}

output "services_range_name" {
  description = "Secondary range name for GKE services (VPC-native cluster config)."
  value       = "services"
}
