variable "project_id" {
  description = "The runtime-<env> project that hosts the Composer environment."
  type        = string
}

variable "name" {
  description = "Composer environment name."
  type        = string
  default     = "runtime-composer"
}

variable "region" {
  description = "Region for the Composer environment."
  type        = string
}

variable "network" {
  description = "VPC network ID/self-link (from shared-vpc)."
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork ID/self-link (from shared-vpc)."
  type        = string
}

variable "image_version" {
  description = "Composer image. MUST be checked against currently-available versions at apply time — Composer images get deprecated."
  type        = string
  default     = "composer-2.9.7-airflow-2.9.3"
}

variable "environment_size" {
  description = "ENVIRONMENT_SIZE_SMALL | _MEDIUM | _LARGE."
  type        = string
  default     = "ENVIRONMENT_SIZE_SMALL"
}

variable "master_ipv4_cidr" {
  description = "/28 for the Composer GKE control plane. Must not overlap any other range in the VPC."
  type        = string
}

variable "composer_network_cidr" {
  description = "/24 for the Composer GKE pods/services network. Must not overlap any other range."
  type        = string
}

variable "web_server_cidr" {
  description = "/28 for the Airflow web server. Must not overlap any other range."
  type        = string
}

variable "labels" {
  description = "Resource labels; managed-by is injected automatically."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["tenant", "environment", "data_classification"] : contains(keys(var.labels), k)])
    error_message = "labels must include all of: tenant, environment, data_classification."
  }
}
