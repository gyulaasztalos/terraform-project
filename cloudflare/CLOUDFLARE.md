# Cloudflare — extended setup & security guide

How the HomeLab uses Cloudflare: **tunnels** (no open inbound ports), DNS, edge
**redirects**, and the **security settings** that protect everything. This is the
"why + how it fits together" companion to:

- [`README.md`](README.md) — API-token prerequisites, Terraform Cloud, mTLS cert
  issuance, Backblaze.
- [`anitatortai-SETUP.md`](anitatortai-SETUP.md) — the step-by-step go-live
  runbook for the public pastry site.
- `main.tf` / `anitatortai.tf` — the actual Terraform (provider **v5**, Terraform
  Cloud workspace `homelab-cloudflare`).

---

## 1. Zones & what Terraform manages

| Zone | Purpose |
|------|---------|
| `asztalos.net` | Personal/HomeLab: DDNS apex, `*.local.asztalos.net` split-horizon names, `homeassistant` (mTLS tunnel), `github` redirect, iCloud mail |
| `anitatortai.hu` | Public pastry business site (cake-order), via the k3s tunnel |

**Managed in Terraform**: DNS records, dynamic-redirect rulesets, the Home
Assistant mTLS WAF ruleset + CA hostname association.

**NOT managed in Terraform** (deliberately — the API token has zone-settings
*read* only, and some things Terraform can't safely hold):
- **Zone security settings** (SSL/TLS mode, HSTS, TLS min version, Bot Fight
  Mode) → dashboard, one-time (see §4).
- **Tunnel creation + public-hostname → service mapping** → Zero Trust dashboard
  (see §3). The tunnel *token* lives in 1Password; `cloudflared` runs in-cluster
  (ArgoCD repo).
- **Client certificate issuance** for mTLS → by hand (README §"Client
  certificate").
- **iCloud mail records** (MX/SPF/DKIM/`apple-domain`/`_dmarc`) → left
  dashboard-managed and **DNS-only**; never proxy or shadow them.

## 2. The tunnel model (why there are no open ports)

Nothing is exposed by opening a port or pointing DNS at a home IP. Instead
`cloudflared` runs **inside the cluster** and dials **out** to Cloudflare; the
edge routes matching hostnames back down that outbound tunnel.

```
Browser ──HTTPS──▶ Cloudflare edge ──(tunnel, outbound-only)──▶ cloudflared (k3s)
                     TLS + WAF + HSTS                              │ HTTP
                                                                   ▼
                                                     ClusterIP Service → app pod
```

Consequences worth remembering:
- **No inbound firewall rule, no DDNS/A-record for the app**, no port 443 on the
  origin. The app serves plain **HTTP** in-cluster; **TLS is entirely
  Cloudflare's job** (Universal SSL at the edge; the tunnel leg is encrypted).
- A proxied (orange-cloud) DNS record is required for the hostname so WAF,
  redirects, and the tunnel apply. Apex uses **CNAME flattening**
  (`anitatortai.hu` CNAME → `<uuid>.cfargotunnel.com`).
- The **public Host header reaches the app**, which some apps rely on for
  defense (cake-order 404s `/metrics` for public hosts).

### Adding a public hostname (general recipe)
1. Zero Trust → Networks → Tunnels → *(tunnel)* → **Public Hostnames → Add**.
2. Subdomain/Domain = the hostname; **Service Type `HTTP`**; Service URL =
   `service.namespace.svc.cluster.local:port`.
3. Terraform owns the DNS record (proxied CNAME → `<uuid>.cfargotunnel.com`); if
   the flow says a record already exists, keep Terraform's.

### Path-restricting a hostname (security)
A tunnel public hostname can be scoped to specific **paths**. Use this when an
app must expose only part of itself publicly. Example: **Umami** — only
`/script.js` and `/api/send` should be public at `stats.anitatortai.hu`; the
dashboard/management API must **not** be reachable from the internet. Add the
public hostname with a path rule (or a WAF rule blocking every other path) so the
admin surface stays internal-only (see the ArgoCD `apps/umami/README.md`).

## 3. DNS conventions

- **Proxied (orange)** — anything served through the edge/tunnel or needing
  WAF/redirects: the app hostnames, redirect stubs.
- **DNS-only (grey)** — mail records, and `*.local.asztalos.net` /
  `local.asztalos.net` (internal names resolved on the LAN; not proxied).
- **Apex** is a CNAME (flattened) to the tunnel; `www` is a CNAME to the apex and
  is 301'd to it by an edge ruleset (so `www` never reaches the tunnel).
- **Mail**: MX `mx01/mx02.mail.icloud.com`, SPF `v=spf1 include:icloud.com ~all`,
  DKIM `sig1._domainkey` CNAME, `apple-domain=…` TXT, `_dmarc`. Keep grey, never
  proxy.

## 4. Zone security settings (dashboard, one-time per zone)

Set these under the zone's **SSL/TLS** and **Security** tabs (Terraform's token
can't edit them):

| Setting | Value | Why |
|---------|-------|-----|
| SSL/TLS mode | **Full (strict)** | Validate the origin cert end-to-end (the tunnel presents a valid one) |
| Always Use HTTPS | **On** | No plaintext edge requests |
| Minimum TLS Version | **1.2** | Drop legacy TLS |
| Automatic HTTPS Rewrites | **On** | Fix mixed-content links |
| HSTS | **Enable**, max-age 6 months, includeSubDomains **on**, preload **off** | Force HTTPS in browsers. Turn preload on only once every subdomain is HTTPS-only (it's hard to undo) |
| Security → Bots → **Bot Fight Mode** | **On** | Free-tier automated-bot mitigation |

**Security-header responsibility split** (don't duplicate blindly):
- **Edge adds HSTS** (above). The origin does not send HSTS.
- **The app sends its own CSP, `X-Content-Type-Options: nosniff`,
  `Referrer-Policy`, `Permissions-Policy`** (cake-order's middleware). Don't also
  set a conflicting CSP at the edge.
- **`/metrics`** is 404'd by the app on public hosts; an edge WAF rule blocking it
  is optional belt-and-suspenders.

Optional hardening: a **WAF custom rule** or **Rate Limiting rule** on the form
endpoint (`/ajanlatkeres`) — the app already rate-limits per IP/e-mail, so this is
defense-in-depth. Cloudflare Turnstile is wired in the app but disabled until spam
demands it.

## 5. Edge redirects (Terraform-managed)

Dynamic-redirect rulesets live in `http_request_dynamic_redirect` (one ruleset
per zone/phase):
- `www.anitatortai.hu → anitatortai.hu` (301, preserve path+query) — `anitatortai.tf`.
- `github.asztalos.net → github.com/gyulaasztalos` — `main.tf`.

## 6. mTLS (Home Assistant) — WAF + client certs

`homeassistant.asztalos.net` requires a **verified client certificate**. Two parts:
- **WAF ruleset** `homeassistant_mtls` (`http_request_firewall_custom`,
  `main.tf`): a **skip** rule for verified certs evaluated **before** a **block**
  rule for everyone else. **Order matters** and is controlled by the list order in
  Terraform, not dashboard drag-and-drop.
- **CA hostname association** binds the hostname to the zone's Cloudflare Managed
  CA (a per-zone singleton).
- **Cert issuance is manual** — Cloudflare won't return a private key it
  generated; see [`README.md`](README.md) for the create/convert/install steps.
  Revoking/expiring a cert locks you out until a new one is issued and installed
  on every device.

## 7. Secrets & CI

- Terraform runs in **Terraform Cloud** (`homelab-cloudflare` workspace); the
  Cloudflare API token is the workspace env var `CLOUDFLARE_API_TOKEN`
  (sensitive). GitHub Actions gets `TF_API_TOKEN` from 1Password via
  `OP_SERVICE_ACCOUNT_TOKEN`.
- **API token scopes** (README): Zone **read**, DNS **edit**, Single Redirect
  **edit**, Zone Settings **read**, WAF **edit**, SSL & Certificates **edit**.
  Zone Settings is read-only → security settings are dashboard-managed (§4).
  When adding a **new zone**, confirm the token can edit it (all-zones or add the
  zone) or `apply` will 403.
- The **tunnel token** lives in 1Password (`kubernetes` vault → `cake-order-app`
  → `cloudflare_tunnel_token`); ESO injects it so `cloudflared` can authenticate.

## 8. Adopting existing records (import blocks)

When Cloudflare already created a record (e.g. the tunnel's "add public hostname"
flow made the apex CNAME), a plain `apply` errors on the duplicate (**81053**).
Use an `import {}` block with the record id to adopt it, `apply`, then delete the
block:

```bash
curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/dns_records?type=CNAME&name=<name>" \
  | jq -r '.result[0].id'
```

See the `import {}` block in `anitatortai.tf` for the worked example. Prefer this
over `lifecycle { ignore_changes }` so the config still reproduces on a fresh
account.

## 9. Runbooks

- **Bring up a new public site** → follow [`anitatortai-SETUP.md`](anitatortai-SETUP.md):
  create tunnel → store token in 1Password → fill Terraform locals → remove old
  apex A/AAAA → `apply` → map the tunnel public hostname → set zone security
  (§4) → deploy → smoke test.
- **Expose only part of an app** (e.g. Umami tracker) → §2 "path-restricting".
