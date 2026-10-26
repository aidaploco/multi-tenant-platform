# kms-tenant

Creates a tenant's Cloud KMS **key ring** and one **CMEK key per service type**
(`gcs`, `sql`, `bq`, `secret` by default), in a **dedicated key-management project** —
separate from the tenant's data project so key control and data access are different
principals (separation of duties).

Keys rotate automatically every 90 days via GCP-native `rotation_period`. There is
**no rotation pipeline** — that was a failure mode in the reference platform. Use `HSM`
protection for the highest `data_classification` tier.

The `key_ids` output feeds the `cmek_key_id` input of the data modules:

```hcl
module "keys" {
  source       = "git::https://github.com/<org>/multi-tenant-platform.git//modules/kms-tenant?ref=v1.0.0"
  project_id   = "company-keys-prod"   # the keys project, NOT the tenant data project
  keyring_name = "abf-keyring"
  location     = "europe-west4"
  labels       = local.labels
}

module "landing_bucket" {
  source      = "...//modules/gcs?ref=v1.0.0"
  cmek_key_id = module.keys.key_ids["gcs"]
  # ...
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
| [google_kms_crypto_key.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key) | resource |
| [google_kms_key_ring.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_keyring_name"></a> [keyring\_name](#input\_keyring\_name) | Name of the tenant's key ring, e.g. "abf-keyring". Key rings cannot be deleted once created (GCP behaviour). | `string` | n/a | yes |
| <a name="input_keys"></a> [keys](#input\_keys) | Logical key names to create, one per service type. Each becomes a CMEK key consumed by the matching data module. | `list(string)` | <pre>[<br/>  "gcs",<br/>  "sql",<br/>  "bq",<br/>  "secret"<br/>]</pre> | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Resource labels; managed-by is injected automatically. Applied to crypto keys (key rings do not support labels). | `map(string)` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | KMS location for the key ring (e.g. "europe-west4"). Per-tenant, driven by the tenant's cmek\_location. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The KMS keys project (a dedicated key-management project, NOT the tenant's data project -- separation of duties). | `string` | n/a | yes |
| <a name="input_protection_level"></a> [protection\_level](#input\_protection\_level) | SOFTWARE for standard data; HSM (Cloud HSM) for the highest data\_classification tier. | `string` | `"SOFTWARE"` | no |
| <a name="input_rotation_period"></a> [rotation\_period](#input\_rotation\_period) | Automatic rotation period in seconds (GCP-native rotation; no cron job). Defaults to 90 days. Min 1 day. | `string` | `"7776000s"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_ids"></a> [key\_ids](#output\_key\_ids) | Map of logical key name -> full crypto-key ID. Pass the relevant entry as cmek\_key\_id to data modules (e.g. key\_ids["gcs"]). |
| <a name="output_keyring_id"></a> [keyring\_id](#output\_keyring\_id) | Full resource ID of the tenant's key ring. |
<!-- END_TF_DOCS -->
