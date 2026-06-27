# Provider and Terraform version constraints.
#
# We set a floor of 1.9 (the platform standard) and an upper bound on the
# google provider major version. Exact, reproducible versions are pinned in
# each consumer's .terraform.lock.hcl, NOT here -- a module that hard-pins an
# exact provider version cannot be composed with other modules that pinned a
# different patch. Floor + ceiling here, lockfile for exactness, is the
# idiomatic split.
terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 7.0"
    }
  }
}
