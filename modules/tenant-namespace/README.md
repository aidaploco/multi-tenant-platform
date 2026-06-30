# tenant-namespace

Stamps one tenant's namespace on the shared runtime cluster with the full isolation contract
(ADR-0013) — the Terraform half of "the cluster is multi-tenant safe". Mirrors
`gitops/namespaces/tenant-template` in `platform-config`.

> **Kubernetes provider module** — the consuming root configures the `kubernetes` provider (via
> Fleet Connect Gateway, ADR-0013 D13-2). Mocked tests verify wiring; a live namespace needs a real
> Fleet-registered cluster.

## What it creates

- the **Namespace**,
- `default-deny-ingress` + `allow-same-namespace` **NetworkPolicies**,
- a **ResourceQuota** + **LimitRange**,
- one **Kubernetes SA per agent-unit**, annotated `iam.gke.io/gcp-service-account` to impersonate
  that unit's GCP SA (completes the Workload Identity bridge),
- a namespace-scoped **RoleBinding** (the tenant's group → `edit`).

## Usage

```hcl
module "namespace" {
  source = "git::https://github.com/aidaploco/multi-tenant-platform.git//modules/tenant-namespace?ref=v0.8.0"

  namespace   = "abf"
  owner_group = "abf-data-engineers@company.com"
  service_accounts = {
    "search-a" = "abf-search-a@abf-dev.iam.gserviceaccount.com"
  }
  labels = local.labels
}
```

## Inputs

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `namespace` | string | — | The tenant slug. |
| `owner_group` | string | — | Group granted `edit` in this namespace only. |
| `service_accounts` | map(string) | `{}` | KSA name → GCP SA email (per agent-unit). |
| `quota` | object | sensible | ResourceQuota hard limits. |
| `labels` | map | — | Must include tenant/environment/data_classification. |

## Outputs

`namespace`, `service_account_names`.

## Tests

```bash
terraform test   # mocked kubernetes provider — wiring only
```
