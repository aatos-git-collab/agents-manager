---
name: mc-docker-build-debug
description: Debug Docker production build failures on Next.js/Mission Control projects where npm dev works fine but Docker build fails due to dead pawnshop reference code.
category: devops
tags: [docker, nextjs, mission-control, build-debug]
created: 2026-04-28
---

# MC Docker Build Debug Skill

## Trigger
Docker production build fails on a Next.js/MC project that works fine with `npm run dev`.

## Root Cause Pattern
npm dev (Next.js HMR/Turbopack) is **lenient** — it skips type-checking broken imports and compiles what it can.
Docker production build uses **Webpack production mode** with full TypeScript type-checking → fails on the first broken import.

This means: dead reference code that "works" in dev can silently block production Docker builds.

## Common Dead Code Locations (MC/pawnshop)
| Directory | Files | Symptom |
|-----------|-------|---------|
| `src/hermes_OLD/` | 109+ | Broken `@hermes/components/*` imports (pawnshop Chinese content) |
| `src/app/dashboard_OLD/` | 27+ | Same pattern — pawnshop pages |
| `src/hermes-lib/` | ~20 | Imports non-existent `@/lib/auth` → TS error |
| `db/migrations/run.ts` | 1 | Module collision with `migrations.ts` — both resolve to `./migrations` |

## Fix Sequence (in order)

### Step 1: Move dead dirs to `_OLD`
```bash
cd /root/saas/admin/src
mv hermes hermes_OLD
mv app/dashboard app/dashboard_OLD
rm -rf hermes-lib   # verify no active imports first
```

### Step 2: Verify no active imports remain
```bash
grep -r "from '@hermes/lib\|from '@hermes/hooks\|from '@hermes/types\|from '@hermes/store\|from '@hermes/components" \
  /root/saas/admin/src \
  --include="*.ts" --include="*.tsx" \
  | grep -v '_OLD'
```
Must return empty before proceeding.

### Step 3: Exclude TypeScript module collision
If `db/migrations/run.ts` collides with `lib/migrations.ts`:
```json
// tsconfig.json exclude
"exclude": ["node_modules", "src/lib/db/migrations/run.ts"]
```

### Step 4: Update .dockerignore
```dockerignore
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

### Step 5: Rebuild Docker
```bash
cd /root/saas/admin
docker compose build mission-control   # or: docker compose up --build -d mission-control
```

### Step 6: Start container (compose may not start it)
```bash
docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep mission
# If "Created" not "Up": docker start mission-control
docker start mission-control
sleep 15
curl -s -o /dev/null -w "%{http_code}" http://localhost:6007/admin
# Expected: 200
```

## Port Conflict: npm dev vs Docker
- Both npm dev and Docker want port 6007 → conflict
- Docker is authoritative for production → kill npm dev:
  ```bash
  kill $(lsof -t -i:6007 -i:3000 2>/dev/null)
  docker start mission-control
  ```

## Verification
- `curl http://localhost:6007/admin` → 200 ✅
- `docker ps | grep mission-control` → `Up X seconds` ✅
- "Unhealthy" status = cosmetic (no HEALTHCHECK configured in docker-compose; app is fine)
## Quick Commands
- `skill-load mc-docker-build-debug` — Load this skill
