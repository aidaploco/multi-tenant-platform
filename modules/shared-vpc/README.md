# shared-vpc

The private network for the **shared runtime plane** — one VPC per `runtime-<env>` project
(ADR-0008 / ADR-0001 D13). Private by default: Private Google Access, no external IPs, egress via
Cloud NAT only, default-deny ingress, admin access via Google IAP only, VPC-native secondary
ranges for GKE.

> **Layering:** this is the VPC perimeter + egress layer. Pod-level isolation *between tenants* is
> the Kubernetes default-deny `NetworkPolicy` (applied by Config Sync), not this module.
> No `labels` — VPC networks, subnets, and firewalls don't carry them.

## Usage

```hcl
module "runtime_vpc" {
  source = "git::https://github.com/aidaploco/multi-tenant-platform.git//modules/shared-vpc?ref=v0.4.0"

  project_id    = "runtime-dev"
  region        = "europe-west4"
  subnet_cidr   = "10.0.0.0/20"
  pods_cidr     = "10.4.0.0/14"
  services_cidr = "10.8.0.0/20"
}
```

## Inputs

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `project_id` | string | — | The `runtime-<env>` project. |
| `network_name` | string | `runtime-vpc` | VPC name. |
| `region` | string | — | Region for subnet/router/NAT. |
| `subnet_cidr` | string | — | Primary node range. |
| `pods_cidr` | string | — | Secondary range for pods. |
| `services_cidr` | string | — | Secondary range for services. |
| `iap_source_range` | string | `35.235.240.0/20` | Google IAP range (admin ingress). |

## Outputs

| Name | Description |
| ---- | ----------- |
| `network_id` / `network_name` | The VPC. |
| `subnetwork_id` / `subnetwork_name` | The subnet (attach the GKE cluster here). |
| `pods_range_name` / `services_range_name` | Secondary range names for VPC-native GKE. |

## Guardrails (OPA)

- No ingress **allow** rule may use source `0.0.0.0/0`.
- Every subnetwork must have `private_ip_google_access = true`.

## Tests

```bash
terraform test   # mocked provider; no cloud, no cost
```
