variable "project_id" {
  description = "The runtime-<env> project that owns this shared network."
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network."
  type        = string
  default     = "runtime-vpc"
}

variable "region" {
  description = "Region for the subnetwork, router, and NAT."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary IPv4 range for nodes."
  type        = string
}

variable "pods_cidr" {
  description = "Secondary range for GKE pods (VPC-native cluster)."
  type        = string
}

variable "services_cidr" {
  description = "Secondary range for GKE services (VPC-native cluster)."
  type        = string
}

variable "iap_source_range" {
  description = "Google IAP TCP-forwarding range — the only admin ingress path."
  type        = string
  default     = "35.235.240.0/20"
}
