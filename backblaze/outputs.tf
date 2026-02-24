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

output "nas_bucket_name" {
  description = "Name of the created B2 bucket"
  value       = b2_bucket.nas_backup.bucket_name
}

output "nas_bucket_id" {
  description = "ID of the created B2 bucket"
  value       = b2_bucket.nas_backup.bucket_id
}

output "nas_application_key_id" {
  description = "Application Key ID for NAS backups"
  value       = b2_application_key.nas_backup_key.application_key_id
}

output "nas_application_key" {
  description = "Application Key for NAS backups"
  value       = b2_application_key.nas_backup_key.application_key
  sensitive   = true
}

output "etcd_bucket_name" {
  description = "Name of the created B2 bucket"
  value       = b2_bucket.etcd_backup.bucket_name
}

output "etcd_bucket_id" {
  description = "ID of the created B2 bucket"
  value       = b2_bucket.etcd_backup.bucket_id
}

output "etcd_application_key_id" {
  description = "Application Key ID for etcd backups"
  value       = b2_application_key.etcd_backup_key.application_key_id
}

output "etcd_application_key" {
  description = "Application Key for etcd backups"
  value       = b2_application_key.etcd_backup_key.application_key
  sensitive   = true
}

output "s3_endpoint" {
  description = "S3-compatible endpoint for Backblaze B2"
  value       = "https://s3.${var.b2_region}.backblazeb2.com"
}
