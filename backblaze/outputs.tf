output "bucket_name" {
  description = "Name of the created B2 bucket"
  value       = b2_bucket.cnpg_backup.bucket_name
}

output "bucket_id" {
  description = "ID of the created B2 bucket"
  value       = b2_bucket.cnpg_backup.bucket_id
}

output "application_key_id" {
  description = "Application Key ID for CNPG backups"
  value       = b2_application_key.cnpg_backup_key.application_key_id
}

output "application_key" {
  description = "Application Key for CNPG backups"
  value       = b2_application_key.cnpg_backup_key.application_key
  sensitive   = true
}

output "s3_endpoint" {
  description = "S3-compatible endpoint for Backblaze B2"
  value       = "https://s3.${var.b2_region}.backblazeb2.com"
}
