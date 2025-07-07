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
    "listFiles",
    "readFiles",
    "shareFiles",
    "writeFiles",
    "deleteFiles"
  ]

  name_prefix = "cnpg-backup/"
}
