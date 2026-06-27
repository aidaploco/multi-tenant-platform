output "keyring_id" {
  description = "Full resource ID of the tenant's key ring."
  value       = google_kms_key_ring.this.id
}

output "key_ids" {
  description = "Map of logical key name -> full crypto-key ID. Pass the relevant entry as cmek_key_id to data modules (e.g. key_ids[\"gcs\"])."
  value       = { for k, v in google_kms_crypto_key.this : k => v.id }
}
