variable "namespace" {
  description = "Namespace name (the tenant slug)."
  type        = string
}

variable "owner_group" {
  description = "Google group granted edit rights WITHIN this namespace only."
  type        = string
}

variable "service_accounts" {
  description = "Kubernetes SA name -> the GCP SA email it impersonates (Workload Identity). One per agent-unit."
  type        = map(string)
  default     = {}
}

variable "quota" {
  description = "ResourceQuota hard limits."
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
    pods            = string
  })
  default = {
    requests_cpu    = "8"
    requests_memory = "16Gi"
    limits_cpu      = "16"
    limits_memory   = "32Gi"
    pods            = "50"
  }
}

variable "labels" {
  description = "Namespace labels; managed-by is injected automatically."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["tenant", "environment", "data_classification"] : contains(keys(var.labels), k)])
    error_message = "labels must include all of: tenant, environment, data_classification."
  }
}
