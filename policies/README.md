# policies

OPA/Conftest **pre-flight policy gate**. These run in CI against
`terraform show -json <plan>` output. A plan that trips any `deny` rule never reaches
apply — not even in dev. OPA is the pre-flight check; Org Policy is the runtime backstop.

Authored here in `multi-tenant-platform` as the **single source of truth** and consumed by
`multi-tenant-config`'s CI (pulled by pinned version, never copy-pasted — that would recreate the
two-sources-of-truth problem the platform avoids).

## Rules

| Rule | Enforces |
| ---- | -------- |
| no service-account keys | keyless identity only |
| uniform bucket-level access | no GCS ACLs |
| public access prevention enforced | no public buckets |
| CMEK required on buckets | no Google-managed encryption |
| KMS rotation_period required | no un-rotating keys |
| required labels | `tenant`, `environment`, `data_classification`, `managed-by` |
| destroy threshold | large teardowns must be explicitly overridden |

## Usage

```bash
# In CI, against a real plan:
terraform show -json plan.tfplan > plan.json
conftest test plan.json --policy policies/

# Unit-test the policy logic (no plan / cloud needed):
conftest verify -p policies
```
