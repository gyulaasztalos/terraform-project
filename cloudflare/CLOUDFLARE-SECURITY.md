# Cloudflare — complete settings walkthrough (Free plan)

Every setting you can reach on a **Free** plan, in the order the current dashboard
presents it, with a verdict for each:

| Badge | Meaning |
|-------|---------|
| 🔴 **Must set** | Leave it wrong and you have a real security or availability gap |
| 🟡 **Nice to have** | Genuine benefit, no downside for this setup |
| ⚪ **Doesn't matter** | Safe either way here — usually because the tunnel/architecture makes it moot |
| ⛔ **Do not set** | Actively harmful *for this setup* (usually: breaks the tunnel or the API endpoints) |

Anything Pro/Business/Enterprise-only is **omitted entirely**.

> **Context this doc assumes** — everything public is served through a
> **Cloudflare Tunnel** (`cloudflared` in k3s, no open inbound ports), origins
> speak plain HTTP in-cluster, and Terraform owns DNS + redirects + the mTLS WAF
> ruleset. See [`CLOUDFLARE.md`](CLOUDFLARE.md) for the architecture. Several
> verdicts below are *only* correct because of that model — they're marked where
> it matters.

> **Nav labels drift.** Cloudflare reorganised the security dashboard in 2025–26
> into five categories (Web application exploits, DDoS attacks, Bot traffic, API
> abuse, Client-side abuse). Where a label may have moved, the *setting name* is
> given too — search the dashboard search bar (`/`) for it.

---

## Table of contents

