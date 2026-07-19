# anitatortai.hu — go-live runbook

Bringing the public site up on the apex (`anitatortai.hu` + `www`) via the
Cloudflare Tunnel that runs in the k3s cluster (`cloudflared` in the
`cake-order` namespace, ArgoCD repo). DNS + the www→apex redirect are in
`anitatortai.tf`; everything below is the manual glue Terraform can't do.

Do the steps in this order — several have ordering constraints (noted).

## 0. Prerequisites
- The `anitatortai.hu` zone is already active in Cloudflare (done).
- The Terraform Cloud workspace `homelab-cloudflare` already has a Cloudflare
  API token. **Verify that token can edit the `anitatortai.hu` zone** (not only
  `asztalos.net`). If it's zone-scoped, broaden it to *All zones* or add the new
  zone, or `terraform apply` will 403 on the new records.

## 1. Create the tunnel + get its UUID and token
Zero Trust → Networks → Tunnels → **Create a tunnel** → *Cloudflared* → name it
`cake-order`.
- Copy the **tunnel token** (the long `eyJ…` string).
- Copy the **tunnel UUID** (shown on the tunnel's page / `cloudflared tunnel list`).

## 2. Store the tunnel token
1Password → vault `kubernetes` → item **`cake-order-app`** → add field
**`cloudflare_tunnel_token`** = the token from step 1. (ArgoCD's
`cake-order-tunnel-secret` ExternalSecret already references this field.)

## 3. Fill in the Terraform locals
In `anitatortai.tf`:
- `anitatortai_zone_id` = Cloudflare → `anitatortai.hu` → Overview → API → **Zone ID**.
- `anitatortai_tunnel_hostname` = `<TUNNEL-UUID>.cfargotunnel.com` (from step 1).

## 4. Remove the old rackhost records (BEFORE `terraform apply`)
A CNAME cannot coexist with an A/AAAA at the apex, so the rackhost redirect
records must go first. In the `anitatortai.hu` DNS tab, **delete**:
- the apex **A** (and any **AAAA**) record pointing at the rackhost redirect IP,
- any **`www` A/AAAA/CNAME** left over from rackhost.
(These were imported with the zone and are not Terraform-managed, so delete them
in the dashboard.) **Do NOT delete** the mail records — see step 6.

## 5. Apply the Terraform
From `cloudflare/`: `terraform plan` then `terraform apply` (a remote run in the
`homelab-cloudflare` workspace). This creates:
- proxied CNAME `anitatortai.hu` → `<uuid>.cfargotunnel.com`
- proxied CNAME `www.anitatortai.hu` → `anitatortai.hu`
- the `www → apex` 301 redirect ruleset.

## 6. Point the tunnel at the app + verify mail
- In the tunnel's **Public Hostnames**, add one entry:
  - **Subdomain:** _(leave empty — this is the apex)_
  - **Domain:** `anitatortai.hu`
  - **Service Type:** `HTTP`  ← not HTTPS
  - **Service URL:** `cake-order.cake-order.svc.cluster.local:80`

  When it says a matching DNS record already exists (Terraform's), keep it. You
  do **not** need a www public hostname — the edge redirect handles www before
  it reaches the tunnel.

  **TLS is entirely Cloudflare's job.** Browser→edge is HTTPS with Cloudflare's
  auto Universal SSL cert (covers apex + www); edge→cloudflared is encrypted by
  the tunnel; cloudflared→app is the `HTTP` leg above — plaintext but in-cluster
  and locked down by the NetworkPolicy. The app serves plain HTTP on :8000 and
  needs **no cert and no port 443**.
- Confirm the iCloud **mail** records are present and **DNS-only (grey cloud)**:
  `MX` mx01/mx02.mail.icloud.com, `TXT` SPF `v=spf1 include:icloud.com ~all`,
  `CNAME` `sig1._domainkey`, the `apple-domain=…` TXT, and (if present) `_dmarc`.
  Leave these dashboard-managed; never proxy them.

## 7. Zone security settings (best practice, one-time)
`anitatortai.hu` → SSL/TLS and Security:
- **SSL/TLS mode: Full (strict)** — the tunnel origin presents a valid cert.
- **Always Use HTTPS: On**
- **Minimum TLS Version: 1.2**
- **Automatic HTTPS Rewrites: On**
- **HSTS: Enable** — max-age 6 months, includeSubDomains on, preload off (turn
  preload on only once you're confident every subdomain is HTTPS-only).
- **Security → Bots → Bot Fight Mode: On** (free tier).
- Optional defense-in-depth: a WAF custom rule blocking `/metrics` at the edge
  (the app already 404s it on the public Host, so this is belt-and-suspenders).

## 8. Deploy the app + release
- App config is already set for the apex (`BASE_URL=https://anitatortai.hu`,
  `PUBLIC_HOSTS=anitatortai.hu,www.anitatortai.hu` in the ArgoCD deployment).
- Push the app repos, review & push the ArgoCD repo, then cut the release tags
  (`v1.0.0` cake-order, `v1.4.0` cake-pricing). CI builds the images, Renovate
  bumps the ArgoCD tags, ArgoCD deploys, and `cloudflared` dials out — the site
  is live with no inbound ports open.

## 9. Smoke test
- `https://anitatortai.hu` loads the order form; `https://www.anitatortai.hu`
  301s to the apex.
- Submit a test order → verification e-mail arrives (iCloud SMTP) → clicking the
  link delivers the order to info@anitatortai.hu.
- `https://anitatortai.hu/metrics` returns 404 (Host-gated); Prometheus still
  scrapes it in-cluster.
- Send a mail to info@anitatortai.hu to confirm delivery is unaffected.

---
_Note: the existing `homeassistant` CNAME in `main.tf` uses `ignore_changes =
[content]` with a stale `asztalos.net` placeholder — it relies on a manual
dashboard fix and wouldn't reproduce on a fresh account. `anitatortai.tf`
deliberately pins the real `cfargotunnel.com` target instead, so the plan is
complete. Consider converting the homeassistant record to the same style._
