variable "project_id" {
  description = "Project that owns the monitored resource and these monitoring resources."
  type        = string
}

variable "display_name" {
  description = "Human label for the monitored resource (used in alert and dashboard titles), e.g. \"abf-dev-landing\"."
  type        = string
}

variable "metric_filter" {
  description = "Monitoring filter selecting the primary time series for this resource. Has a sensible default per the caller's resource type."
  type        = string
}

variable "notification_channels" {
  description = "Notification channel IDs alerts fire to. Created once per tenant, not per resource (so this is passed in, never created here)."
  type        = list(string)
  default     = []
}

variable "log_bucket_id" {
  description = "Destination log bucket ID. When set, a log sink routes this resource's logs there. When null, no sink is created. The bucket is never created here -- and nothing in the platform creates one yet (ADR-0006 tracked)."
  type        = string
  default     = null
}

variable "log_filter" {
  description = "Filter for the log sink (which log entries to route)."
  type        = string
  default     = ""
}

variable "egress_threshold_bytes" {
  description = "Egress-spike alert threshold. Hardcoded-but-overridable default; tenants rarely change it."
  type        = number
  default     = 1073741824 # 1 GiB / alignment window
}

variable "alert_duration" {
  description = "How long the condition must hold before alerting."
  type        = string
  default     = "300s"
}

variable "enable_egress_alert" {
  description = "Baseline alert toggle. Callers may disable a specific alert but cannot remove the module invocation (the platform always ships observability)."
  type        = bool
  default     = true
}

variable "runbook_url" {
  description = "Runbook link embedded in alert documentation. Policy requires every alert to carry one."
  type        = string
  default     = "https://github.com/<org>/platform-config/blob/main/docs/runbooks/observability.md"
}

variable "labels" {
  description = "Resource labels; managed-by is injected automatically."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["tenant", "environment", "data_classification"] : contains(keys(var.labels), k)])
    error_message = "labels must include all of: tenant, environment, data_classification."
  }
}
