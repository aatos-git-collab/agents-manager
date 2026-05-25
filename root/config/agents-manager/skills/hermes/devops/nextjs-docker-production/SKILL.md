---
name: nextjs-docker-production
description: Next.js production Docker build patterns — standalone output, basePath cookie scope, dead code cleanup, tsconfig collision fixes, and iterative build debugging.
origin: MC Docker spin-up (Aatos CTO)
---

# Next.js Production Docker — Troubleshooting Patterns

## When to Activate

- Next.js `docker compose up` fails during build or runtime
- Cookie/session issues after Docker deployment
- "Dead code" blocking production Webpack compilation
- tsconfig collision between two source trees
- Session cookie not persisting with `basePath` set

---

## 1. Cookie Path Bug with `basePath`

**Symptom:** Login works (curl returns session cookie), browser shows "Login failed" on every attempt. Session never persists — every request appears unauthenticated.

**Root Cause:** Next.js `basePath: '/admin'` means the app lives at `/admin/*`. The session cookie has `Path=/` instead of `Path=/admin`. Browser never sends the cookie to `/admin/*` routes.

**Fix:** Set cookie `path` to match `basePath`:

```typescript
// src/lib/session-cookie.ts
export function getMcSessionCookieOptions(input) {
  return {
    httpOnly: true,
    secure,
    sameSite: 'strict',
    maxAge: input.maxAgeSeconds,
    path: '/admin',  // ← Must match basePath in next.config.js
  }
}
```

**Note:** Do NOT use `process.env.NEXT_PUBLIC_BASE_PATH` — it is NOT automatically set from `next.config.js`'s `basePath` field. Either hardcode it to match, or add `env: { NEXT_PUBLIC_BASE_PATH: '/admin' }` to `next.config.js`.

---

## 2. Dead Code Blocking Production Build

**Symptom:** `docker compose up` fails with TypeScript/Webpack errors on broken imports. npm dev works fine (HMR is lenient).

**Root Cause:** Next.js production builds use Webpack in production mode — strict type checking. Stale directories with broken imports (e.g., `src/hermes/`, `src/app/dashboard/`) from copied codebases cause build failures.

**Pattern: Rename + .dockerignore**

```bash
# DON'T delete — rename to _OLD so you can recover if needed
mv src/hermes src/hermes_OLD
mv src/app/dashboard src/app/dashboard_OLD

# Add to .dockerignore
echo "src/hermes_OLD" >> .dockerignore
echo "src/app/dashboard_OLD" >> .dockerignore
```

**Iterative debugging:** Build fails → find broken import → remove or rename source dir → rebuild. Repeat until clean.

```bash
# Quick check: find files importing non-existent modules
grep -rn "from '@/hermes/components\|from '@hermes/components" src/ --include="*.ts" --include="*.tsx" | grep -v '_OLD'
```

---

## 3. tsconfig Collision Between Two Systems

**Symptom:** TypeScript error: `Module not found: @/lib/migrations/run` but `migrations.ts` exists at `src/lib/migrations.ts`.

**Root Cause:** Two files resolve to the same path when TypeScript walks the `src/lib/` directory:
- `src/lib/migrations.ts` (SQLite, used by `db.ts`)
- `src/lib/db/migrations/run.ts` (PostgreSQL, standalone script)

**Fix:** Exclude the conflicting file in `tsconfig.json`:

```json
{
  "exclude": [
    "node_modules",
    "src/lib/db/migrations/run.ts"
  ]
}
```

**Rule:** When merging two codebases into one Docker image, check for file name collisions across all `src/` subdirectories.

---

## 4. Next.js standalone Output — Port Mismatch

**Symptom:** Container starts but returns 404. `docker logs` shows Next.js listening on port 3000 but `EXPOSE` and `ports:` in compose map to a different port.

**Pattern:**

```yaml
# docker-compose.yml
services:
  app:
    build: .
    ports:
      - "${MC_PORT:-3000}:3000"   # Host:Container — container MUST be 3000
    environment:
      - PORT=3000                  # Next.js internal port
```

```dockerfile
# Dockerfile
EXPOSE 3000
CMD ["node", ".next/standalone/server.js"]
```

```javascript
// next.config.js — standalone output MUST bind to PORT env
output: 'standalone',

// standalone entrypoint in package.json
"start:standalone": "node .next/standalone/server.js"
```

---

## 5. Environment Variables in Docker

**Common mistakes:**
- Using `npm` when project uses `pnpm` (check `package.json` `"packageManager"` field)
- Env vars not in container at build time (docker-compose `env_file:` only at runtime)
- `AUTH_USER`/`AUTH_PASS` seeded on first run but DB volume is fresh each time

```bash
# Verify env vars are in running container
docker exec <container> env | grep AUTH
docker logs <container> | grep "Seeded admin user"
```

**Fix for seeding admin on first run:**
```bash
# Kill old container (with stale volumes)
docker rm -f <container>

# Remove named volumes to get fresh seed
docker volume rm <project>_mc-data

# Or: keep volume, delete the SQLite DB file inside it
docker exec <container> rm /app/.data/mc.db
```

---

## 6. Next.js Production Build Checklist

Before `docker compose up`:

```bash
# 1. Clean all _OLD directories
find src -type d -name "*_OLD" -exec echo "Removing {}" \;

# 2. Verify .dockerignore excludes _OLD dirs
grep "_OLD" .dockerignore || echo "src/hermes_OLD" >> .dockerignore

# 3. Check for tsconfig collisions
grep -r "from.*migrations\|from.*db/migrations" src/ --include="*.ts" | grep -v '_OLD'

# 4. Verify env vars will be available
grep "AUTH_USER\|AUTH_PASS" docker-compose.yml

# 5. Kill any process on the target port
lsof -i :6007 | awk 'NR>1 {print $2}' | xargs kill 2>/dev/null

# 6. Use correct package manager
pnpm --version   # vs npm --version
```

---

## 7. Hot Reload vs Production — Different Behavior

| Issue | npm dev | Docker prod |
|-------|---------|------------|
| Dead import files | ✅ HMR ignores | ❌ Webpack fails |
| Cookie path | Works (no basePath) | Broken (`Path=/`) |
| Missing env vars | Errors at runtime | Silent seed failure |
| Type errors | Warnings | Build fatal |

**Rule:** Always test with `docker compose up` (production build) before declaring success. npm dev masks production-breaking issues.
## Quick Commands
- `skill-load nextjs-docker-production` — Load this skill
