variable "project_id" {
  description = "The KMS keys project (a dedicated key-management project, NOT the tenant's data project -- separation of duties)."
  type        = string
}

variable "keyring_name" {
  description = "Name of the tenant's key ring, e.g. \"abf-keyring\". Key rings cannot be deleted once created (GCP behaviour)."
  type        = string
}

variable "location" {
  description = "KMS location for the key ring (e.g. \"europe-west4\"). Per-tenant, driven by the tenant's cmek_location."
  type        = string
}

variable "keys" {
  description = "Logical key names to create, one per service type. Each becomes a CMEK key consumed by the matching data module."
  type        = list(string)
  default     = ["gcs", "sql", "bq", "secret"]

  validation {
    condition     = length(var.keys) > 0
    error_message = "At least one key must be created."
  }
}

variable "rotation_period" {
  description = "Automatic rotation period in seconds (GCP-native rotation; no cron job). Defaults to 90 days. Min 1 day."
  type        = string
  default     = "7776000s" # 90 days

  validation {
    condition     = can(regex("^[0-9]+s$", var.rotation_period)) && tonumber(trimsuffix(var.rotation_period, "s")) >= 86400
    error_message = "rotation_period must be a seconds string like \"7776000s\" and at least 86400s (1 day)."
  }
}

variable "protection_level" {
  description = "SOFTWARE for standard data; HSM (Cloud HSM) for the highest data_classification tier."
  type        = string
  default     = "SOFTWARE"

  validation {
    condition     = contains(["SOFTWARE", "HSM"], var.protection_level)
    error_message = "protection_level must be SOFTWARE or HSM."
  }
}

variable "labels" {
  description = "Resource labels; managed-by is injected automatically. Applied to crypto keys (key rings do not support labels)."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["tenant", "environment", "data_classification"] : contains(keys(var.labels), k)])
    error_message = "labels must include all of: tenant, environment, data_classification."
  }
}
