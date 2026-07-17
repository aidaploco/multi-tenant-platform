variable "project_id" {
  description = "The runtime-<env> project that hosts the cluster."
  type        = string
}

variable "name" {
  description = "Cluster name."
  type        = string
  default     = "runtime-cluster"
}

variable "region" {
  description = "Region for this regional Autopilot cluster."
  type        = string
}

variable "network" {
  description = "VPC network ID/self-link (from the shared-vpc module)."
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork ID/self-link the nodes attach to (from the shared-vpc module)."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods (VPC-native)."
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services (VPC-native)."
  type        = string
}

variable "master_ipv4_cidr" {
  description = "The /28 reserved for the private control plane. Must not overlap the VPC ranges."
  type        = string
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the control-plane endpoint. Default [] = no external access (admin via IAP)."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "release_channel" {
  description = "GKE release channel (auto-upgrades)."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "deletion_protection" {
  description = "Block accidental cluster deletion. Set false only for throwaway/dev."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Resource labels; managed-by is injected automatically."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["tenant", "environment", "data_classification"] : contains(keys(var.labels), k)])
    error_message = "labels must include all of: tenant, environment, data_classification."
  }
}

variable "database_encryption_key" {
  description = "CMEK crypto-key ID for application-layer encryption of Kubernetes Secrets in etcd (ADR-0025 D25-1). REQUIRED — substrate encryption is not optional. A PLATFORM key (runtime project), never a tenant key: shared substrate cannot be per-tenant encrypted."
  type        = string

  validation {
    condition     = length(var.database_encryption_key) > 0
    error_message = "database_encryption_key must be set — a cluster without substrate CMEK is a silent compliance gap (ADR-0025)."
  }
}

variable "boot_disk_kms_key" {
  description = "CMEK crypto-key ID for node boot disks, applied via Autopilot auto-provisioning defaults (ADR-0025 D25-1). REQUIRED. The Compute service agent needs cryptoKeyEncrypterDecrypter on it — granted by the caller."
  type        = string

  validation {
    condition     = length(var.boot_disk_kms_key) > 0
    error_message = "boot_disk_kms_key must be set — a cluster without substrate CMEK is a silent compliance gap (ADR-0025)."
  }
}
