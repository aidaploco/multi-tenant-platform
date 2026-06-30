# cloud-composer

The shared managed-Airflow orchestration plane (ADR-0010 / ADR-0001 D13): one **private** Composer
environment per `runtime-<env>`, on the shared VPC, running as its own least-privilege service
account.

> **Least-verified module in the library.** Composer environments are large and their networking
> config is highly apply-sensitive — the mocked tests confirm *wiring* (private endpoint, VPC, own
> SA), not that an environment actually builds. Expect to tune `image_version` and the CIDR blocks
> on the first real apply.
>
> **Layering:** per-tenant DAG folders, Airflow RBAC, and `KubernetesPodOperator`-as-the-tenant's-
> WI-SA (so a task touches only its tenant's data) are operational config on top — not created here.

## Usage

```hcl
module "composer" {
  source = "git::https://github.com/aidaploco/multi-tenant-platform.git//modules/cloud-composer?ref=v0.6.0"

  project_id            = "runtime-dev"
  region                = "europe-west4"
  network               = module.vpc.network_id
  subnetwork            = module.vpc.subnetwork_id
  image_version         = "composer-2.9.7-airflow-2.9.3" # CHECK current versions at apply
  master_ipv4_cidr      = "172.16.1.0/28"
  composer_network_cidr = "10.1.0.0/24"
  web_server_cidr       = "172.16.1.16/28"
  labels                = local.labels
}
```

## Inputs (key)

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `project_id` | string | — | Runtime project. |
| `network` / `subnetwork` | string | — | From `shared-vpc`. |
| `image_version` | string | `composer-2.9.7-airflow-2.9.3` | **Verify against current versions at apply.** |
| `environment_size` | string | `ENVIRONMENT_SIZE_SMALL` | |
| `master_ipv4_cidr` / `composer_network_cidr` / `web_server_cidr` | string | — | Disjoint private ranges. |
| `labels` | map | — | Must include tenant/environment/data_classification. |

## Outputs

`name`, `service_account_email`, `airflow_uri`, `dag_gcs_prefix`.

## Guardrails (OPA)

- Composer environments must enable a **private endpoint**.

## Tests

```bash
terraform test   # mocked provider — wiring only, not a live environment
```
