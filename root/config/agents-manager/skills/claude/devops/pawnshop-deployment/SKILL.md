---
name: pawnshop-deployment
description: pawnshop-deployment skill
  Deterministic Docker deployment for pawnshop (risheng.team.nexeraa.io).
  Proxy-agnostic: works with NPM self-heal, Traefik/Coolify labels, or Caddy.
  Use when: deploying pawnshop, rebuilding Docker images, debugging 404 static assets,
  or migrating to Coolify.
version: 1.4.0
---

# Pawnshop Deployment

## Architecture

```
Browser → Proxy (NPM or Traefik or Caddy) → pawnshop-app-1:6006 → Next.js standalone
```

**Key principle:** The app is proxy-agnostic. It binds to `0.0.0.0:6006` inside Docker.
Any proxy that can reach `host.docker.internal:6006` (or the container's IP) works.

---

## One-Command Deploy (NPM)

```bash
cd /root/pawnshop && docker compose up --build -d && docker exec npm nginx -s reload
```

---

## NPM Proxy — CRITICAL: TWO Files Control Routing

NPM routes through **TWO config files**. Both must point to `host.docker.internal:6006`.
Changes via NPM UI can silently overwrite File 2 — always verify after NPM UI changes.

### File 1: Domain-level proxy
**Path (inside npm container):** `/data/nginx/proxy_host/7.conf`
**Purpose:** Routes all `/` and non-static requests to the app.
**Status:** ✅ Set to `proxy_pass http://host.docker.internal:6006`

### File 2: Static asset override ⚠️ ⚠️ ⚠️
**Path (inside npm container):** `/data/nginx/custom/server_proxy.conf`
**Also on host at:** `/root/npm/data/nginx/custom/server_proxy.conf`
**Purpose:** Included inside the `server {}` block of 7.conf via `include /data/nginx/custom/server_proxy[.]conf`. OVERRIDES `/_next/static/` routing. NPM UI may **silently overwrite** this file — it looks empty in the NPM UI but it still works, so operators don't notice until static assets 404.
**This file must ALWAYS contain the block below.** The header comment prevents accidental removal.

```nginx
# =============================================================================
# CUSTOM STATIC ASSET OVERRIDE — risheng.team.nexeraa.io
# =============================================================================
# THIS FILE OVERRIDES /_next/static/ proxy for risheng.team.nexeraa.io
#
# ⚠️  DO NOT CHANGE THE IP BELOW without consulting the pawnshop-deployment skill
#     or you will break CSS/JS/fonts on risheng.team.nexeraa.io (404 on all static assets)
#
# CORRECT TARGET: host.docker.internal:6006  (pawnshop-app Docker container)
# WRONG TARGET:   116.202.111.107:6007       (OLD hermes server — decommissioned)
#
# How it works:
#   7.conf includes this file: `include /data/nginx/custom/server_proxy[.]conf`
#   This file's location / block ADDS TO / OVERRIDES what 7.conf does for matching paths.
#   NPM UI may silently overwrite this file — CHECK THIS FILE AFTER any NPM UI changes.
#
# Verification after changes:
#   curl -sI https://risheng.team.nexeraa.io/_next/static/css/ | head -1
#   Expected: HTTP/2 200
#   If 404: this file was overwritten — restore with this content and `docker exec npm nginx -s reload`
# =============================================================================

location /_next/static/ {
    proxy_pass http://host.docker.internal:6006;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Permanent fix: write the annotated file to host disk
Write the annotated file to the host path so it persists across npm container rebuilds:
```bash
tee /root/npm/data/nginx/custom/server_proxy.conf << 'ENDOFFILE'
# =============================================================================
# CUSTOM STATIC ASSET OVERRIDE — risheng.team.nexeraa.io
# =============================================================================
# ⚠️  DO NOT CHANGE THE IP BELOW
# CORRECT TARGET: host.docker.internal:6006
# WRONG TARGET:   116.202.111.107:6007 (decommissioned)
# Verification: curl -sI https://risheng.team.nexeraa.io/_next/static/css/ | head -1
# =============================================================================
location /_next/static/ {
    proxy_pass http://host.docker.internal:6006;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
}
ENDOFFILE
```

### Check current state:
```bash
docker exec npm cat /data/nginx/custom/server_proxy.conf
docker exec npm cat /data/nginx/proxy_host/7.conf | grep proxy_pass
```

### Self-heal if overwritten:
```bash
docker exec npm tee /data/nginx/custom/server_proxy.conf << 'EOF'
location /_next/static/ {
    proxy_pass http://host.docker.internal:6006;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
}
EOF
docker exec npm nginx -s reload
```

### Auto Self-Heal on NPM container restart (crontab):
```bash
# Add to npm container crontab (one-time setup)
docker exec npm sh -c 'echo "*/5 * * * * grep -q host.docker.internal /data/nginx/custom/server_proxy.conf || (echo \"location /_next/static/ { proxy_pass http://host.docker.internal:6006; proxy_set_header Host \\\$host; proxy_set_header X-Forwarded-For \\\$remote_addr; proxy_set_header X-Forwarded-Proto \\\$scheme; }\" > /data/nginx/custom/server_proxy.conf && nginx -s reload)" | crontab -'
```

---

## Docker Network (one-time)

npm and pawnshop must share a Docker network:
```bash
docker network connect pawnshop_network npm
```

---

## Traefik / Coolify Labels (recommended for scaling)

Add these labels to the `app` service in `docker-compose.yml`.
Coolify reads these automatically — no NPM or manual proxy config needed:

```yaml
services:
  app:
    image: pawnshop-app:latest
    labels:
      # Traefik/Coolify reads these automatically
      - "traefik.enable=true"
      - "traefik.http.routers.pawnshop.rule=Host(`risheng.team.nexeraa.io`)"
      - "traefik.http.routers.pawnshop.tls=true"
      - "traefik.http.routers.pawnshop.tls.certResolver=letsencrypt"
      - "traefik.http.services.pawnshop.loadbalancer.server.port=6006"
      # Optional: rate limiting
      - "traefik.http.middlewares.pawnshop-rate.limit.rate=100"
      - "traefik.http.middlewares.pawnshop-rate.limit.burst=50"
    networks:
      - pawnshop_network
      - traefik_public  # or whatever network Traefik watches

networks:
  pawnshop_network:
    external: false
  traefik_public:
    external: true  # or false depending on setup
```

**Coolify deployment:** Upload the compose file, set domain `risheng.team.nexeraa.io`,
Coolify auto-detects Traefik labels and configures routing. SSL auto-provisioned.

---

## Caddy Alternative (standalone, no NPM or Traefik needed)

If using Caddy instead of NPM/Traefik:

```bash
# Caddyfile (/root/Caddyfile)
risheng.team.nexeraa.io {
    reverse_proxy localhost:6006
    tls {
        dns cloudflare API_KEY_HERE
    }
}
```

```bash
# Run Caddy
docker run -d --name caddy \
    -v /root/Caddyfile:/etc/caddy/Caddyfile \
    -p 80:80 -p 443:443 \
    --network pawnshop_network \
    caddy:latest
```

Caddy auto-discovers containers on the same network and handles SSL automatically.
No manual static asset routing needed — Caddy proxies everything by default.

---

## Verify

```bash
# Static assets via public URL — must be 200
curl -s -o /dev/null -w "%{http_code}" https://risheng.team.nexeraa.io/_next/static/css/2bba93359a4a1c6a.css

# Homepage via public URL
curl -s -o /dev/null -w "%{http_code}" https://risheng.team.nexeraa.io/

# Admin dashboard
curl -s -o /dev/null -w "%{http_code}" https://risheng.team.nexeraa.io/dashboard
```

---

## If 404s Still Happen (NPM path)

1. Check File 2 is not empty: `docker exec npm cat /data/nginx/custom/server_proxy.conf`
2. If empty → run self-heal commands above
3. Reload npm: `docker exec npm nginx -s reload`
4. Verify container port: `docker ps | grep pawnshop-app`
5. Browser cache — hard refresh (Ctrl+Shift+R)

---

## Troubleshooting Static Assets 404

**Symptom:** App builds/deploys fine, homepage loads, but CSS/JS/fonts return 404.
**Root cause:** Almost always `server_proxy.conf` pointing to wrong IP (e.g. old `116.202.111.107:6007`).

```bash
# Debug: check what IP npm is proxying static assets to
docker exec npm grep -r "116.202.111.107\|6007" /data/nginx/custom/server_proxy.conf /data/nginx/proxy_host/7.conf

# Should show: host.docker.internal:6006
docker exec npm grep "proxy_pass" /data/nginx/custom/server_proxy.conf
```

---

## Git Safety Workflow — ALWAYS BEFORE CHANGES

**Before ANY styling, refactor, or component edit:**

```bash
cd /root/pawnshop

# 1. Commit a save point FIRST
git add -A && git commit -m "chore: save point before [description]"

# 2. Make your changes, build, deploy
pnpm build && docker build -t pawnshop-app:latest . && \
docker rm -f pawnshop-app-1 && docker run -d --name pawnshop-app-1 \
  -p 6006:6006 --restart unless-stopped pawnshop-app:latest

# 3. Smoke test
curl -s -o /dev/null -w "%{http_code}" https://risheng.team.nexeraa.io/

# 4. If broken — test if pre-existing:
git stash && git checkout <save-point-commit> -- . && pnpm build && \
docker rm -f pawnshop-app-1 && docker run -d --name pawnshop-app-1 \
  -p 6006:6006 --restart unless-stopped pawnshop-app:latest
# Test the page — if still broken, bug is pre-existing
# Restore changes:
git stash pop
```

**Revert anytime:** `git reset --hard <save-point-commit>`

## Deploy (fast path)
```bash
cd /root/pawnshop && pnpm build && docker build -t pawnshop-app:latest . && \
docker rm -f pawnshop-app-1 && \
docker run -d --name pawnshop-app-1 -p 6006:6006 --restart unless-stopped pawnshop-app:latest
```

## Current State (2026-04-24)
- **Branch:** `version-2.0` (HEAD: `8017f42` — save point before dark mode fixes)
- **Git ahead:** 4 commits ahead of `origin/version-2.0`
- **Running:** `pawnshop-app-1` on `0.0.0.0:6006->6006/tcp`, Next.js standalone
- **Public URL:** https://risheng.team.nexeraa.io/
- **Admin URL:** https://risheng.team.nexeraa.io/dashboard
- **Admin credentials:** `admin@risheng.com.tw` / `risheng2026`

## Known Pre-existing Issues
- **FAQ crash** (`/faq`) — server-side exception: `HelpCircle` icon passed incorrectly to Client Component. Existed before any dark mode changes. Separate fix needed.

## CtaBanner Dark Mode Gradient

CtaBanner uses `yellow-*` (NOT `primary-*`) for the brand gradient.

**Light mode:** `from-yellow-500 via-yellow-400 to-yellow-600`
**Dark mode:** `from-amber-900 via-amber-700 to-yellow-600`

Dot pattern: `opacity-10 dark:opacity-20` + `fill-black dark:fill-white`

## LandingFooter Dark Mode Fix

`dark:bg-primary-900/10` → `dark:bg-slate-800/40`
Reason: `primary-900` on dark background = near-invisible.

## Build and Deploy (2026-04-24 update)

```bash
# 1. Build
cd /root/pawnshop && pnpm build

# 2. Build Docker image (NOT Dockerfile.prod — use plain Dockerfile)
docker build -t pawnshop-app:latest .

# 3. Restart container with new image
#    CRITICAL: docker compose conflicts with existing standalone container naming.
#    Must rm existing container first, then run fresh.
docker rm -f pawnshop-app-1
docker run -d \
  --name pawnshop-app-1 \
  --restart unless-stopped \
  --env-file /root/pawnshop/.env.production \
  -e NODE_ENV=production \
  -e AUTH_TRUST_HOST=true \
  -p 6006:6006 \
  --network pawnshop_network \
  pawnshop-app:latest

# 4. Wait for health
sleep 35 && docker ps --format "{{.Names}} {{.Image}} {{.Status}}" | grep pawnshop
```

### GHCR Push (if needed)
```bash
# Login first — push WILL fail with "denied" without this
docker login ghcr.io -u USERNAME -t GHP_TOKEN

# Tag and push
docker tag pawnshop-app:latest ghcr.io/aatos-git-collab/pawnshop:latest
docker push ghcr.io/aatos-git-collab/pawnshop:latest
```

### Clean Old Images (free ~25GB)
```bash
# List all pawnshop images
docker images --format "{{.Repository}} {{.Tag}} {{.Size}}" | grep pawnshop

# Remove old/unused images (KEEP: pawnshop-app:latest)
docker rmi \
  pawnshop-hermes-new2:latest \
  pawnshop-hermes-new:latest \
  pawnshop-hermes:latest \
  pawnshop-hermes:v3 \
  pawnshop-ops-hermes:latest \
  pawnshop-ops-public:latest \
  pawnshop-public-new:latest \
  pawnshop-public:latest
```

## Git File Paths with Parentheses
Paths containing parentheses (e.g. `app/(marketing)/about/page.tsx`) must be quoted:
```bash
git show 4da3859:"app/(marketing)/about/page.tsx" > /tmp/about-old.tsx
```

## PageHero Dark/Light Mode (CRITICAL)

PageHero was always dark slate (`from-slate-900`) regardless of mode — looked wrong in light mode (pitch-black block between light page sections = "blue looks out of page in light mode").

**Fix pattern:** Always provide BOTH light AND dark base classes. Do NOT rely solely on `dark:` variants for background — Tailwind applies base classes first, `dark:` only overrides in dark mode.

```tsx
// ✅ CORRECT — dual base classes
className={`bg-gradient-to-br from-slate-50 via-slate-100 to-slate-50 dark:bg-gradient-to-br dark:from-slate-900 dark:via-slate-800 dark:to-slate-900`}

// ❌ WRONG — only dark base, light mode gets nothing useful
className={`bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900`}
```

**Text colors must also dual-class:**

| Element | Light Mode | Dark Mode |
|---------|-----------|-----------|
| Title | `text-slate-900` | `text-white` |
| Badge | `text-yellow-600` | `text-yellow-400` |
| Subtitle | `text-slate-600` | `text-slate-300` |
| Dot pattern | `opacity-10 dark:opacity-10` | same |

**Full correct PageHero pattern:**
```tsx
<section className={`
  w-full py-12 md:py-16 relative overflow-hidden
  bg-gradient-to-br from-slate-50 via-slate-100 to-slate-50
  dark:bg-gradient-to-br dark:from-slate-900 dark:via-slate-800 dark:to-slate-900
`}>
  <div className="absolute inset-0 opacity-10 dark:opacity-10">
    {/* dot pattern SVG */}
  </div>
  <div className="absolute top-0 right-0 w-96 h-96 bg-yellow-500/5 ..." />
  <div className="absolute bottom-0 left-0 w-96 h-96 bg-yellow-600/5 ..." />
  <div className="container-wide px-6 relative z-10">
    <div className="max-w-3xl mx-auto text-center">
      {/* Badge */}
      <span className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full
        bg-yellow-500/10 dark:bg-yellow-500/10
        text-yellow-600 dark:text-yellow-400
        text-sm font-medium mb-6 border border-yellow-500/20">
        {BadgeIcon && <BadgeIcon className="w-4 h-4" />}
        {badge}
      </span>
      {/* Title */}
      <h1 className="text-3xl md:text-4xl lg:text-5xl font-bold text-slate-900 dark:text-white mb-1">
        {title}
      </h1>
      {/* Subtitle */}
      <p className="text-base md:text-lg text-slate-600 dark:text-slate-300">
        {subtitle}
      </p>
    </div>
  </div>
</section>
```

## Page Status (2026-04-24)
| Page | Hero | Badge Icon |
|------|------|-----------|
| `/services` | PageHero + Wrench | ✅ |
| `/shop` | PageHero + ShoppingBag | ✅ |
| `/blog` | PageHero + BookOpen | ✅ |
| `/about` | Original custom hero (reverted) | — |
| `/contact` | PageHero + Phone | ✅ |
| `/faq` | PageHero + HelpCircle | ✅ |

## ⚠️ CRITICAL: Clone Before Styling — Read First!

When user says "make X look like Y" or "use the same style as homepage CTA":
**ALWAYS read the source file FIRST, then copy-paste, then modify.**

❌ WRONG approach (this session's failure):
1. Assume what the existing code looks like
2. Rewrite from memory/assumptions
3. Deploy and get it wrong
4. User corrects → repeat

✅ CORRECT approach:
1. `grep` or read the target page's CTA section code
2. Copy the exact className strings and markup
3. Apply to new component
4. Deploy — matches first time

**This session's failure:** CtaBanner was rewritten with `primary-*` tokens (amber-500 family)
but the homepage uses `yellow-*` tokens (yellow-500 family). I had to be corrected 3 times.
The fix was to read `app/(marketing)/page.tsx` lines 352-390 and clone it exactly.

**When in doubt about brand colors, always check the homepage `(marketing)/page.tsx` first.**

## CtaBanner Exact Spec (source: `(marketing)/page.tsx` lines 352-390)

```tsx
// BACKGROUND
className="w-full py-20 bg-gradient-to-br from-yellow-500 via-yellow-400 to-yellow-600 relative overflow-hidden"

// DOT PATTERN — same opacity BOTH modes
<div className="absolute inset-0 opacity-10 pointer-events-none">
  <div className="absolute inset-0" style={{
    backgroundImage: `url("data:image/svg+xml,...")`
  }} />
</div>

// TITLE — white, bold
<h2 className="text-3xl md:text-4xl lg:text-5xl font-bold text-white mb-6">
  {title}
</h2>

// SUBTITLE — yellow-100
<p className="text-lg text-yellow-100 mb-8">{subtitle}</p>

// BUTTONS — same gap-4, exact same className as homepage
<div className="flex flex-col sm:flex-row gap-4 justify-center">
  {/* LINE button — GREEN */}
  <a href="https://line.me/R/ti/p/~0955678899"
    className="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 h-12 bg-green-500 hover:bg-green-600 text-white text-lg px-8 text-center">
    <MessageCircle className="w-5 h-5 mr-2" />
    LINE線上借款
  </a>
  {/* 0800 button — white border, transparent bg */}
  <a href="tel:0800-789-789"
    className="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 h-12 border border-white text-white hover:bg-white/20 text-lg px-8 bg-transparent text-center">
    <Phone className="w-5 h-5 mr-2" />
    0800-789-789
  </a>
</div>
```

**Brand color key:** `yellow-*` (NOT `primary-*` or `amber-*`) = the brand's CTA/banner color.

## LandingHeader Desktop Positioning

Desktop nav is `sticky top-8` — sits 2rem below the mobile nav's `h-16` fixed bar.

## Blog Newsletter — Uses CtaBanner Clone

Blog page newsletter section at the bottom should use the EXACT same CtaBanner pattern
above, with `title="訂閱最新借貸資訊"`. It does NOT have an email input form — it uses
LINE + 0800 buttons like all other pages.

Backup of current about page: `/tmp/about-page-current-backup.tsx`
Restore with: `cp /tmp/about-page-current-backup.tsx /root/pawnshop/app/\(marketing\)/about/page.tsx`
## Quick Commands
- `skill-load pawnshop-deployment` — Load this skill
