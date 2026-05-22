---
name: mc-dev-npm-proxy
description: Set up Next.js dev servers and Docker containers behind NPM (OpenResty) proxy. Covers hostname binding, OpenResty reload, cookie paths, login auth, proxy_pass trailing-slash redirect loops, and NPM access log analysis.
category: devops
tags: [nextjs, openresty, nginx, mission-control, docker, proxy]
---

# MC Dev + NPM Proxy Setup

## Overview

MC dev at `/root/saas/admin` runs on port 6007. The NPM container (OpenResty) proxies `admin.team.nexeraa.io` to it. This skill covers the full setup pipeline.

---

## Architecture

```
INTERNAL (from npm container):
Browser → admin.team.nexeraa.io → NPM container (OpenResty) → host.docker.internal:6007 → MC pnpm dev (0.0.0.0:6007)

EXTERNAL DIRECT ACCESS (dev server):
Browser → http://116.202.111.107:6007 → Host port 6007 → pnpm dev (0.0.0.0:6007)

EXTERNAL PUBLIC URL (broken — external proxy can't reach Docker internal):
Browser → https://admin.team.nexeraa.io → 116.202.111.107 (external proxy) → 502 (can't reach host.docker.internal)
```

**Key insight:** The dev server on `0.0.0.0:6007` is reachable externally via the host's port 6007 directly. The NPM container on `mc-bridge-net` proxies internal traffic via `host.docker.internal`. Both work, but the public DNS routes through a separate external proxy that can't reach Docker internal.

- NPM container name: `npm` (verify with `docker ps` — there may be multiple)
- NPM ports: 80/443 (OpenResty) — the traffic handler
- `host.docker.internal` from npm container → `172.17.0.1` (Docker bridge gateway)
- MC dev must bind to `0.0.0.0` (not `127.0.0.1`) to receive from docker0
- saas-mc Docker container needs `mc-bridge-net` to be reachable from npm container

---

## Step 1 — Fix package.json Hostname

**Problem:** `next dev` ignores `HOST`/`HOSTNAME`/`PORT` environment variables. The CLI flag `--hostname` is the only way.

```bash
# Check current dev script
grep -n "\"dev\"" /root/saas/admin/package.json

# Patch line 12: --hostname 127.0.0.1 → --hostname 0.0.0.0
sed -i 's/--hostname 127\.0\.0\.1/--hostname 0.0.0.0/' /root/saas/admin/package.json
```

**Why:** NPM container reaches MC via `host.docker.internal` → `172.17.0.1` → docker0. If MC binds to `127.0.0.1`, docker0 can't reach it.

---

## Step 2 — Update NPM Proxy Config

The proxy config lives INSIDE the npm container at `/data/nginx/proxy_host/8.conf`.

```bash
# View current config
docker exec npm cat /data/nginx/proxy_host/8.conf

# Update the backend server directive
# Change: set $server "116.202.111.107" → set $server "host.docker.internal"
docker exec npm sed -i 's/set \$server "[^"]*"/set $server "host.docker.internal"/' /data/nginx/proxy_host/8.conf
```

**Why:** Old IP was external server. `host.docker.internal` resolves from inside the npm container to `172.17.0.1`, reaching the host machine where MC dev runs.

---

## Step 3 — Reload OpenResty (NOT nginx)

**Problem:** The container runs OpenResty, not plain nginx. `nginx -s reload` inside the container doesn't work the same way.

```bash
# Option A: Signal reload (preferred)
docker kill -s HUP npm

# Option B: Exec reload
docker exec npm nginx -s reload

# Option C: Full restart (ifreload fails)
docker restart npm
```

**Verify:**
```bash
docker exec npm curl -s http://host.docker.internal:6007/admin/api/auth/login \
  -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
# Should return: {"user":{"id":1,"username":"admin"...}}
```

---

## Step 4 — Ensure docker0 Bridge is UP

