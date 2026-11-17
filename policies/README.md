# policies

OPA/Conftest **pre-flight policy gate**. These run in CI against
`terraform show -json <plan>` output. A plan that trips any `deny` rule never reaches
apply — not even in dev. OPA is the pre-flight check; Org Policy is the runtime backstop.

Authored here in `multi-tenant-platform` as the **single source of truth** and consumed by
`multi-tenant-config`'s CI (pulled by pinned version, never copy-pasted — that would recreate the
two-sources-of-truth problem the platform avoids).

## Rules

Every rule is a `deny`: any one of them blocks the plan.

| Rule | Enforces |
| ---- | -------- |
| no service-account keys | keyless identity only |
| no `roles/owner` / `roles/editor` grants | on project, folder, org and service-account IAM members (`roles/viewer` is allowed: the read-only CI planner uses it) |
| no SA-key-minting roles | `serviceAccountKeyAdmin` / `serviceAccountKeyCreator` can never be granted |
| uniform bucket-level access | no GCS ACLs |
| public access prevention enforced | no public buckets |
| CMEK required on buckets | no Google-managed encryption |
| KMS rotation_period required | no un-rotating keys |
| required labels | `tenant`, `environment`, `data_classification`, `managed-by` on projects, buckets and KMS keys |
| approved locations only | buckets and KMS key rings must be in `europe-west4` or `eu` (data residency) |
| alert policies link a runbook | `documentation.content` must be set |
| alert policies reach a notification channel | at least one; channels created in the same plan (unknown until apply) are accepted |
| no world-open ingress | a firewall *allow* rule may not use source `0.0.0.0/0` |
| Private Google Access on subnets | `private_ip_google_access = true` |
| private GKE nodes | `enable_private_nodes = true` |
| private Composer endpoint | `enable_private_endpoint = true` |
| no delete/replace of projects, KMS keys/key rings, buckets | one stray delete can't remove a tenant's boundary, data or keys; teardown override only |
| destroy threshold | a plan destroying more than 5 resources must be explicitly overridden |

### The teardown override

The two delete rules are waived only by external data, never by plan content, so a PR cannot
waive its own gate. The offboarding pipeline supplies a data file (`--data` takes a path, not
inline JSON) containing:

```json
{"exceptions": {"allow_destroy_over_threshold": true}}
```

```bash
conftest test plan.json --policy policies/ --data exceptions.json
```

The override does not waive any other rule.

## Usage

```bash
# In CI, against a real plan:
terraform show -json plan.tfplan > plan.json
conftest test plan.json --policy policies/

# Unit-test the policy logic (no plan / cloud needed):
conftest verify -p policies
```
