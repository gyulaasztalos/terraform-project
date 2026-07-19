# Terraform projects
## CI/CD
For github actions TF_API_TOKEN is populated by 1password.
You need to set OP_SERVICE_ACCOUNT_TOKEN secret in GitHub.
## Cloudflare

> **Extended guide:** see [`CLOUDFLARE.md`](CLOUDFLARE.md) for the tunnel model,
> DNS conventions, zone security settings, mTLS, redirects, and how it all fits
> together. Go-live runbook for the public site: [`anitatortai-SETUP.md`](anitatortai-SETUP.md).

Creating DNS config in cloudflare
**Prerequisites:**
1. Cloudflare account -> get API token
  * zone.zone (read)
  * zone.'single redirect' (edit)
  * zone.'zone settings' (read)
  * zone.dns (edit)
  * zone.'waf' (edit) -- required for the WAF custom rules ruleset (mTLS enforcement)
  * zone.'ssl and certificates' (edit) -- required for the mTLS hostname association
2. Terraform Cloud account
3. homelab-cloudflare workspace in terraform
4. In the Terraform workspace create CLOUDFLARE_API_TOKEN environment variable (sensitive) with cloudflare API token in it

### Client certificate (mTLS) for Home Assistant -- manual step

The WAF rules (`cloudflare_ruleset.homeassistant_mtls`) and hostname
association (`cloudflare_certificate_authorities_hostname_associations`)
that enforce mTLS on `homeassistant.asztalos.net` are Terraform-managed.

Issuing the client certificate itself is **not** -- Cloudflare's Terraform
provider only accepts a CSR you already generated, it won't hand back a
private key it created for you, and short of a change of approach (e.g.
generating the keypair via the `tls` provider and pushing it to 1Password,
like the Backblaze workflow does) there's nowhere safe for Terraform to
put it. So certs are created and installed by hand:

1. Cloudflare dashboard -> `asztalos.net` -> **SSL/TLS -> Client
   Certificates -> Create Certificate**.
2. Let Cloudflare generate the private key and CSR. Set a validity period
   you're comfortable with (long-lived is fine for personal devices, just
   remember it has no automatic rotation).
3. Download the certificate and private key as `.pem` files.
4. Convert to PKCS#12 for installing on devices:
   ```bash
   openssl pkcs12 -export -out homeassistant-client.p12 \
     -inkey homeassistant-client.key.pem \
     -in homeassistant-client.cert.pem
   ```
5. Install the `.p12` on each client device:
   - **Android**: Settings -> Security -> "User certificates" -> "Install
     from device storage" -> select "VPN and app user certificate".
   - **Windows/macOS browsers**: import via the OS/browser certificate
     manager (Keychain Access on macOS, `certmgr.msc` on Windows).
   - **iOS**: the Home Assistant Companion app supports mTLS certificates
     directly -- see the [iOS mTLS docs](https://github.com/home-assistant/iOS/blob/main/docs/mTLS.md).
6. Delete the local `.pem`/`.p12` files once installed -- don't commit
   them to this repo.
7. Repeat per device. Losing a device or rotating the cert means
   reinstalling on every remaining device.

If you ever revoke or let a certificate expire, the WAF block rule still
applies -- you'll be locked out of `homeassistant.asztalos.net` until a
new certificate is issued and installed.

## Backblaze
Creating B2 bucket for CNPG backup
**Prerequisites:**
1. Backblaze account -> create new application key id and application key for Terraform cloud
2. Terraform Cloud account
3. homelab-backblaze workspace in Terraform
4. B2_APPLICATION_KEY and B2_APPLICATION_KEY_ID environment variables (sensitive) in the Terraform workspace
