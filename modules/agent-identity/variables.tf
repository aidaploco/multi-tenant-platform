variable "project_id" {
  description = "Tenant project where this runtime service account lives — so it can be granted access to that tenant's own data, and nothing else (ADR-0001 D2/D13)."
  type        = string
}

variable "account_id" {
  description = "Service account ID (6-30 chars). Typically \"<tenant>-<unit>\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.account_id))
    error_message = "account_id must be 6-30 chars: a lowercase letter first, then lowercase letters/digits/hyphens, not ending in a hyphen."
  }
}

variable "display_name" {
  description = "Human-readable name for the service account."
  type        = string
}

variable "iam_roles" {
  description = "Roles granted to this SA on iam_project. Must be least-privilege."
  type        = list(string)
  default     = []

  # Primitive roles are never least-privilege. (The OPA gate also blocks owner/editor as a
  # platform-wide backstop; this module is stricter and additionally forbids primitive viewer.)
  validation {
    condition     = alltrue([for r in var.iam_roles : !contains(["roles/owner", "roles/editor", "roles/viewer"], r)])
    error_message = "Primitive roles (roles/owner, roles/editor, roles/viewer) are forbidden; grant predefined or custom least-privilege roles."
  }

  # Never grant the power to mint SA keys — that would undermine keyless identity (ADR-0001 D5).
  validation {
    condition     = alltrue([for r in var.iam_roles : !contains(["roles/iam.serviceAccountKeyAdmin", "roles/iam.serviceAccountKeyCreator"], r)])
    error_message = "Granting the ability to create service-account keys is forbidden (keyless identity only)."
  }
}

variable "iam_project" {
  description = "Project to grant iam_roles on. Defaults to project_id (the tenant's own project)."
  type        = string
  default     = null
}

variable "workload_identity" {
  description = "Optional Workload Identity binding: the Kubernetes SA in the shared runtime allowed to act AS this GCP SA. null = no binding yet (the runtime cluster may not exist)."
  type = object({
    runtime_project_id = string
    namespace          = string
    ksa_name           = string
  })
  default = null
}
