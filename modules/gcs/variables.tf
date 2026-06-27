variable "project_id" {
  description = "The tenant's data project that will own the bucket."
  type        = string
}

variable "name" {
  description = "Globally-unique bucket name (e.g. \"abf-dev-landing\")."
  type        = string
}

variable "location" {
  description = "Bucket location (region or multi-region). Constrained by the gcp.resourceLocations org policy."
  type        = string
}

variable "cmek_key_id" {
  description = "Full KMS crypto-key ID to encrypt the bucket (from kms-tenant's key_ids output). REQUIRED -- the module fails closed if absent rather than fall back to Google-managed keys."
  type        = string
  default     = null

  validation {
    # Fail-closed CMEK guard: reject both null and empty string. (`!= null`
    # short-circuits, and `null != ""` is itself a safe, error-free comparison.)
    condition     = var.cmek_key_id != null && var.cmek_key_id != ""
    error_message = "cmek_key_id is required: this module never falls back to Google-managed encryption keys."
  }
}

variable "storage_class" {
  description = "Default storage class for objects."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "storage_class must be one of STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }
}

variable "versioning" {
  description = "Enable object versioning (recommended for data buckets)."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete a non-empty bucket. Keep false for real data."
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "Optional object-lifecycle rules (e.g. delete or down-tier old/noncurrent objects)."
  type = list(object({
    action_type   = string           # "Delete" or "SetStorageClass"
    storage_class = optional(string) # required when action_type = "SetStorageClass"
    age_days      = optional(number)
    with_state    = optional(string, "ANY") # ANY | LIVE | ARCHIVED
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.lifecycle_rules : contains(["Delete", "SetStorageClass"], r.action_type)])
    error_message = "lifecycle_rules[*].action_type must be Delete or SetStorageClass."
  }
}

variable "labels" {
  description = "Resource labels; managed-by is injected automatically."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["tenant", "environment", "data_classification"] : contains(keys(var.labels), k)])
    error_message = "labels must include all of: tenant, environment, data_classification."
  }
}
