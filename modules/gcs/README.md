# gcs

A private, **CMEK-encrypted** Cloud Storage bucket. The security posture is not negotiable:
uniform bucket-level access (no ACLs, ever) and `public_access_prevention = "enforced"` are
hardcoded, not inputs. The module also grants the project's GCS service agent permission to
use the supplied key, so CMEK bucket creation succeeds.

**Fails closed:** if `cmek_key_id` is null/empty the module errors out — it never falls back
to Google-managed encryption. Pair it with `kms-tenant`:

```hcl
module "landing" {
  source      = "git::https://github.com/<org>/platform-modules.git//modules/gcs?ref=v1.0.0"
  project_id  = module.project.project_id
  name        = "abf-dev-landing"
  location    = "europe-west4"
  cmek_key_id = module.keys.key_ids["gcs"]
  labels      = local.labels

  lifecycle_rules = [
    { action_type = "SetStorageClass", storage_class = "NEARLINE", age_days = 30 },
    { action_type = "Delete", age_days = 365, with_state = "ARCHIVED" },
  ]
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
| [google_kms_crypto_key_iam_member.gcs_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_storage_bucket.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_project_service_account.gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cmek_key_id"></a> [cmek\_key\_id](#input\_cmek\_key\_id) | Full KMS crypto-key ID to encrypt the bucket (from kms-tenant's key\_ids output). REQUIRED -- the module fails closed if absent rather than fall back to Google-managed keys. | `string` | `null` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow `terraform destroy` to delete a non-empty bucket. Keep false for real data. | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Resource labels; managed-by is injected automatically. | `map(string)` | n/a | yes |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | Optional object-lifecycle rules (e.g. delete or down-tier old/noncurrent objects). | <pre>list(object({<br/>    action_type   = string           # "Delete" or "SetStorageClass"<br/>    storage_class = optional(string) # required when action_type = "SetStorageClass"<br/>    age_days      = optional(number)<br/>    with_state    = optional(string, "ANY") # ANY | LIVE | ARCHIVED<br/>  }))</pre> | `[]` | no |
| <a name="input_location"></a> [location](#input\_location) | Bucket location (region or multi-region). Constrained by the gcp.resourceLocations org policy. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally-unique bucket name (e.g. "abf-dev-landing"). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The tenant's data project that will own the bucket. | `string` | n/a | yes |
| <a name="input_storage_class"></a> [storage\_class](#input\_storage\_class) | Default storage class for objects. | `string` | `"STANDARD"` | no |
| <a name="input_versioning"></a> [versioning](#input\_versioning) | Enable object versioning (recommended for data buckets). | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_name"></a> [name](#output\_name) | The bucket name. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | The bucket's self link. |
| <a name="output_url"></a> [url](#output\_url) | The gs:// URL of the bucket. |
<!-- END_TF_DOCS -->