**Problem:** docker0 bridge can go `linkdown` after Docker daemon restart, breaking `host.docker.internal`.

```bash
# Check docker0 state
ip link show docker0

# If state is DOWN:
ip link set docker0 up

# If it has NO-CARRIER:
# Restart Docker daemon
sudo systemctl restart docker
sleep 5
ip link show docker0  # should show UP
```

**MC dev on `0.0.0.0` survives docker0 fluctuations** — it binds to all interfaces, not just docker0.

---

## Step 5 — Start MC Dev Server

```bash
# Kill any existing process on port 6007
fuser -k 6007/tcp 2>/dev/null || true
sleep 2

# Start MC dev
cd /root/saas/admin && PORT=6007 pnpm dev

# OR with explicit hostname (if package.json not patched):
cd /root/saas/admin && pnpm -- --hostname 0.0.0.0 --port 6007
```

**Verify local:**
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:6007/admin/
# Expected: 308 (redirect) — normal for basePath='/admin'

curl -s -o /dev/null -w "%{http_code}" http://localhost:6007/admin/api/auth/login \
  -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}'
# Expected: 200
```

**Verify public:**
```bash
curl -s -o /dev/null -w "%{http_code}" https://admin.team.nexeraa.io/admin/api/auth/login \
  -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}'
# Expected: 200
```

---

## Common Fixes

### MC Login Returns 404 from NPM
**Cause:** `package.json` still has `--hostname 127.0.0.1`, or npm proxy points to wrong IP.
**Fix:** Patch package.json + update NPM config + reload OpenResty.

### Login Works via curl but Browser 502
**Cause:** Cookie `Path=/` instead of `Path=/admin`. Browser doesn't send cookie to MC because basePath mismatch.
**Fix:** In `src/lib/session-cookie.ts`, set `path: '/admin'` (was `path: '/'`).

### Login API 400 on Browser Submit
**Cause:** Browser HTML forms submit `application/x-www-form-urlencoded`, not `application/json`.
**Fix:** In `src/app/api/auth/login/route.ts`, support both:
```ts
// Check Content-Type header
const isForm = request.headers.get('content-type')?.includes('application/x-www-form-urlencoded');
if (isForm) {
  const formData = await request.formData();
  username = formData.get('username') as string;
  password = formData.get('password') as string;
} else {
  body = await request.json();
}
```

### Two NPM Containers — Target the RIGHT One
**Problem:** There are TWO npm containers on this host:
- `npm` (ports 80/443 → `10.201.0.2`) — **actual traffic handler** — on `mc-bridge-net`
- Another npm container (port 3050) — config edits there have no effect on traffic

**How to identify which is which:**
```bash
# Shows both containers — find the one handling port 80/443
docker ps --format "{{.Names}}\t{{.Ports}}" | grep npm

# Traffic npm has these ports mapped:
# 0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp

# Test which container is live:
docker exec npm curl -sf http://host.docker.internal:6007/admin/api/status?action=health
# If 200 → it's the traffic npm. If fails → try the other container.
```

**Rule:** Always use `docker exec npm` — Docker will route to the running container named `npm`. But if two exist with the same name, Docker uses the one created first. Use `docker ps --format "{{.Names}}\t{{.Created}}" | grep npm` to identify which was created later (that's the one you want to edit).

### External DNS 502 — admin.team.nexeraa.io Returns 502 but :6007 Works
**Problem:** `https://admin.team.nexeraa.io` → 502, but `http://116.202.111.107:6007` → 200 OK.

