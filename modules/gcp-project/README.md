# gcp-project

Creates a single GCP project — the platform's **tenant isolation boundary** (billing +
IAM + API-enablement in one). Enables only the APIs it is told to, never creates the legacy
default VPC (`auto_create_network = false`), injects the `managed-by = terraform` label, and
defaults to `deletion_policy = PREVENT` so a stray destroy can't delete a live tenant.

Everything else in the platform runs *inside* a project created here.

```hcl
module "project" {
  source          = "git::https://github.com/<org>/platform-modules.git//modules/gcp-project?ref=v1.0.0"
  project_id      = "abf-dev-7f3a"
  display_name    = "ABF Analytics dev"
  folder_id       = "folders/123456789"
  billing_account = var.billing_account
  activate_apis   = ["storage.googleapis.com", "cloudkms.googleapis.com"]
  labels = {
    tenant              = "abf"
    environment         = "dev"
    data_classification = "confidential"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 6.50.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_service.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_activate_apis"></a> [activate\_apis](#input\_activate\_apis) | APIs to enable on the project. Keep this minimal: enabling an API widens the attack surface, so callers pass only what the tenant's enabled layers require. | `list(string)` | <pre>[<br/>  "cloudresourcemanager.googleapis.com",<br/>  "serviceusage.googleapis.com",<br/>  "iam.googleapis.com",<br/>  "logging.googleapis.com",<br/>  "monitoring.googleapis.com"<br/>]</pre> | no |
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | Billing account ID to associate (e.g. "0X0X0X-0X0X0X-0X0X0X"). | `string` | n/a | yes |
| <a name="input_deletion_policy"></a> [deletion\_policy](#input\_deletion\_policy) | PREVENT in prod (blocks accidental project deletion), DELETE in dev/staging. Defaults to the safe option. | `string` | `"PREVENT"` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Human-readable project name shown in the console. | `string` | n/a | yes |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | Numeric ID of the parent folder (e.g. "folders/123456789"). Tenants live under folders for org-policy inheritance; the folder is NOT the isolation boundary (the project is). | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Resource labels. Must include the platform-mandated keys; managed-by is injected automatically. | `map(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Globally-unique project ID (e.g. "abf-dev-7f3a"). Immutable after creation. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_enabled_apis"></a> [enabled\_apis](#output\_enabled\_apis) | The set of APIs enabled on the project. |
| <a name="output_labels"></a> [labels](#output\_labels) | The effective labels applied (including the injected managed-by key). |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The created project's ID. Pass this to every other module targeting this tenant. |
| <a name="output_project_number"></a> [project\_number](#output\_project\_number) | The created project's numeric ID. Needed for IAM principals and Workload Identity Federation bindings. |
<!-- END_TF_DOCS -->
