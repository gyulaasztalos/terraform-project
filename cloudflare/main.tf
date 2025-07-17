# Configure the Cloudflare provider using the required_providers stanza
# required with Terraform 0.13 and beyond. You may optionally use version
# directive to prevent breaking changes occurring unannounced.

terraform {
  cloud {
    organization = "asztalosgyula"

    workspaces {
      name = "homelab-cloudflare"
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

resource "cloudflare_record" "terraform_managed_resource_8663194f1dcc57cdec36fed108dd2f25" {
  name    = "asztalos.net"
  proxied = false
  ttl     = 600
  type    = "A"
  content = "84.1.62.209"
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"

  lifecycle {
    ignore_changes = [content]
  }
}

resource "cloudflare_record" "terraform_managed_resource_694a6a23084a976f1a563d72e6e11bbb" {
  name    = "*.local.asztalos.net"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  content = "asztalos.net"
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_record" "terraform_managed_resource_1bb8fe9f88bbabbb1eeb9e68e6da10fd" {
  name    = "local.asztalos.net"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  content = "asztalos.net"
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_record" "terraform_managed_resource_cd5c8e6c433115f918c7dbf3d0a3a58f" {
  name    = "sig1._domainkey.asztalos.net"
  proxied = false
  ttl     = 3600
  type    = "CNAME"
  content = "sig1.dkim.asztalos.net.at.icloudmailadmin.com"
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_record" "terraform_managed_resource_fa7fe93582b72b86ad988c7e53231388" {
  name     = "asztalos.net"
  priority = 10
  proxied  = false
  ttl      = 3600
  type     = "MX"
  content  = "mx01.mail.icloud.com"
  zone_id  = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_record" "terraform_managed_resource_c2b153bf6ff9452cd252f2aaac7a6da5" {
  name     = "asztalos.net"
  priority = 10
  proxied  = false
  ttl      = 3600
  type     = "MX"
  content  = "mx02.mail.icloud.com"
  zone_id  = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_record" "terraform_managed_resource_4e0669bea856b1f22fd7a1bcdf42bc30" {
  name    = "asztalos.net"
  proxied = false
  ttl     = 120
  type    = "TXT"
  content = "\"Fca2-RCcWWdRdbSAAAbmvWupYFY-JdTP3UCpIHP2yUU\""
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_record" "terraform_managed_resource_e19dca3c2553b9608dbb3f9b43e09efe" {
  name    = "asztalos.net"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  content = "\"v=spf1 include:icloud.com ~all\""
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_record" "terraform_managed_resource_a2845f3f5c9c427af3515290cb5c68d3" {
  name    = "asztalos.net"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  content = "\"apple-domain=CSdTNEh8JvlOlPNm\""
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_record" "terraform_managed_resource_397463f674c69ac8ea5157937eb2344c" {
  name    = "_dmarc.asztalos.net"
  proxied = false
  ttl     = 1
  type    = "TXT"
  content = "\"v=DMARC1;  p=quarantine; rua=mailto:359163ccf0df46798200cf86e732815e@dmarc-reports.cloudflare.net\""
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_record" "github_asztalos_net" {
  name    = "github.asztalos.net"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  content = "asztalos.net" // or any valid content; must be proxied
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"
}

resource "cloudflare_ruleset" "github_redirect" {
  zone_id = "c292442e09dde675d6f337a5f4d9e7a6"
  name    = "github.asztalos.net redirect"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules {
    enabled     = true
    description = "Redirect github.asztalos.net to GitHub profile"
    action      = "redirect"

    action_parameters {
      from_value {
        status_code           = 301
        preserve_query_string = false

        target_url {
          value = "https://github.com/gyulaasztalos/$${http.request.uri.path}"
        }
      }
    }

    expression = "http.host == \"github.asztalos.net\""
  }
}
