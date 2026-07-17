# tenant-namespace: stamps one tenant's namespace on the shared runtime cluster with the full
# isolation contract (ADR-0013, mirroring gitops/namespaces/tenant-template). This is the Terraform
# half of "the cluster is multi-tenant safe": default-deny networking, quotas, namespace RBAC, and
# the Kubernetes SA that completes each agent-unit's Workload Identity bridge.

locals {
  labels = merge(var.labels, { "managed-by" = "terraform" })
}

resource "kubernetes_namespace" "this" {
  metadata {
    name   = var.namespace
    labels = local.labels
    # The tenant's allowed unit KSAs, readable by the exact-KSA Gatekeeper constraint via
    # referential data (ADR-0018). Tamper-proof from tenants: the namespaced `edit` role cannot
    # update the Namespace object itself. Empty (no units) = the constraint admits no pods.
    annotations = {
      "unit-ksas" = join(",", sort(keys(var.service_accounts)))
    }
  }
}

# No pod in any other tenant's namespace can reach this one.
resource "kubernetes_network_policy" "default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

# A tenant's own pods can talk to each other.
resource "kubernetes_network_policy" "allow_same_namespace" {
  metadata {
    name      = "allow-same-namespace"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    ingress {
      from {
        pod_selector {}
      }
    }
  }
}

# Egress: default-deny + an explicit allow-list (ADR-0022 D22-4 in platform-config). The two
# ingress policies above stop other tenants reaching IN; neither touches egress, so — checked
# directly, not assumed — every pod here could reach OUT anywhere, including other tenants'
# pods, this cluster's own control plane, and (on real GKE) the metadata server. This closes
# that gap with the same default-deny shape as ingress.
resource "kubernetes_network_policy" "default_deny_egress" {
  metadata {
    name      = "default-deny-egress"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]

    # DNS — without this nothing else resolves, including every rule below.
    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
        pod_selector {
          match_labels = { "k8s-app" = "kube-dns" }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }

    # A tenant's own pods can talk to each other (egress-side mirror of allow-same-namespace).
    egress {
      to {
        pod_selector {}
      }
    }

    # Shared platform-system control-plane services (Temporal today; anything else the
    # platform team runs there later, e.g. an OTel collector) are trusted infrastructure, not
    # tenant-boundary-relevant — namespace-level trust, consistent with how this module reasons
    # about isolation everywhere else. On real GKE with Temporal Cloud this rule is a no-op
    # (nothing in platform-system to reach); Temporal Cloud's own reachability at activation is
    # covered by the external-internet rule below and is unverified until a real cluster exists
    # (same honesty as every other real-cluster gap in docs/VERIFICATION.md).
    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "platform-system" }
        }
      }
    }

    # The internet, minus this cluster's own private address space. Standard Kubernetes
    # NetworkPolicy can't match by hostname (no FQDN allow-listing without a CNI extension like
    # Cilium), so "only api.openai.com" isn't expressible here — this is the practical
    # compromise: let workloads reach external APIs, block the SSRF-shaped targets that
    # actually matter. Verified directly against this cluster: both the pod CIDR (10.244.0.0/16)
    # and service CIDR (10.96.0.0/16) fall inside 10.0.0.0/8, so this genuinely blocks reaching
    # another tenant's pod/Service by IP, not just looks like it does.
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
          except = [
            "10.0.0.0/8",
            "172.16.0.0/12",
            "192.168.0.0/16",
            "169.254.0.0/16", # link-local + the cloud metadata service (169.254.169.254)
          ]
        }
      }
    }

    # Narrow, explicit, documented exceptions beyond the baseline above — e.g. a local-dev
    # dependency that lives outside the cluster entirely (ADR-0022). Empty by default; never
    # populated in real/GKE mode.
    dynamic "egress" {
      for_each = var.extra_egress_cidrs
      content {
        to {
          ip_block {
            cidr = egress.value.cidr
          }
        }
        ports {
          port     = egress.value.port
          protocol = egress.value.protocol
        }
      }
    }
  }
}

# A noisy tenant can't starve the shared cluster.
resource "kubernetes_resource_quota" "this" {
  metadata {
    name      = "tenant-quota"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = var.quota.requests_cpu
      "requests.memory" = var.quota.requests_memory
      "limits.cpu"      = var.quota.limits_cpu
      "limits.memory"   = var.quota.limits_memory
      "pods"            = var.quota.pods
    }
  }
}

resource "kubernetes_limit_range" "this" {
  metadata {
    name      = "tenant-limits"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    limit {
      type            = "Container"
      default         = { cpu = "500m", memory = "512Mi" }
      default_request = { cpu = "100m", memory = "128Mi" }
    }
  }
}

# One Kubernetes SA per agent-unit, annotated to impersonate that unit's GCP SA. The GCP half
# (workloadIdentityUser binding GSA <- this KSA) is created by the agent-unit (ADR-0002).
resource "kubernetes_service_account" "workload" {
  for_each = var.service_accounts

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.this.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = each.value
    }
  }
}

# Tenant humans get READ (built-in `view`) plus the narrow operate role below — NOT `edit`
# (ADR-0023 in platform-config). `edit` includes create/update/delete on NetworkPolicies, and
# NetworkPolicies are additive-permissive: one tenant-created allow-all egress policy — or a
# plain delete of default-deny-egress — would quietly defeat the baseline above. RBAC is the
# PRIMARY layer here because it is the only one that covers DELETE: Gatekeeper's webhook only
# intercepts CREATE/UPDATE (checked against the live webhook config, not assumed). The
# admission backstop for other write paths is the deny-tenant-netpol constraint in
# platform-config gitops/.
resource "kubernetes_role_binding" "viewers" {
  metadata {
    name      = "tenant-viewers"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "Group"
    name      = var.owner_group
    api_group = "rbac.authorization.k8s.io"
  }
}

# What tenants may WRITE, shaped by the delivery contract instead of a k8s built-in: workloads
# arrive via GitOps (ADR-0017), never kubectl — the only hand-managed objects are the
# pre-created app Secrets (ADR-0020 `secret_ref`), plus the debugging surfaces (logs, exec,
# port-forward). `view` deliberately excludes Secrets; this role adds them back, scoped to this
# namespace only. A legitimate new tenant need extends THIS rule list (a reviewable diff) —
# never a fallback to `edit`.
resource "kubernetes_role" "operators" {
  metadata {
    name      = "tenant-operators"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec", "pods/portforward"]
    verbs      = ["get", "create"]
  }
}

resource "kubernetes_role_binding" "operators" {
  metadata {
    name      = "tenant-operators"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.operators.metadata[0].name
  }
  subject {
    kind      = "Group"
    name      = var.owner_group
    api_group = "rbac.authorization.k8s.io"
  }
}
