# config-sync

Installs **Config Sync** on the shared runtime cluster via Fleet (`gke_hub`), pointed at the
`platform-config` repo's `gitops/` directory (ADR-0012). The GitOps reconciliation loop that keeps
the cluster's tenant-isolation policy applied and self-healing.

> **Reviewed, not live-verified.** Fleet/Config Sync need a real cluster to exercise; the mocked
> tests confirm wiring (reconciles `gitops/`, provisions the git secret).
>
> **Out of scope (operational / data-driven elsewhere):** the in-cluster `git-creds` secret (needs
> cluster access) and the per-tenant namespaces (the Terraform tenant composition creates those).

## Usage

```hcl
module "config_sync" {
  source = "git::https://github.com/aidaploco/multi-tenant-platform.git//modules/config-sync?ref=v0.7.0"

  project_id   = "runtime-dev"
  region       = "europe-west4"
  cluster_name = module.cluster.name
  cluster_id   = module.cluster.id
  sync_repo    = "https://github.com/aidaploco/multi-tenant-config"
  secret_type  = "token" # or "gcpserviceaccount" for keyless (OCI hardening, ADR-0012 D12-4)
  labels       = local.labels
}
```

## Inputs (key)

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `project_id` / `region` | string | — | Runtime project + cluster region. |
| `cluster_name` / `cluster_id` | string | — | From `gke-autopilot`. |
| `sync_repo` | string | — | Git repo Config Sync reads. |
| `sync_branch` / `policy_dir` | string | `main` / `gitops` | What to reconcile. |
| `secret_type` | string | `token` | `none` \| `token` \| `gcpserviceaccount`. |
| `rotation_days` | number | `90` | Recorded on the git-token secret (ADR-0006). |
| `labels` | map | — | Must include tenant/environment/data_classification. |

## Outputs

`membership_id`, `policy_dir`, `git_token_secret_id`.

## Tests

```bash
terraform test   # mocked provider — wiring only
```
