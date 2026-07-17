# gke-autopilot: the shared runtime cluster (ADR-0009 / ADR-0001 D13).
#
# Autopilot (Google manages nodes + security defaults — minimal ops for a small team). Private
# nodes (no public node IPs; egress via the shared-vpc NAT). Control-plane endpoint locked by
# master_authorized_networks (default none). Workload Identity on — this is the pool the tenant
# agent-unit SAs bind to. Pod-level tenant isolation (default-deny NetworkPolicy) is applied by
# Config Sync in milestone part 4, not here.

locals {
  labels = merge(var.labels, { "managed-by" = "terraform" })
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region

  enable_autopilot = true

  network    = var.network
  subnetwork = var.subnetwork

  # VPC-native, using the shared-vpc secondary ranges.
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private nodes; the control plane stays reachable only from authorized networks.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  release_channel {
    channel = var.release_channel
  }

  # The Workload Identity pool tenant agent-unit SAs bind to (`<project>.svc.id.goog`).
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Substrate CMEK (ADR-0025 D25-1): PLATFORM keys for platform substrate — per-tenant CMEK is
  # physically impossible on shared disks (one node hosts many tenants' pods); tenant-data CMEK
  # stays per-tenant in tenant projects. Both variables are REQUIRED: a cluster without
  # substrate CMEK must be a visible fork of this module, never a forgotten argument.
  #
  # Application-layer encryption of Kubernetes Secrets in etcd.
  database_encryption {
    state    = "ENCRYPTED"
    key_name = var.database_encryption_key
  }

  # Node boot-disk CMEK. On Autopilot the node config is Google-managed, so the key rides the
  # auto-provisioning defaults. The GKE + Compute service agents need
  # roles/cloudkms.cryptoKeyEncrypterDecrypter on the respective keys — granted by the CALLER
  # (the runtime root), next to the keys; grant-vs-first-cluster ordering is register-tracked.
  cluster_autoscaling {
    auto_provisioning_defaults {
      boot_disk_kms_key = var.boot_disk_kms_key
    }
  }

  resource_labels     = local.labels
  deletion_protection = var.deletion_protection
}
