# Terraform projects
## CI/CD
For github actions TF_API_TOKEN is populated by 1password.
You need to set OP_SERVICE_ACCOUNT_TOKEN secret in GitHub.
## Cloudflare
Creating DNS config in cloudflare
**Prerequisites:**
1. Cloudflare account -> get API token
  * zone.zone (read)
  * zone.'single redirect' (edit)
  * zone.'zone settings' (read)
  * zone.dns (edit)
2. Terraform Cloud account
3. homelab-cloudflare workspace in terraform
4. In the Terraform workspace create CLOUDFLARE_API_TOKEN environment variable (sensitive) with cloudflare API token in it

## Backblaze
Creating B2 bucket for CNPG backup
**Prerequisites:**
1. Backblaze account -> create new application key id and application key for Terraform cloud
2. Terraform Cloud account
3. homelab-backblaze workspace in Terraform
4. B2_APPLICATION_KEY and B2_APPLICATION_KEY_ID environment variables (sensitive) in the Terraform workspace