- [Part A — Account level](#part-a--account-level) (Manage account, Notifications, Observe, Protect & Connect)
- [Part B — Zone: DNS](#part-b--zone-dns)
- [Part C — Zone: SSL/TLS](#part-c--zone-ssltls)
- [Part D — Zone: Security](#part-d--zone-security)
- [Part E — Zone: Rules](#part-e--zone-rules)
- [Part F — Zone: Caching, Network, Speed](#part-f--zone-caching-network-speed)
- [Part G — Step-by-step guides](#part-g--step-by-step-guides)
- [Part H — The 20-minute checklist](#part-h--the-20-minute-checklist)

---

# Part A — Account level

Account-level settings apply to **every zone you own**. They're reached by
clicking the account name in the top-left breadcrumb (or **Accounts** in the
sidebar), which swaps the zone sidebar for the account sidebar.

## A1. Manage account → Members / Authentication

### Two-factor authentication (2FA) — 🔴 Must set
Requires a TOTP code (or hardware key) in addition to your password. Your
Cloudflare account is the single control point for DNS, TLS termination and the
tunnel for every domain you own — an attacker with it can silently re-point your
domains and MITM all traffic. **This is the highest-value security setting in the
entire product.** → [Guide G1](#g1-lock-down-the-account-2fa--hardware-key).

### Security key / passkey (WebAuthn) — 🟡 Nice to have
Phishing-resistant second factor, strictly stronger than TOTP. Add one if you own
a YubiKey or can use a platform passkey (Touch ID / iCloud Keychain). Keep TOTP
enrolled as a fallback so you can't lock yourself out.

### Email address & password — ⚪ Doesn't matter (beyond the obvious)
Use a unique, 1Password-generated password. Consider whether the account email
itself is on a domain hosted *in this Cloudflare account* — if `asztalos.net`
mail broke, account recovery mail would break with it. Your iCloud mail routing
means this is fine, but it's worth knowing.

### Members / roles — ⚪ Doesn't matter
Single-operator account. Relevant only if you add someone; then use
**Administrator Read Only** rather than Super Administrator wherever possible.

### API Tokens (under **My Profile → API Tokens**) — 🔴 Must set
Scoped, revocable credentials. **Never use the legacy Global API Key** — it has
full account access and can't be scoped. Your Terraform token is already
correctly narrow (Zone read, DNS edit, Single Redirect edit, Zone Settings
**read**, WAF edit, SSL & Certificates edit). Two things worth doing:
- Set an **expiry** (e.g. 12 months) and a calendar reminder, so a leaked token
  eventually dies on its own.
- Set an **IP filter** if your CI has stable egress IPs. Terraform Cloud does
  not, so leave it unfiltered there.

### Audit Log (**Manage account → Audit Log**) — 🟡 Nice to have
Records every configuration change with actor, IP and timestamp. Nothing to
configure; just know it exists. It's the first place to look if a setting changed
and you don't know who did it — and the only way to spot a compromised token that
was used *carefully*. Free plan retains **18 months**.

## A2. Notifications — 🔴 Must set (at least three)

Email alerts on account and zone events. Free plans get email delivery (no
webhook/PagerDuty). Cloudflare silently does a lot on your behalf; notifications
are how you find out. The three that genuinely matter here:

| Notification | Why |
|---|---|
| **Universal SSL certificate expiry / validation failure** | If Universal SSL fails to renew, every public site goes to a browser TLS error. Silent otherwise. |
| **Cloudflare Tunnel health / Tunnel down** | Your entire public surface is one tunnel. If `cloudflared` drops, sites 502 and nothing else tells you. |
| **Access / account: "Login from new IP" or 2FA changes** | Early warning of account compromise. |

Also worth enabling: **DNSSEC status change**, **Zone configuration changed**
(catches out-of-band edits that would then drift from Terraform), **Script
Monitor / Page Shield alerts** if you enable client-side monitoring.
→ [Guide G2](#g2-set-up-notifications).

## A3. Observe (Analytics & Logs)

### Account Analytics / Web Analytics — 🟡 Nice to have
Traffic, bandwidth and threat charts aggregated across zones. **Web Analytics**
specifically is a free, cookieless, privacy-friendly RUM product — for
`anitatortai.hu` you're already running Umami, so it's redundant unless you want
a second opinion that doesn't depend on your own cluster staying up.

### Logs (Logpush / Instant Logs) — ⚪ Doesn't matter
Enterprise-only. Not available to you. Free plan gets aggregate analytics and
**Security Events** (sampled), which is enough to tune WAF rules.

## A4. Protect & Connect (Zero Trust)

This is the same "Zero Trust" dashboard your tunnel lives in. Free tier covers
**up to 50 users** and is unusually generous — it's the biggest untapped security
win available to you.

### Networks → Tunnels — 🔴 Must set (already done)
Where the tunnel and its **Public Hostnames** live. Two hardening habits:
- **Scope each public hostname by path** where the app has an admin surface
  (your Umami `/script.js` + `/api/send` case). A hostname with no path
  restriction exposes the whole app.
- Keep the tunnel token in 1Password only; rotate it if it ever lands in a log.

### Access → Applications (self-hosted) — 🔴 Must set for any admin UI
Puts an **identity check in front of a hostname at the edge**, before the request
enters the tunnel. This is how you expose an admin dashboard (Umami's UI, ArgoCD,
Grafana, anything) to the internet safely without a VPN — the app never sees an
unauthenticated request. Free for 50 users, works with a one-time PIN emailed to
an allowlisted address, or Google/GitHub as IdP.

**This is strictly better than the pattern of "just don't expose the admin
path".** → [Guide G5](#g5-put-cloudflare-access-in-front-of-an-admin-surface).

### Access → Service Auth / Service Tokens — 🟡 Nice to have
Machine-to-machine credentials (`CF-Access-Client-Id` / `-Secret` headers) for
letting a script or CI job through an Access-protected hostname. Use it instead
of carving a path exception when automation needs in.

### Settings → WARP / Device enrolment — ⚪ Doesn't matter
Client-based access to private networks. Overkill unless you want to reach
`*.local.asztalos.net` from outside the LAN without exposing it — at which point
it becomes a genuinely good alternative to a VPN.

### Turnstile (account level) — 🟡 Nice to have
Cloudflare's privacy-preserving CAPTCHA alternative. Already wired into
cake-order but disabled. Correct call: turn it on **when spam appears**, not
before — it costs you conversions on a pastry-order form. The widget/secret keys
are issued here.

### Registrar / domain lock — 🔴 Must set (wherever your registrar is)
If a domain is registered *at* Cloudflare Registrar, domain transfer lock is on
by default — verify it. If registered elsewhere, go set **registrar lock** and
2FA there too. Domain hijacking at the registrar bypasses every Cloudflare
setting you're about to configure.

---

# Part B — Zone: DNS

## DNS → Records

### Proxy status (orange vs grey cloud) — 🔴 Must set
Orange = traffic goes through Cloudflare (WAF, TLS, tunnel, redirects, IP
hidden). Grey = plain DNS, the record's IP is public and unprotected. Your rule
is already right: **orange for everything served through the tunnel, grey for
mail and `*.local.asztalos.net`**. Proxying a mail record breaks mail; proxying a
LAN name breaks split-horizon resolution.

### CNAME flattening — ⚪ Doesn't matter (already implicit)
Lets the apex be a CNAME (illegal in raw DNS) by resolving it to an A record at
the edge. Automatically applied to your apex → `<uuid>.cfargotunnel.com`. Setting
is "Flatten CNAME at apex" (default) vs "Flatten all CNAMEs" — leave default.

## DNS → Settings

### DNSSEC — 🟡 Nice to have (🔴 if the registrar makes it easy)
Cryptographically signs your DNS so a resolver can detect forged answers,
defeating cache-poisoning and some MITM setups. The catch is operational: it
requires adding a DS record **at your registrar**, and if the chain breaks your
domain goes *completely dark* — not degraded, unresolvable. Enable it if you're
comfortable with that failure mode. → [Guide G3](#g3-enable-dnssec).

### Multi-provider DNS / secondary DNS — ⚪ Doesn't matter
Off. Only relevant when running Cloudflare alongside another authoritative DNS
provider.

### CNAME Flattening for all CNAMEs — ⛔ Do not set
Would flatten your mail CNAMEs (`sig1._domainkey`) into A records, breaking DKIM.
Leave it on "apex only".

---

# Part C — Zone: SSL/TLS

## C1. Overview → Encryption mode

### SSL/TLS encryption mode — 🔴 Must set → **Full (strict)**
Controls how Cloudflare connects to *your origin*. The options:
- **Off** — plaintext to visitors. ⛔ Never.
- **Flexible** — HTTPS to browser, **plain HTTP to origin**. ⛔ Never: it makes
  the padlock a lie and enables trivial MITM on the origin leg.
- **Full** — HTTPS to origin but **certificate not validated** (self-signed ok).
- **Full (strict)** — HTTPS to origin *and* the cert must be valid. ✅ This one.

**Tunnel nuance:** with `cloudflared` there is no origin TLS leg to validate —
the tunnel itself is an authenticated, encrypted outbound connection, so the mode
is largely moot for tunnel-served hostnames. Set **Full (strict)** anyway, because
it's the correct default the day you add a non-tunnel origin, and a
Flexible/Full setting left lying around is a footgun.

### Automatic SSL/TLS — ⛔ Do not set (choose the explicit mode)
Newer default where Cloudflare picks the encryption mode for you and can *raise*
it automatically. Sounds good, but it means your security posture can change
without you. Switch to **Custom SSL/TLS → Full (strict)** so the setting is
explicit and auditable.

## C2. Edge Certificates

### Universal SSL — 🔴 Must set (on by default)
The free, auto-renewing certificate covering your apex and **first-level
subdomains** (`*.asztalos.net`, but *not* `a.b.asztalos.net`). Leave enabled.
Disabling it takes every site offline. Note the one-level limit — a
two-level hostname needs a redesign or paid Advanced Certificate Manager.

### Always Use HTTPS — 🔴 Must set → On
301-redirects any `http://` request to `https://` at the edge. Without it a
plaintext request is served plaintext. Zero downside.

### HSTS (HTTP Strict Transport Security) — 🔴 Must set → On, carefully
A response header telling browsers "never contact this host over HTTP again, for
N seconds." It closes the gap *Always Use HTTPS* leaves open: the very first
plaintext request, which an on-path attacker can hijack before the redirect.

**The danger is that it's not revocable** — browsers cache it for the full
max-age regardless of what you do later. Ramp up, and only enable
`includeSubDomains` once *every* subdomain (including LAN-only ones you might
serve over HTTP) is HTTPS. → [Guide G4](#g4-enable-hsts-safely).

### Minimum TLS Version — 🔴 Must set → **1.2**
Rejects handshakes below the given version. TLS 1.0/1.1 are broken and
PCI-forbidden. 1.2 is the safe floor; **1.3** would be stronger but drops some
older Android/OS clients — not worth it for a public bakery site.

### TLS 1.3 — 🔴 Must set → On (default)
Faster, safer handshake with legacy ciphers removed. On by default, no
compatibility risk (clients that don't speak it fall back to 1.2). Just verify.

### Automatic HTTPS Rewrites — 🟡 Nice to have → On
Rewrites `http://` asset URLs in your HTML to `https://` so mixed-content
warnings don't break pages. Harmless safety net; your app should emit correct
URLs anyway.

### Certificate Transparency Monitoring — 🟡 Nice to have → On
Emails you whenever *any* CA issues a certificate for your domain. This is your
detection mechanism for mis-issuance or an attacker who got control of DNS long
enough to get a cert. Free, zero-effort, alert-only.

### Opportunistic Encryption — ⚪ Doesn't matter
Advertises HTTP/2-over-TLS to clients making plaintext requests. Legacy, near
zero effect now that Always Use HTTPS + HSTS handle it. Leave default.

### Total TLS / Advanced Certificates / Custom certificates / Cipher suites — ⚪ Doesn't matter
All require paid Advanced Certificate Manager. Not available on Free.

## C3. Client Certificates (mTLS)

### Client certificates + Hostname associations — 🔴 Must set (already done)
The Cloudflare-managed CA and the per-hostname binding behind your Home Assistant
mTLS setup. Managed in Terraform (`homeassistant_mtls` ruleset) — **don't edit the
rule order in the dashboard**, it's controlled by list order in `main.tf`.
Remember: an expired client cert locks you out until you issue and install a new
one on every device.

## C4. Origin Server

### Origin certificates — ⚪ Doesn't matter (tunnel makes it unnecessary)
Free long-lived certs trusted only by Cloudflare, for the edge→origin leg. Your
tunnel replaces this entirely. You'd need one only if you exposed an origin
directly on port 443.

### Authenticated Origin Pulls — ⚪ Doesn't matter (same reason)
Makes the origin verify that requests genuinely came from Cloudflare, preventing
someone who learns your origin IP from bypassing the edge. **Critical for a
port-exposed origin — irrelevant for you**, because the tunnel is outbound-only
and there is no origin IP to find. This is one of the main reasons the tunnel
architecture is worth the complexity.

---

# Part D — Zone: Security

The 2025–26 redesign groups these under **Security** with sub-pages: *Overview /
Analytics*, *Security rules*, *Settings*, plus the category pages. Names in
parentheses are the setting to search for.

## D1. Security → Analytics & Events

### Security Analytics / Events — 🟡 Nice to have
Sampled log of what the WAF, bots and rate limits did, filterable by rule, path,
country, ASN. Nothing to configure. **This is where you tune rules** — always
deploy a new WAF rule, watch Events for a day, *then* tighten it. It's also how
you tell a real attack from your own monitoring.

## D2. Security → Security rules (WAF)

### Cloudflare Free Managed Ruleset — 🔴 Must set (verify deployed)
A curated subset of Cloudflare's managed WAF rules covering high-impact,
widely-exploited CVEs (Log4j, Shellshock, common RCEs). Deployed by default on
Free. You can't tune individual rules on Free — just confirm it's enabled and
leave it. Free tier does **not** include the full Cloudflare Managed Ruleset or
OWASP Core Ruleset.

### Custom rules — 🔴 Must set (you get **5**)
Your own `if <expression> then <action>` rules evaluated at the edge before
anything reaches the tunnel. Actions on Free: Block, Managed Challenge, JS
Challenge, Skip — **not** Log. Five is a tight budget, so spend it deliberately.

Recommended allocation for this setup:
1. **Block admin/metrics paths from the internet** (`/metrics`, `/api/admin`,
   Umami's dashboard paths) — belt-and-suspenders behind the app's own 404s.
2. **Managed Challenge on the quote form** (`/ajanlatkeres`) — defence in depth
   over the app's per-IP/email limit.
3. Keep 2–3 free for incident response. When you're being scraped or spammed at
   3am, an empty rule slot is what lets you stop it in 60 seconds.

→ [Guide G6](#g6-create-a-waf-custom-rule).

### Rate limiting rules — 🟡 Nice to have (you get **1**, and it's crippled)
Blocks a client exceeding N requests in a window. The Free tier is heavily
limited: **1 rule**, counting period fixed at **10 s**, mitigation timeout **10
s**, counts by **IP only**, and the expression can only match on **Path** and
**Verified Bot**. That's enough to blunt a crude flood against one endpoint and
nothing more. Point it at your form endpoint if you point it anywhere.
→ [Guide G7](#g7-create-the-one-free-rate-limiting-rule).

### Managed Rules exceptions / skip rules — 🟡 Nice to have
A Skip custom rule that exempts known-good traffic (your own monitoring, a
webhook source) from the WAF. Use sparingly and scope by IP *and* path — a broad
skip rule is a hole. Note: **Skip cannot bypass Bot Fight Mode** (see below).

### Under Attack Mode (**Security → Settings**, or the quick action) — 🟡 Nice to have (emergency only)
Presents an interstitial JS challenge to *every* visitor for ~5 seconds. It is a
sledgehammer for an active L7 DDoS: it will also block legitimate users, API
calls, RSS readers and your own monitoring. Know where the toggle is; leave it
**off** until you're actually under attack, and turn it off after.

## D3. Security → Bot traffic

### Bot Fight Mode — 🟡 Nice to have — **with a serious caveat** ⚠️
Detects known-bot request patterns and issues a computational challenge. Free,
zero-config, meaningfully reduces scraper and scanner noise.

**Read this before enabling:** Bot Fight Mode **cannot be scoped, tuned, or
bypassed** — not by WAF Skip rules, not by Page Rules. It applies to the whole
zone, and it force-enables JavaScript Detections. That means it will challenge
**any non-browser client**, including:
- Umami's `/api/send` beacon in some configurations,
- webhooks, uptime monitors, `curl` health checks,
- RSS/feed readers and legitimate API consumers.

For `anitatortai.hu` (a browser-facing marketing site) it's a reasonable win. For
a zone carrying API or machine traffic, it can silently break things you won't
notice for weeks. **Enable it on one zone at a time and watch Security Events for
48 hours.** If it breaks something, your only remedy is turning it off.

### Block AI Bots / AI Labyrinth — 🟡 Nice to have
One-click blocking of AI training crawlers (GPTBot, CCBot, etc.); AI Labyrinth
feeds them decoy content instead. For a pastry business with original photography
and copy, blocking AI scrapers is a defensible choice with no SEO cost — these
are *not* the crawlers that index you for search. Turn on if you care; harmless
either way.

### Managed `robots.txt` — ⚪ Doesn't matter
Cloudflare serves a maintained `robots.txt` declaring AI-crawler preferences.
Convenience only — `robots.txt` is advisory and ignored by bad actors. Skip if
your app serves its own.

### Super Bot Fight Mode / Bot Management — ⚪ Doesn't matter
Pro+ and Enterprise. Not available.

## D4. Security → DDoS attacks

### HTTP DDoS Attack Protection (managed ruleset) — 🔴 Must set (on by default, unconfigurable)
Always-on L3–L7 DDoS mitigation, applied automatically to all plans including
Free, with no request cap. This is the single biggest thing Cloudflare gives you
for nothing. Overrides and sensitivity tuning are Enterprise-only, so on Free
there is literally nothing to configure — **just don't route around it** (i.e.
keep records proxied).

### Browser Integrity Check — 🟡 Nice to have → On
Inspects headers for signatures of known-abusive bots and malformed/absent
user-agents, and blocks them. Cheap, low false-positive, catches lazy scanners.
Small risk of blocking a badly-written legitimate client — same watch-your-Events
advice.

### Challenge Passage — ⚪ Doesn't matter
How long a visitor stays "solved" after passing a challenge (default 30 min).
Only relevant once you're issuing challenges at volume. Default is fine.

### Security Level — 🟡 Nice to have → **Medium** (default)
Sets how aggressively Cloudflare challenges visitors based on their IP threat
reputation. *Essentially Off* / *Low* / *Medium* / *High* / *I'm Under Attack*.
Medium is right for a public site. High will challenge legitimate visitors on
shared/VPN/mobile-CGNAT IPs — a real conversion cost for a business site.

## D5. Security → Client-side abuse

### Page Shield / Script Monitor — 🟡 Nice to have
Inventories every third-party JavaScript running on your pages and alerts when a
new or changed script appears. This is your detection for a Magecart-style
supply-chain compromise (a CDN'd script silently replaced to skim form data).
Free tier gives you the script *inventory and alerts*; policy enforcement is
paid. For a site with a customer-facing order form, the alerting alone is worth
enabling. Pair with a Notification.

### Email Address Obfuscation — 🟡 Nice to have → On
Encodes `mailto:` addresses in your HTML so scrapers don't harvest them, decoding
them in-browser via JS. Reduces spam to your published business address. Tiny JS
cost, occasionally confuses a copy-paste. Fine to leave on.

### Hotlink Protection — ⚪ Doesn't matter (⛔ if you have social sharing)
Blocks other sites from embedding your images by checking the Referer. Saves
bandwidth you aren't paying for, and **will break image previews when your cake
photos are shared on Facebook/WhatsApp/Instagram** — the opposite of what a
pastry business wants. Leave off.

### Server-side Excludes — ⚪ Doesn't matter
Legacy: hides content wrapped in `<!--sse-->` tags from suspicious visitors.
Requires app changes for negligible benefit. Ignore.

## D6. Security → Settings (misc)

### Managed `security.txt` — 🟡 Nice to have
Publishes `/.well-known/security.txt` telling researchers how to report a
vulnerability to you. One field (a contact email), and it converts "found a bug,
posted it on Twitter" into "found a bug, emailed you". Cheap goodwill.

### Replace Insecure JS / Automatic Platform Optimization — ⚪ Doesn't matter
Niche or WordPress-specific. Not applicable.

### Leaked credentials / malicious upload / sensitive data detection — ⚪ Doesn't matter
Paid tiers. Listed here only so you know why they're greyed out.

---

# Part E — Zone: Rules

### Redirect Rules (Single Redirects / Dynamic Redirects) — 🔴 Must set (Terraform-owned)
Your `www → apex` and `github.asztalos.net → github.com/...` redirects. **These
are managed in Terraform** (`http_request_dynamic_redirect`). Don't create them
in the dashboard — you'll get drift or a duplicate. Free plan gets ~10 single
redirect rules.

### Configuration Rules — 🟡 Nice to have
Override zone settings (security level, cache, etc.) for specific paths. Useful
if you ever need e.g. a stricter Security Level only on `/admin`. Empty is fine.

### Transform Rules (URL rewrite / request & response headers) — 🟡 Nice to have
Rewrite URLs or add/remove headers at the edge. The security use case: adding
`X-Frame-Options`, `Referrer-Policy` etc. **Your app already sends its own
security headers** (cake-order middleware) — do *not* duplicate them here, and
above all don't set a second CSP, since two CSP headers intersect and will break
your page in confusing ways.

### Origin Rules — ⚪ Doesn't matter
Change host header / port / SNI toward the origin. The tunnel's public-hostname
mapping already does this job.

### Page Rules — ⛔ Do not set (deprecated)
The legacy all-in-one rules product, superseded by the dedicated Rules products
above and being migrated away. Anything you'd do here is better done in Redirect
/ Cache / Configuration Rules. Don't add new ones.

### Snippets — ⚪ Doesn't matter
Small JS at the edge (a lightweight Workers). Powerful, but nothing you need for
security here, and it's another place logic can hide.

---

# Part F — Zone: Caching, Network, Speed

### Caching → Configuration / Cache Rules — ⚪ Doesn't matter (one security note)
Performance, not security — **except**: never cache authenticated or
personalised responses. Default "Standard" caching only caches static extensions,
which is safe. If you ever add a Cache Rule, make sure it can't cache a response
that varies per user. **Purge Cache** lives here for when a deploy doesn't show up.

### Caching → Tiered Cache / Crawler Hints — ⚪ Doesn't matter
Performance niceties, free, no risk. Enable if you like.

### Network → HTTP/2, HTTP/3 (QUIC), 0-RTT — 🟡 Nice to have
HTTP/2 and HTTP/3 on = faster, no security downside. **0-RTT Connection Resumption
is off by default and should stay off** unless you know your app is idempotent on
replayed early data — it trades a replay-attack window for a few ms.

### Network → IPv6 Compatibility — 🟡 Nice to have → On (default)
Cloudflare serves your site over IPv6 even though your origin is v4-only. Free
reach, no risk.

### Network → WebSockets — ⚪ Doesn't matter → leave On
Needed if any app uses WebSockets (Home Assistant does). Off would break it.

### Network → Onion Routing — ⚪ Doesn't matter
Serves your site to Tor users via a .onion address without challenging them.
Harmless; irrelevant to a local bakery.

### Network → gRPC / Pseudo IPv4 / IP Geolocation — ⚪ Doesn't matter
Leave defaults. IP Geolocation adds a country header your app can read; enable
only if the app uses it.

### Speed → Optimization (Auto Minify, Rocket Loader, Polish, Mirage) — ⚪ Doesn't matter
Performance features. **Auto Minify was retired**; Rocket Loader reorders script
execution and **breaks more sites than it speeds up** — leave it off. Polish/Mirage
are Pro+. Modern build tooling already minifies.

### Speed → Early Hints / Brotli — 🟡 Nice to have
Free, safe performance wins. On.

### Scrape Shield — see [D5](#d5-security--client-side-abuse), it now lives under Client-side abuse.

---

# Part G — Step-by-step guides

## G1. Lock down the account (2FA + hardware key)

1. Dashboard top-right → **profile icon → My Profile**.
2. **Authentication** tab → **Two-Factor Authentication → Enable**.
3. Enter your password, scan the QR with 1Password (or your authenticator), enter
   the 6-digit code to confirm.
4. **Download the backup codes and store them in 1Password immediately.** They're
   shown once. Without them, a lost phone = a support ticket with ID checks.
5. *(Optional, stronger)* same page → **Security Keys → Add security key** →
   name it → touch your YubiKey / approve the passkey prompt.
6. **API Tokens** tab → review the list. Delete anything you don't recognise.
   Confirm the **Global API Key** is not in use anywhere (it can't be deleted,
   only rolled — roll it if it was ever pasted into a script).

## G2. Set up notifications

1. Account sidebar → **Notifications** → **Add**.
2. Pick the notification type. Do these three, one at a time:
   - **SSL for SaaS / Universal SSL** → *Certificate validation & expiry*
   - **Cloudflare Tunnel** → *Tunnel health*, then select your tunnel
   - **Account** → *login from unusual location* / *2FA disabled*
3. Give each a **name** you'll recognise in your inbox at 3am
   (`CF: tunnel down — k3s`, not `Notification 1`).
4. **Notification delivery** → your email address. Free plan is email-only.
5. **Save**. Then add a mail rule so these don't land in a folder you never read.

## G3. Enable DNSSEC

> Do this when you have 15 unhurried minutes. A broken DNSSEC chain makes the
> domain **unresolvable**, not merely insecure.

1. Zone → **DNS → Settings** → **DNSSEC → Enable DNSSEC**.
2. Cloudflare shows a **DS record**: key tag, algorithm, digest type, digest.
   Leave the tab open.
3. Go to your **registrar** (where the domain is registered — not Cloudflare,
   unless you use Cloudflare Registrar, in which case it's automatic and you're
   done).
4. Find *DNSSEC* / *DS records* in the registrar's control panel → **Add DS
   record** → paste the four values exactly.
5. Wait for propagation (minutes to a few hours). Cloudflare's DNSSEC panel flips
   to **Active** when it sees the chain.
6. Verify independently at `https://dnsviz.net/d/<yourdomain>/analyze/` — you want
   a clean chain with no red.
7. **Before you ever move DNS providers again**: disable DNSSEC and remove the DS
   record *first*, wait for TTL, then migrate. This is the classic way to take a
   domain offline for a day.

## G4. Enable HSTS safely

1. Zone → **SSL/TLS → Edge Certificates**. First confirm **Always Use HTTPS = On**
   and that every hostname on the zone genuinely works over HTTPS. HSTS on a
   hostname that can't do TLS = that hostname is gone.
2. Scroll to **HTTP Strict Transport Security (HSTS)** → **Enable HSTS**.
3. Read and accept the warning dialog (it is not boilerplate — this is the
   irreversible one).
4. Set, for the **first** rollout:
   - **Max Age**: `6 months` — long enough to be meaningful. If you're nervous,
     start at **1 month**, confirm nothing broke, then raise it.
   - **Apply HSTS policy to subdomains (includeSubDomains)**: **Off** initially.
     Turn it **On** only once you're certain *every* subdomain — including
     `*.local.asztalos.net` and anything you serve internally over plain HTTP —
     is HTTPS. This flag is what usually bites people.
   - **Preload**: **Off**. Preloading submits your domain to a list baked into
     browser binaries; removal takes *months* of browser release cycles. Only
     consider it once you've run `includeSubDomains` for a year without incident.
   - **No-Sniff header**: On (harmless, adds `X-Content-Type-Options: nosniff`).
5. **Save**. Verify:
   ```bash
   curl -sI https://anitatortai.hu | grep -i strict-transport-security
   # strict-transport-security: max-age=15552000
   ```

## G5. Put Cloudflare Access in front of an admin surface

Worked example: exposing the **Umami dashboard** at `stats.anitatortai.hu` to
yourself only, instead of blocking it.

1. **Zero Trust dashboard** (Protect & Connect) → **Access → Applications → Add
   an application → Self-hosted**.
2. **Application name**: `Umami admin`. **Session duration**: 24 hours.
3. **Public hostname**: subdomain `stats`, domain `anitatortai.hu`, **path**
   `/` — *but* see step 8, you'll exclude the tracker paths.
4. **Next** → **Add policy**:
   - Policy name: `Me only`
   - Action: **Allow**
   - Configure rules → Include → Selector **Emails** → value `gyula@asztalos.net`
5. **Next** → leave defaults → **Add application**.
6. Identity: with no IdP configured, Cloudflare uses **One-time PIN** — it emails
   a code to the allowlisted address. That's sufficient. To use Google/GitHub
   instead: **Settings → Authentication → Add new** first.
7. Test in a private window: visiting `stats.anitatortai.hu` should now show the
   Cloudflare Access login, not Umami.
8. **Critical for Umami specifically** — the tracker endpoints must stay public.
   Add a second application (Access evaluates the most specific path first) as a
   **Bypass** policy:
   - Application → Self-hosted → hostname `stats.anitatortai.hu`, path
     `api/send` → policy Action **Bypass**, Include **Everyone**.
   - Repeat for `script.js`.
   Verify a cake-order page still records a pageview before you walk away.

## G6. Create a WAF custom rule

Worked example: **block `/metrics` from the public internet.**

1. Zone → **Security → Security rules** (older UI: *Security → WAF → Custom
   rules*) → **Create rule**.
2. **Rule name**: `Block metrics from internet`.
3. Build the expression with the visual editor:
   - Field **URI Path**, Operator **contains**, Value `/metrics`
4. For anything non-trivial, click **Edit expression** and paste directly instead:
   ```
   (http.request.uri.path contains "/metrics") or
   (http.request.uri.path contains "/actuator") or
   (starts_with(http.request.uri.path, "/.git"))
   ```
5. **Then take action** → choose:
   - **Block** — flat refusal, correct for admin/metrics paths.
   - **Managed Challenge** — correct for *human* paths you want to protect
     (forms), since it's usually invisible to real browsers.
   - Avoid *JS Challenge* / *Interactive Challenge* unless Managed isn't enough.
6. **Place at**: *Last* is fine unless you're building a skip-then-block pair, in
   which case order matters (as with the Home Assistant mTLS ruleset — which is
   Terraform-ordered, so don't drag it here).
7. **Deploy**.
8. **Verify**, then watch:
   ```bash
   curl -sI https://anitatortai.hu/metrics   # expect 403
   ```
   Then **Security → Events**, filter by this rule name, and check for 24h that
   you're not blocking anything real.

> To protect the quote form instead, same steps with expression
> `http.request.uri.path eq "/ajanlatkeres" and http.request.method eq "POST"`
> and action **Managed Challenge**.

## G7. Create the one free rate limiting rule

Remember the Free constraints: 1 rule, 10s window, 10s block, IP-only, and the
expression may only reference **Path** and **Verified Bot**.

1. Zone → **Security → Security rules → Create rule → Rate limiting rule**.
2. **Rule name**: `Throttle quote form`.
3. **If incoming requests match**: Field **URI Path** → **equals** →
   `/ajanlatkeres`.
4. **With the same characteristics**: **IP** (the only option on Free).
5. **When rate exceeds**: Requests `5`, Period `10 seconds` (period is fixed).
6. **Then take action**: **Block**, duration `10 seconds` (also fixed).
7. **Deploy**, then confirm a normal submission still works — 5 requests per 10
   seconds is far above human behaviour but below a script.

---

# Part H — The 20-minute checklist

Do these in order. Everything else in this document is optional.

**Account (once, protects everything):**
- [ ] 2FA enabled, backup codes in 1Password — [G1](#g1-lock-down-the-account-2fa--hardware-key)
- [ ] Global API Key unused; Terraform token scoped and given an expiry
- [ ] Registrar lock + 2FA at your registrar
- [ ] Notifications: SSL expiry, Tunnel health, account login — [G2](#g2-set-up-notifications)

**Per zone (`asztalos.net`, `anitatortai.hu`):**
- [ ] SSL/TLS mode = **Full (strict)**, explicit (not Automatic)
- [ ] Always Use HTTPS = **On**
- [ ] Minimum TLS Version = **1.2**; TLS 1.3 = **On**
- [ ] HSTS enabled, 6 months, `includeSubDomains` only when truly safe, preload **off** — [G4](#g4-enable-hsts-safely)
- [ ] Certificate Transparency Monitoring = **On**
- [ ] Automatic HTTPS Rewrites = **On**
- [ ] Security Level = **Medium**; Browser Integrity Check = **On**
- [ ] Free Managed Ruleset confirmed deployed
- [ ] WAF custom rule blocking `/metrics` and friends — [G6](#g6-create-a-waf-custom-rule)
- [ ] Bot Fight Mode — **on `anitatortai.hu` only**, then watch Events 48h ⚠️
- [ ] Mail records still **grey-cloud**; LAN records still grey
- [ ] Hotlink Protection **off** (social sharing)
- [ ] Rocket Loader **off**

**Worth the extra hour:**
- [ ] Cloudflare Access in front of every admin UI — [G5](#g5-put-cloudflare-access-in-front-of-an-admin-surface)
- [ ] DNSSEC — [G3](#g3-enable-dnssec)
- [ ] Page Shield script monitoring + alert
- [ ] Rate limiting rule on the form — [G7](#g7-create-the-one-free-rate-limiting-rule)

---

## Sources

Verified against current Cloudflare documentation (July 2026):

- [Security dashboard — settings & new navigation](https://developers.cloudflare.com/security/settings/)
- [Making Application Security simple with a new unified dashboard experience](https://blog.cloudflare.com/new-application-security-experience/)
- [WAF custom rules (Free = 5 rules, all actions except Log)](https://developers.cloudflare.com/waf/custom-rules/)
- [Rate limiting rules (Free = 1 rule, 10s/10s, IP only)](https://developers.cloudflare.com/waf/rate-limiting-rules/)
- [Bot Fight Mode — cannot be bypassed by custom rules](https://developers.cloudflare.com/bots/get-started/bot-fight-mode/)
- [WAF Managed Rules — Free Managed Ruleset](https://developers.cloudflare.com/waf/managed-rules/)
- [SSL edge certificates & additional options](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/)
- [Page Rules migration guide](https://developers.cloudflare.com/rules/reference/page-rules-migration/)
- [The future of Page Rules](https://blog.cloudflare.com/future-of-page-rules/)
- [Notifications (Free = email delivery, proxied records only)](https://developers.cloudflare.com/fundamentals/notifications/)
