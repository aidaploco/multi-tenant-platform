output "namespace" {
  description = "The created namespace name."
  value       = kubernetes_namespace.this.metadata[0].name
}

output "service_account_names" {
  description = "The Kubernetes SA names created (one per agent-unit)."
  value       = keys(var.service_accounts)
}
