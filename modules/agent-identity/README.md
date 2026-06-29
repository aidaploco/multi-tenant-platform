# agent-identity

The **agent-unit** archetype (ADR-0002 D2-4): a workload's *runtime identity* and nothing else.
A service account distinct from the CI identities, an optional Workload Identity binding so a pod
in the shared runtime can act AS it (ADR-0001 D13), and least-privilege IAM. **No data
resources. No keys** — workloads authenticate via Workload Identity, never a downloaded key (D5).

> **Scope note:** in GCP the service account *is* the API client identity, so "agent/API client"
> from the archetype description maps to the SA + scoped IAM here. OAuth brands/clients
> (`google_iap_brand`) are out of scope for this archetype.

## Usage

```hcl
module "search_a" {
  source = "git::https://github.com/aidaploco/multi-tenant-platform.git//modules/agent-identity?ref=v0.2.0"

  project_id   = "abf-dev"          # the tenant's own project
  account_id   = "abf-search-a"
  display_name = "ABF Analytics search-a"

  iam_roles = ["roles/storage.objectViewer"] # least-privilege; primitive roles are rejected

  workload_identity = {             # optional — omit until the runtime cluster exists
    runtime_project_id = "runtime-dev"
    namespace          = "abf"
    ksa_name           = "search-a"
  }
}
```

## Inputs

| Name | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `project_id` | string | — | Tenant project where the SA lives. |
| `account_id` | string | — | SA id, 6-30 chars (`^[a-z][a-z0-9-]{4,28}[a-z0-9]$`). |
| `display_name` | string | — | Human-readable name. |
| `iam_roles` | list(string) | `[]` | Roles granted on `iam_project`. Primitive roles and SA-key roles are **rejected**. |
| `iam_project` | string | `null` | Project to grant roles on. Defaults to `project_id`. |
| `workload_identity` | object | `null` | `{ runtime_project_id, namespace, ksa_name }`; `null` = no binding yet. |

## Outputs

| Name | Description |
| ---- | ----------- |
| `email` | The service account email. |
| `member` | `serviceAccount:<email>` — for granting this SA access elsewhere. |
| `account_id` | Full resource name of the SA. |
| `workload_identity_member` | The bound Kubernetes SA, or `null`. |

## Guardrails

- **Variable validation** rejects primitive roles (`owner`/`editor`/`viewer`) and SA-key roles
  (`serviceAccountKeyAdmin`/`serviceAccountKeyCreator`).
- The **OPA gate** independently denies `roles/owner`/`roles/editor` and SA-key roles on any IAM
  member (platform-wide backstop). See `policies/terraform.rego`.

## Tests

```bash
terraform test   # mocked provider; no cloud, no cost
```
