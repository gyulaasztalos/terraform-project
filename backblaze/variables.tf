variable "b2_region" {
  description = "Backblaze B2 bucket region"
  type        = string
  default     = "eu-central-003"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project identifier"
  type        = string
  default     = "homelab"
}
