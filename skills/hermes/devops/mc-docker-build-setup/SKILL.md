---
name: mc-docker-build-setup
description: Pre-flight checklist and cleanup workflow before Docker production build of Mission Control (MC) at /root/saas/admin. Run BEFORE any docker compose up. MC has pawnshop reference code scattered across multiple directories — all must be removed or Docker build will fail iteratively, one blocker at a time.
category: devops
tags: [docker, nextjs, mission-control, pawnshop, cleanup]
---

# MC Docker Build Setup — Pre-Flight Checklist

## Context

Mission Control (`/root/saas/admin`) was built by copying pawnshop reference code that was never fully adapted. Multiple directories contain broken pawnshop imports that only surface as Docker build errors AFTER previous blockers are removed. **Must clean ALL dead code in one pass.**

MC uses:
- `basePath: '/admin'` — routes are at `/admin/*`
- `output: 'standalone'` — Docker image is self-contained
- Port: `6007` (MC_PORT override)
- SQLite for local MC data (tasks/agents), PostgreSQL for CMS modules

---

## Pre-Build Dead Code Cleanup (One-Time)

Run ALL of these BEFORE `docker compose up`:

### 1. Remove pawnshop page directories

```bash
# These contain broken pawnshop imports (e.g. @hermes/components/* that don't exist in MC)
cd /root/saas/admin/src
[ -d app/dashboard ] && mv app/dashboard app/dashboard_OLD
[ -d hermes ] && mv hermes hermes_OLD
```

### 2. Remove hermes-lib (broken pawnshop auth/db imports)

```bash
cd /root/saas/admin/src
[ -d hermes-lib ] && rm -rf hermes-lib
```

**Why:** `hermes-lib/api-auth.ts` imports `auth` from `@/lib/auth` which doesn't exist in MC. No active code references `@hermes/lib` anywhere, so removal is safe.

### 3. Verify no active imports of dead code namespaces

```bash
# Should return NO matches for these:
grep -r "from '@hermes/components\|from '@hermes/lib\|from '@hermes/hooks\|from '@hermes/types" \
  /root/saas/admin/src --include="*.ts" --include="*.tsx" | grep -v '_OLD'

# Should also confirm no @hermes/store references from active code:
grep -r "from '@hermes/store" /root/saas/admin/src --include="*.ts" --include="*.tsx" | grep -v '_OLD'
```

### 4. Fix tsconfig.json — exclude dead migration runner

The file `src/lib/db/migrations/run.ts` (PostgreSQL migration runner) collides with `src/lib/migrations.ts` (SQLite migrator). TypeScript resolves the directory when `db.ts` imports `./migrations`. Fix:

```json
// In tsconfig.json exclude array:
"exclude": [
  "node_modules",
  "src/lib/db/migrations/run.ts"
]
```

### 5. Update .dockerignore

Add `_OLD` directories so Docker build doesn't copy dead pawnshop code:

```
node_modules
.git
.data
.next
.env
*.md
.github
ops
scripts/*
src/hermes_OLD
src/app/dashboard_OLD
```

---

## Docker Build Command

```bash
cd /root/saas/admin

# Kill any process on port 6007 first
kill $(lsof -t -i:6007 2>/dev/null) 2>/dev/null || true
sleep 2

# Rebuild and start
MC_PORT=6007 docker compose up -d mission-control

# Wait for container to start
sleep 15

# Verify
docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}" | grep mission
curl -s -o /dev/null -w "%{http_code}" http://localhost:6007/admin
```

Expected output:
```
mission-control  0.0.0.0:6007->3000/tcp  Up N seconds (health: starting)
200
```

---

## Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `@hermes/components/*` not found | `src/hermes/` or `src/app/dashboard/` dead code | mv to `_OLD` dirs |
| `@/lib/auth` not found in `api-auth.ts` | `hermes-lib/api-auth.ts` broken import | `rm -rf hermes-lib` |
| `migrations/run.ts` type error | tsconfig collision SQLite vs PostgreSQL migrations | Exclude in tsconfig.json |
| Port 6007 already in use | npm dev server still running | `kill $(lsof -t -i:6007)` |
| "address already in use" on docker run | Previous container didn't release port | `docker rm -f mission-control` then retry |

---

## Verification

After successful build, browser should show:
- URL: `http://localhost:6007/admin`
- Title: "Mission Control — AI Agent Orchestration Dashboard"
- NavRail: Overview, Agents, Tasks, Team, Activity, More
- Content: Launch Sequence wizard (first-run state) OR dashboard if configured

---

## Related Skills

- **`mc-dev-npm-proxy`** — MC dev server (pnpm) + NPM OpenResty proxy setup. Covers hostname binding, OpenResty reload, cookie path, login API fixes, and docker0 bridge troubleshooting. Use for iteration before Docker production build.

---

## Troubleshooting

**"unhealthy" container status:** Cosmetic — docker-compose has no HEALTHCHECK defined. App is running fine if curl returns 200.

**WS errors in UI:** Expected — no gateway configured. MC runs in "Local Mode" without a gateway.

**Wizard blocking dashboard:** The Launch Sequence shows on first run. To skip, either complete the 3-step wizard or check if MC has a `SKIP_WIZARD` env var or config flag.
## Quick Commands
- `skill-load mc-docker-build-setup` — Load this skill
