---
name: pawnshop-docker-nextjs-debug
description: Debug stale Docker images and Next.js production servers for the risheng-pawnshop project. Use when static assets return 404 after Docker deploy, or Next.js prod server fails to start.
triggers:
  - "static assets 404 through npm proxy after docker deploy"
  - "next start Could not find a production build"
  - "Docker image has old chunk hashes that don't match actual files"
  - "pnpm serve fails with Invalid project directory"
---

## Root Cause: Pre-rendered HTML has STALE chunk hashes

When Next.js pre-renders HTML (in `.next/server/app/`), it bakes in chunk filenames
like `webpack-1c6ad31b245fbca2.js`. If the Docker image was built from an OLD `.next/`
directory (from a different branch or before a rebuild), the HTML references OLD chunks
that don't exist in the NEW container.

## Symptom: Assets 404 through proxy, but work directly on container port

1. Check what chunks the live HTML references:
```
curl -s http://localhost:6006/ | grep -o 'webpack-[a-f0-9]*.js' | head -3
```

2. Check what chunks actually exist in the container:
```
docker exec <container> ls /app/.next/static/chunks/ | grep webpack | head -5
```

3. If they DON'T match → stale Docker image.

## Solution A: Rebuild Docker image with --no-cache

```
docker build --no-cache -t <image>:latest .
```

## Solution B: Rebuild Next.js then restart container

```
cd /root/pawnshop
pnpm build  # full rebuild with fresh chunk hashes
# then restart container with same image
```

## Next.js Production Server Won't Start

### Error: "Could not find a production build"

Cause: `.next/BUILD_ID` doesn't exist yet (build still running) OR build was to a different directory (branch switch wiped `.next/`).

Check:
```
cat /root/pawnshop/.next/BUILD_ID
ls /root/pawnshop/.next/server/app/
```

Fix:
1. Verify build completed: `pnpm build | tail -20`
2. Wait for BUILD_ID to exist
3. Start server: `node /root/pawnshop/node_modules/.bin/next start -p 6006`

### Error: "Invalid project directory provided / -p"

Cause: `pnpm serve -- -p 6006` — pnpm passes `-p` as project directory arg, not port.

Fix: Use the binary directly:
```
node /root/pawnshop/node_modules/.bin/next start -p 6006
```

### Error: "next: command not found"

Cause: `next` binary not in PATH.

Fix: Always use:
```
node /root/pawnshop/node_modules/.bin/next start -p 6006
```

## Branch Structure (risheng-pawnshop)

| Branch | Status | Admin | Frontend |
|--------|--------|-------|----------|
| main | Old | app/dashboard/ | app/page.tsx (449 lines) |
| hermes-broken | Old | app/dashboard/ (same as main) | app/page.tsx |
| version-2.0 | WORKING | app/dashboard/ | app/(marketing)/ |
| admin-design-system | Saved work | app/admin/ with CSS design | app/(marketing)/ |

## Quick Check: Floating header on current server?

```
curl -s http://localhost:6006/ | grep -o 'nav class="[^"]*"' | grep "\-mb-4\|sticky top-4"
```

- Has `-mb-4 !important` → version-2.0 base (CORRECT)
- Has `sticky top-4` → old main/hermes-broken base (STALE)

## Docker Container Management

```bash
# List all pawnshop containers
docker ps -a --format "{{.Names}} {{.Status}}" | grep pawnshop

# Kill bare-metal Next.js on port 6006
kill $(ss -tlnp | grep 6006 | grep -oP 'pid=\K[0-9]+' | head -1)

# Clean restart sequence
cd /root/pawnshop
pnpm build  # wait for BUILD_ID
node node_modules/.bin/next start -p 6006 &
```

## Relevant Files
- /root/pawnshop/.env — DATABASE_URL, AUTH_SECRET, AUTH_URL
- /root/pawnshop/docker-compose.yml — postgres (5432) + app (6006)
- /root/pawnshop/css/globals.css — admin design system (admin-design-system branch)
- /root/pawnshop/app/(marketing)/layout.tsx — frontend layout with Header (floating `-mb-4 !important`)
- /root/pawnshop/app/dashboard/ — admin panel pages
- /data/nginx/proxy_host/7.conf — npm proxy config

## Pitfalls
- `pnpm build` output goes to the session that ran it — if background, check BUILD_ID
- Branch switch (git checkout) WIPES `.next/` directory — must rebuild after switch
- Docker image caches OLD `.next/` at build time — rebuild with `--no-cache`
- Next.js prod server validates BUILD_ID at startup — can't pre-start before build completes
- pnpm scripts don't pass args correctly for next start — use `node_modules/.bin/` directly
- Killing the process owning port 6006: find PID via `ss -tlnp`, not lsof

## Verification
- Static assets: `curl -s -o /dev/null -w "%{http_code}" http://localhost:6006/_next/static/chunks/webpack-*.js`
- Nav floating: `curl -s http://localhost:6006/ | grep "\-mb-4"`
- Dashboard: `http://localhost:6006/dashboard` → should redirect to login or show dashboard
- Console errors: browser_console tool
## Quick Commands
- `skill-load pawnshop-docker-nextjs-debug` — Load this skill
