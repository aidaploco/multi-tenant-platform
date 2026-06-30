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

# The tenant's group gets edit rights ONLY in its namespace (RoleBinding, never ClusterRoleBinding).
resource "kubernetes_role_binding" "editors" {
  metadata {
    name      = "tenant-editors"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }
  subject {
    kind      = "Group"
    name      = var.owner_group
    api_group = "rbac.authorization.k8s.io"
  }
}
