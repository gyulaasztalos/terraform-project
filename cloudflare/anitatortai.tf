# ---------------------------------------------------------------------------
# anitatortai.hu — public site for the family pastry business, served from the
# HomeLab k3s cluster through a Cloudflare Tunnel (cloudflared runs in the
# cake-order namespace; see the ArgoCD repo). DNS + edge redirect are managed
# here; the tunnel itself and its ingress mapping are created in Zero Trust
# (see the step-by-step guide in this file's trailing comment).
#
# NOT managed here on purpose: the iCloud custom-domain MAIL records (MX, SPF,
# DKIM CNAME, apple-domain TXT). Cloudflare imported them when it took over the
# zone; leave them dashboard-managed and DNS-only (grey cloud) so mail keeps
# working. Do not add proxied records that shadow them.
# ---------------------------------------------------------------------------

locals {
  # Cloudflare → anitatortai.hu → Overview → API → Zone ID.
  anitatortai_zone_id = "94bb9c1d6ecc4db3dc899f9564def962"

  # The tunnel's routable hostname: "<TUNNEL-UUID>.cfargotunnel.com".
  # Get the UUID from Zero Trust → Networks → Tunnels → (your tunnel) → the
  # connector ID, or `cloudflared tunnel list`.
  anitatortai_tunnel_hostname = "224d999c-f4f7-4b6c-84b8-f196ae5093b8.cfargotunnel.com"
}

# --- Web: apex + www → the tunnel (proxied / orange cloud) ------------------

# Apex uses Cloudflare CNAME flattening (a CNAME at the zone root is allowed and
# resolved to A/AAAA at the edge). Proxied so the tunnel and WAF/redirects apply.
resource "cloudflare_dns_record" "anitatortai_apex" {
  zone_id = local.anitatortai_zone_id
  name    = "anitatortai.hu"
  type    = "CNAME"
  content = local.anitatortai_tunnel_hostname
  proxied = true
  ttl     = 1 # 1 = automatic (required for proxied records)

  lifecycle {
    ignore_changes = [content]
  }
}

# www is an alias of the apex; the redirect ruleset below 301s it to the apex at
# the edge (so it never reaches the tunnel). Proxied so the ruleset can run.
resource "cloudflare_dns_record" "anitatortai_www" {
  zone_id = local.anitatortai_zone_id
  name    = "www.anitatortai.hu"
  type    = "CNAME"
  content = "anitatortai.hu"
  proxied = true
  ttl     = 1
}

# --- Edge redirect: www → apex (canonical host) ----------------------------
# Same pattern as the github.asztalos.net redirect in main.tf. anitatortai.hu is
# a separate zone, so it gets its own dynamic-redirect ruleset (one per phase
# per zone).
resource "cloudflare_ruleset" "anitatortai_www_to_apex" {
  zone_id = local.anitatortai_zone_id
  name    = "www.anitatortai.hu → apex redirect"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules = [
    {
      enabled     = true
      description = "Redirect www.anitatortai.hu to the apex, preserving path + query"
      action      = "redirect"

      action_parameters = {
        from_value = {
          status_code           = 301
          preserve_query_string = true

          target_url = {
            expression = "concat(\"https://anitatortai.hu\", http.request.uri.path)"
          }
        }
      }

      expression = "http.host == \"www.anitatortai.hu\""
    }
  ]
}