**Root Cause:** `admin.team.nexeraa.io` resolves to `116.202.111.107` which is an **external proxy/nginx outside the Docker host** — it cannot reach `host.docker.internal` (Docker's internal DNS). Meanwhile `116.202.111.107:6007` works because it's the **host machine's direct port** where the dev server binds to `0.0.0.0`.

**Diagnosis:**
```bash
# Both of these return 200 — confirm it's a DNS/proxy routing issue
curl -s -o /dev/null -w "%{http_code}" http://116.202.111.107:6007/admin/api/status?action=health
curl -s -o /dev/null -w "%{http_code}" https://admin.team.nexeraa.io/admin/api/status?action=health

# The second returns 502 → external proxy can't reach host.docker.internal
```

**Fix Options:**
1. **Best:** Change `admin.team.nexeraa.io` DNS A record to point directly to the Docker host IP, so external traffic reaches the npm container on `mc-bridge-net` which CAN reach `host.docker.internal:6007`
2. **Alternative:** Configure the external proxy at `116.202.111.107` to forward `admin.team.nexeraa.io` requests to `116.202.111.107:6007` (the host port where the dev server listens)
3. **Quick test:** Temporarily access via `http://116.202.111.107:6007` directly (works, but not on port 443)

### Dev Server (6007) Works Externally — Why
**Finding:** `http://116.202.111.107:6007` is accessible externally because:
1. The dev server binds to `0.0.0.0:6007` (all interfaces, not just localhost)
2. The host machine has port 6007 open and NAT-ed to the outside world
3. Traffic: External → Host IP:6007 → directly to the pnpm dev process

This is NOT Docker routing — it's a host-level port. The dev server is running as a native process, not inside a container.

### saas-mc Docker Container — Network Isolation
**Problem:** `saas-mc` container (port 6010) is NOT reachable via `host.docker.internal` from the npm container.
**Cause:** `saas-mc` is only on its own `saas-net` bridge, not on `mc-bridge-net`.
**Fix:** Connect it to `mc-bridge-net`:
```bash
docker network connect mc-bridge-net saas-mc
```
Or update docker-compose.yml to include `mc-bridge-net` in the container's networks list.

### All Containers Down / docker0 Linkdown
**Cause:** Docker daemon recreates docker0 in DOWN state after restart.
**Fix:**
```bash
sudo systemctl restart docker
sleep 5
ip link set docker0 up
# Then restart MC dev
```

### pkill Leaves Orphaned Next.js Processes
**Cause:** `pkill -f "next dev"` matches broadly.
**Fix:** Use port-based kill instead:
```bash
fuser -k 6007/tcp 2>/dev/null
# OR
kill $(lsof -t -i:6007)
```

---

## Critical Bug: proxy_pass Trailing Slash Causes Redirect Loop

**Symptom:** A Next.js route (e.g. `/admin`) works perfectly when accessed directly (`curl http://host:6007/admin` → 302) but returns **308 with no Location header** when accessed through the NPM domain proxy.

**Root Cause:** Nginx `proxy_pass` with a **trailing slash** strips the matched prefix from the URI.

```nginx
# WRONG — strips /admin from URI, forwards / instead
location /admin {
    proxy_pass http://116.202.111.107:6007/admin/;   # ← TRAILING SLASH
}

# RIGHT — forwards /admin as-is
location /admin {
    proxy_pass http://116.202.111.107:6007/admin;    # ← NO TRAILING SLASH
}
```

With the trailing slash, nginx receives `/admin` → matches `location /admin` → **strips `/admin`** → forwards `/` to upstream. Next.js receives `/` (not `/admin`), applies its own canonical URL redirect (308 `/admin` → `/admin`), which returns a 308 with `location: /admin` relative to the upstream — causing a loop.

**Diagnosis steps:**
1. `curl -sv http://localhost:6007/admin` — works (302 + Location header) ✅
2. `curl -sv https://your.domain/admin` — 308 but no Location or wrong Location ❌
3. `docker exec npm curl -sv http://<upstream>:6007/admin/` — confirms the trailing-slash stripping
4. Check npm access log: `docker exec npm tail /data/logs/proxy-host-N_access.log`
   - 16-byte 308 body = Next.js's own "Not Found" response
   - 0-byte responses = empty upstream responses

**Fix:**
```bash
# Remove trailing slashes from proxy_pass directives
docker exec npm sh -c "
  sed -i 's|proxy_pass.*6007/admin/;|proxy_pass http://<upstream>:6007/admin;|g' /data/nginx/proxy_host/N.conf
  sed -i 's|proxy_pass.*6007/api/;|proxy_pass http://<upstream>:6007/api;|g' /data/nginx/proxy_host/N.conf
"
docker exec npm nginx -s reload
```

**Rule:** When proxying to a Next.js app at a specific path (like `/admin`), NEVER use a trailing slash in `proxy_pass`. The `location` directive does the prefix matching — `proxy_pass` should end at the path without stripping.

---

## NPM Access Log Analysis

NPM (OpenResty) access logs are gold for diagnosing proxy issues:
```bash
# Recent requests for a specific host
docker exec npm tail -30 /data/logs/proxy-host-7_access.log

# Errors only
docker exec npm tail -10 /data/logs/proxy-host-7_error.log
```

Log format: `[timestamp] - STATUS CODE STATUS - METHOD PROTOCOL DOMAIN "REQUEST" [Client IP] [Length] [Gzip] [Sent-to upstream] "User-Agent" "Referrer"`

Key patterns:
- `404 404` + 19 bytes = Next.js chunk 404 (asset not in build)
- `308 308` + 16 bytes = Next.js redirect loop (likely trailing-slash proxy_pass bug)
- `502 502` = upstream unreachable (wrong IP, port down, network隔离)
- `304 304` = static asset cached, working correctly

To find the right proxy host conf ID:
```bash
docker exec npm sh -c "grep -l 'your-domain.com' /data/nginx/proxy_host/*.conf"
```

---

## Redirect Tracing Method (Always Do This First)

When a route behaves differently through the proxy vs direct:

```bash
# Step 1: Direct to upstream (should show real behavior)
curl -sv http://localhost:6007/admin 2>&1 | grep -E "< HTTP|< Location"

# Step 2: Through NPM domain (compare headers)
curl -sv https://your.domain/admin 2>&1 | grep -E "< HTTP|< Location|< Server"

# Step 3: From inside NPM container directly (bypasses any host-level proxy)
docker exec npm curl -sv http://<upstream_ip>:6007/admin 2>&1 | grep -E "< HTTP|< Location"

# Step 4: With X-Forwarded headers (simulate NPM proxy headers)
curl -sv -H "Host: your.domain" \
  -H "X-Forwarded-Proto: https" \
  -H "X-Real-IP: 10.201.0.2" \
  http://localhost:6007/admin 2>&1 | grep -E "< HTTP|< Location"
```

If Step 1 ✅ but Step 2 ❌ → problem is in NPM proxy config
If Step 3 ❌ → upstream itself has an issue
If Step 1 matches Step 3 → NPM is modifying the response

---

## Troubleshooting Checklist

```bash
# 1. Is port 6007 listening on 0.0.0.0?
ss -tlnp | grep 6007

# 2. Can npm container reach it?
docker exec npm curl -s -o /dev/null -w "%{http_code}" http://host.docker.internal:6007/admin/api/auth/login

# 3. Is docker0 UP?
ip link show docker0

# 4. Is NPM config updated? (check for TRAILING SLASH bug)
docker exec npm grep "proxy_pass" /data/nginx/proxy_host/7.conf

# 5. Did OpenResty reload?
docker exec npm nginx -t  # syntax check

# 6. Check access log for recent requests
docker exec npm tail -20 /data/logs/proxy-host-7_access.log

# 7. Find which proxy host config serves your domain
docker exec npm sh -c "grep -l 'your-domain.com' /data/nginx/proxy_host/*.conf"
```

---

## Key Files

| File | Purpose |
|------|---------|
| `/root/saas/admin/package.json` | Must use `--hostname 0.0.0.0` |
| `/root/saas/admin/src/lib/session-cookie.ts` | Cookie `path: '/admin'` |
| `/root/saas/admin/src/app/api/auth/login/route.ts` | JSON + form support |
| `/root/saas/admin/.env` | `DATABASE_URL`, `SESSION_SECRET`, `ADMIN_USER/PASS` |
| `/root/saas/admin/docker-compose.yml` | Container: `mc-bridge-net` network required |
| `/data/nginx/proxy_host/N.conf` | NPM proxy config (inside **traffic** npm container) — NO trailing slash on proxy_pass |

## Verified Working Access

| URL | Status | Notes |
|-----|--------|-------|
| `http://116.202.111.107:6007` | ✅ 200 | Host port directly to dev server |
| `http://localhost:6007` | ✅ 200 | Local access |
| `https://admin.team.nexeraa.io` | ❌ 502 | External DNS → external proxy can't reach Docker internal |
| NPM container → `host.docker.internal:6007` | ✅ 200 | Internal Docker routing works |
| `saas-mc` container (6010) | ⚠️ Unreachable | Not on `mc-bridge-net` |

---

## Common Fixes

### MC Login Returns 404 from NPM
**Cause:** `package.json` still has `--hostname 127.0.0.1`, or npm proxy points to wrong IP.
**Fix:** Patch package.json + update NPM config + reload OpenResty.

### Login Works via curl but Browser 502
**Cause:** Cookie `Path=/` instead of `Path=/admin`. Browser doesn't send cookie to MC because basePath mismatch.
**Fix:** In `src/lib/session-cookie.ts`, set `path: '/admin'` (was `path: '/'`).

### Login API 400 on Browser Submit
**Cause:** Browser HTML forms submit `application/x-www-form-urlencoded`, not `application/json`.
**Fix:** In `src/app/api/auth/login/route.ts`, support both:
```ts
const isForm = request.headers.get('content-type')?.includes('application/x-www-form-urlencoded');
if (isForm) {
  const formData = await request.formData();
  username = formData.get('username') as string;
  password = formData.get('password') as string;
} else {
  body = await request.json();
}
```

### Two NPM Containers — Target the RIGHT One
**Problem:** There are TWO npm containers on this host:
- `npm` (ports 80/443 → `10.201.0.2`) — **actual traffic handler** — on `mc-bridge-net`
- Another npm container (port 3050) — config edits there have no effect on traffic

**How to identify which is which:**
```bash
docker ps --format "{{.Names}}\t{{.Ports}}" | grep npm
# Traffic npm has: 0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp

docker exec npm curl -sf http://host.docker.internal:6007/admin/api/status?action=health
# If 200 → it's the traffic npm. If fails → try the other container.
```

**Rule:** Always verify you're editing the traffic npm's config:
```bash
docker exec npm sh -c "grep -l 'your-domain.com' /data/nginx/proxy_host/*.conf"
```

### External DNS 502 — admin.team.nexeraa.io Returns 502 but :6007 Works
**Problem:** External proxy at `116.202.111.107` cannot reach `host.docker.internal`.

**Fix Options:**
1. **Best:** Change DNS A record to point directly to Docker host so npm on `mc-bridge-net` handles it
2. **Alternative:** External proxy forwards to `116.202.111.107:6007` (host port)
3. **Quick test:** `http://116.202.111.107:6007` directly (works, no SSL)

### saas-mc Docker Container — Network Isolation
**Problem:** `saas-mc` container is NOT reachable via `host.docker.internal` from the npm container.
**Fix:**
```bash
docker network connect mc-bridge-net saas-mc
```

### All Containers Down / docker0 Linkdown
**Cause:** Docker daemon recreates docker0 in DOWN state after restart.
**Fix:**
```bash
sudo systemctl restart docker
sleep 5
ip link set docker0 up
```

### pkill Leaves Orphaned Next.js Processes
**Fix:** Use port-based kill:
```bash
fuser -k 6007/tcp 2>/dev/null
```
## Quick Commands
- `skill-load mc-dev-npm-proxy` — Load this skill
