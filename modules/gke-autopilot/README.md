# gke-autopilot

The shared runtime cluster (ADR-0009 / ADR-0001 D13): one regional **Autopilot** cluster per
`runtime-<env>` project. Google manages the nodes and their security defaults — minimal ops for a
small team. Private nodes (egress via the shared-vpc NAT), control-plane locked to authorized
networks, Workload Identity on.

> **Layering:** this is the cluster. Per-tenant namespaces with default-deny `NetworkPolicy`,
> quotas, and Policy Controller constraints are applied by **Config Sync** (milestone part 4), not
> here. Do not run two tenants' workloads here until part 4.

## Usage

```hcl
module "cluster" {
  source = "git::https://github.com/aidaploco/multi-tenant-platform.git//modules/gke-autopilot?ref=v0.5.0"

  project_id          = "runtime-dev"
  region              = "europe-west4"
  network             = module.vpc.network_id
  subnetwork          = module.vpc.subnetwork_id
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name
  master_ipv4_cidr    = "172.16.0.0/28"
  deletion_protection = true
  labels              = local.labels
}
```

## Inputs (key)

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `project_id` | string | — | Runtime project. |
| `network` / `subnetwork` | string | — | From `shared-vpc`. |
| `pods_range_name` / `services_range_name` | string | — | Secondary ranges (VPC-native). |
| `master_ipv4_cidr` | string | — | `/28` for the private control plane. |
| `master_authorized_networks` | list(obj) | `[]` | CIDRs allowed to reach the control plane (`[]` = none; admin via IAP). |
| `release_channel` | string | `REGULAR` | `RAPID`\|`REGULAR`\|`STABLE`. |
| `database_encryption_key` | string | — (required) | Platform CMEK for Secrets-in-etcd (ADR-0025). Caller grants the GKE service agent on it. |
| `boot_disk_kms_key` | string | — (required) | Platform CMEK for node boot disks via Autopilot provisioning defaults (ADR-0025). Caller grants the Compute service agent on it. |
| `deletion_protection` | bool | `true` | |
| `labels` | map | — | Must include tenant/environment/data_classification. |

## Outputs

`name`, `id`, `endpoint` (sensitive), `workload_pool`, `enable_autopilot`.

## Guardrails (OPA)

- GKE clusters must enable **private nodes** (no public node IPs).

## Tests

```bash
terraform test   # mocked provider — verifies wiring, not a live cluster
```
