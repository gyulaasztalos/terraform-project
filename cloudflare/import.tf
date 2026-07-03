# Adopts the zone's existing (auto-provisioned) entry-point ruleset for the
# http_request_firewall_custom phase, instead of creating a second one --
# Cloudflare allows only one zone-level ruleset per phase.
#
# Safe to leave in place indefinitely (a no-op once the resource is already
# in state), or delete after the first successful apply if you'd rather keep
# the file tidy like moved.tf.
import {
  to = cloudflare_ruleset.homeassistant_mtls
  id = "zones/c292442e09dde675d6f337a5f4d9e7a6/36c2aefacdf54e4d9dfa502106660151"
}
