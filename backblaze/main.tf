terraform {
  cloud {
    organization = "asztalosgyula"
    workspaces {
      name = "homelab-backblaze"
    }
  }

  required_providers {
    b2 = {
      source  = "backblaze/b2"
      version = "~> 0.10.0"
    }
  }
}

resource "b2_bucket" "etcd_backup" {
  bucket_name = "${var.project_name}-etcd-backup-${var.environment}"
  bucket_type = "allPrivate"

  bucket_info = {
    purpose     = "Kubernetes etcd backups"
    environment = "production"
    managed_by  = "terraform"
  }

  default_server_side_encryption {
    algorithm = "AES256"
    mode      = "SSE-B2"
  }

  lifecycle_rules {
    days_from_hiding_to_deleting  = 1
    days_from_uploading_to_hiding = 30
    file_name_prefix              = ""
  }
}

resource "b2_application_key" "etcd_backup_key" {
  key_name  = "${var.project_name}-etcd-backup-key-${var.environment}"
  bucket_id = b2_bucket.etcd_backup.bucket_id
  capabilities = [
    "listBuckets",
    "listFiles",
    "readFiles",
    "writeFiles",
    "deleteFiles"
  ]

  name_prefix = ""
}

resource "b2_bucket" "cnpg_backup" {
  bucket_name = "${var.project_name}-cnpg-backup-${var.environment}"
  bucket_type = "allPrivate"

  bucket_info = {
    purpose     = "CNPG PostgreSQL backups"
    environment = "production"
    managed_by  = "terraform"
  }

  default_server_side_encryption {
    algorithm = "AES256"
    mode      = "SSE-B2"
  }

  lifecycle_rules {
    days_from_hiding_to_deleting  = 1
    days_from_uploading_to_hiding = 30
    file_name_prefix              = ""
  }
}

resource "b2_application_key" "cnpg_backup_key" {
  key_name  = "${var.project_name}-cnpg-backup-key-${var.environment}"
  bucket_id = b2_bucket.cnpg_backup.bucket_id
  capabilities = [
    "listBuckets",
    "listFiles",
    "readFiles",
    "shareFiles",
    "writeFiles",
    "deleteFiles"
  ]

  name_prefix = "cnpg-backup/"
}

resource "b2_bucket" "nas_backup" {
  bucket_name = "${var.project_name}-nas-backup-${var.environment}"
  bucket_type = "allPrivate"

  bucket_info = {
    purpose     = "NAS backups"
    environment = "production"
    managed_by  = "terraform"
  }

  default_server_side_encryption {
    algorithm = "AES256"
    mode      = "SSE-B2"
  }

  lifecycle_rules {
    days_from_hiding_to_deleting  = 1
    days_from_uploading_to_hiding = 5
    file_name_prefix              = ""
  }

  file_lock_configuration {
    is_file_lock_enabled = true
  }
}

resource "b2_application_key" "nas_backup_key" {
  key_name  = "${var.project_name}-nas-backup-key-${var.environment}"
  bucket_id = b2_bucket.nas_backup.bucket_id
  capabilities = [
    "listBuckets",
    "listFiles",
    "readFiles",
    "shareFiles",
    "writeFiles"
  ]

  name_prefix = "nas-backup/"
}

# Enable Object Lock manually on buckets for WORM in the B2 web interface!
