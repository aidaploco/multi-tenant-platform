variable "project_id" {
  description = "Globally-unique project ID (e.g. \"abf-dev-7f3a\"). Immutable after creation."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6-30 chars, lowercase letters/digits/hyphens, start with a letter."
  }
}

variable "display_name" {
  description = "Human-readable project name shown in the console."
  type        = string
}

variable "folder_id" {
  description = "Numeric ID of the parent folder (e.g. \"folders/123456789\"). Tenants live under folders for org-policy inheritance; the folder is NOT the isolation boundary (the project is)."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID to associate (e.g. \"0X0X0X-0X0X0X-0X0X0X\")."
  type        = string
}

variable "activate_apis" {
  description = "APIs to enable on the project. Keep this minimal: enabling an API widens the attack surface, so callers pass only what the tenant's enabled layers require."
  type        = list(string)
  default = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

variable "labels" {
  description = "Resource labels. Must include the platform-mandated keys; managed-by is injected automatically."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["tenant", "environment", "data_classification"] : contains(keys(var.labels), k)])
    error_message = "labels must include all of: tenant, environment, data_classification."
  }
}

variable "deletion_policy" {
  description = "PREVENT in prod (blocks accidental project deletion), DELETE in dev/staging. Defaults to the safe option."
  type        = string
  default     = "PREVENT"

  validation {
    condition     = contains(["PREVENT", "DELETE", "ABANDON"], var.deletion_policy)
    error_message = "deletion_policy must be one of PREVENT, DELETE, ABANDON."
  }
}
