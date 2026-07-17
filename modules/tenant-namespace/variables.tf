variable "namespace" {
  description = "Namespace name (the tenant slug)."
  type        = string
}

variable "owner_group" {
  description = "Google group granted read + operate rights (view, Secrets, logs, exec/port-forward) WITHIN this namespace only — never `edit`; workloads and NetworkPolicies are platform-owned (ADR-0023)."
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

variable "extra_egress_cidrs" {
  description = "Explicit, additional egress allow-rules beyond the default baseline (DNS, same-namespace, platform-system, external-minus-private-ranges). For narrow, documented exceptions only — e.g. a local-dev dependency that lives outside the cluster (ADR-0022 in platform-config). `cidr` should be a /32 for a single host unless a real range is intended. Never populated in real/GKE mode."
  type = list(object({
    cidr     = string
    port     = string
    protocol = optional(string, "TCP")
  }))
  default = []
}

variable "labels" {
  description = "Namespace labels; managed-by is injected automatically."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["tenant", "environment", "data_classification"] : contains(keys(var.labels), k)])
    error_message = "labels must include all of: tenant, environment, data_classification."
  }
}
