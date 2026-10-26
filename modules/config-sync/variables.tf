variable "project_id" {
  description = "The runtime-<env> project that owns the cluster and fleet membership."
  type        = string
}

variable "region" {
  description = "Membership location (the cluster's region)."
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster to register + reconcile."
  type        = string
}

variable "cluster_id" {
  description = "Full resource link/ID of the GKE cluster (from the gke-autopilot module)."
  type        = string
}

variable "sync_repo" {
  description = "Git repo Config Sync reads (the multi-tenant-config repo)."
  type        = string
}

variable "sync_branch" {
  description = "Branch to sync."
  type        = string
  default     = "main"
}

variable "policy_dir" {
  description = "Directory within the repo Config Sync reconciles."
  type        = string
  default     = "gitops"
}

variable "secret_type" {
  description = "Config Sync git auth: none (public) | token (Secret Manager) | gcpserviceaccount (keyless)."
  type        = string
  default     = "token"

  validation {
    condition     = contains(["none", "token", "gcpserviceaccount"], var.secret_type)
    error_message = "secret_type must be none, token, or gcpserviceaccount."
  }
}

variable "enable_policy_controller" {
  description = "Enable Policy Controller (Gatekeeper) to enforce the gitops constraints (ADR-0015)."
  type        = bool
  default     = true
}

variable "rotation_days" {
  description = "Rotation cadence recorded on the git-token secret (ADR-0006). Operational refresh; SM rotation needs a function."
  type        = number
  default     = 90
}

variable "labels" {
  description = "Resource labels; managed-by is injected automatically."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["tenant", "environment", "data_classification"] : contains(keys(var.labels), k)])
    error_message = "labels must include all of: tenant, environment, data_classification."
  }
}
