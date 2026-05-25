---
name: webbuilder-cto
description: webbuilder-cto skill
  CTO operating manual for the AI WebBuilder project. Single source of truth for
  architecture, workflow standards, and implementation priorities.
version: 1.2.0
category: webbuilder
---

# WebBuilder CTO Operating Manual

## Architecture (immutable — do not revisit)

```
User → SaaS Frontend (React+Vite) → API (Fastify) → Worker (job queue)
                                     ↓
                           Docker-in-Docker (dind)
                                     ↓
                           vibe-starter container per project
                                     ↓
                           Traefik → preview URL per project
```

**Key decisions (do not revisit without flagging):**
- vibe-starter as base image — files copied into `/workspace/projects/{projectId}/`
- Per-file JSON Patch (RFC 6902) stored in PostgreSQL `code_diffs.diff_json` (JSONB)
- Worker is separate process from API, scaled independently via `deploy.replicas`
- **ALL tests run inside Docker** — nothing runs locally: `docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml up`
- Secrets via environment variables only, never in code
- `container_name` is FORBIDDEN on any service using `deploy.replicas`

## Priority order (always)

1. Does it compile/build? (verify first)
2. Does it pass tests? (Docker-only)
3. Is schema.sql updated before source, not after?
4. Is it documented? (no README update = not done)

## The Verification Loop (NEVER skip)

```
Agent produces → Leader verifies → If broken → Send errors BACK to agent
→ They fix → Verify again → Repeat until ALL checks pass
→ ONLY THEN mark complete and close session
```

**Leader is COORDINATOR, never implementer.** Only exception: agent explicitly cannot resolve and escalates.

```bash
# When build fails after agent delivers:
# BAD:  leader fixes the code directly
# GOOD: aatosteam inbox send webbuilder <agent> "<error output> — fix and resubmit"
```

**Verification phases (in order, never skip):**
1. Build — `pnpm build` (backend & frontend, both exit 0)
2. Compose validation — `docker compose config --quiet`
3. Docker test — `docker compose -f infra/docker-compose.test.yml up --build test`
4. E2E/Playwright — browser tests inside Docker
5. CI/CD — GitHub Actions workflows valid
6. UX — browser snapshot + console check

See skill: `verification-loop` for full checklist.

## Docker compose rules

- NEVER use `container_name` on a service with `deploy.replicas` (causes conflict)
- `version:` key is obsolete — remove from all compose files
- `volumes:` under a service must be a YAML list: `- volume-name:/path` not `volume-name:/path`
- Volumes defined at bottom of compose must match: `volumes: { name: }` not top-level shorthand
- The `dind` service must exist in base compose if prod overlay references it
- Healthchecks use `curl -f` for HTTP or `pg_isready` for postgres — exit 0/1 only

## Docker-in-Docker
- Connect: `DOCKER_HOST=tcp://dind:2376`, TLS certs from `DOCKER_TLS_CERTDIR=/certs`
- All Docker operations from API/worker go through dind — never the host socket
- Build command must use `sg docker -c "docker build ..."` when user is in docker group but shell hasn't picked up new group

## vibe-starter Dockerfile rules
- For **dev base image**: just needs `pnpm install` + source + `pnpm dev`
- Do NOT try to `pnpm build` in the Dockerfile — that's a developer's action
- Do NOT use `|| true` on build commands — let them fail so we see the error
- Use `RUN pnpm dev &` or a proper dev server for the HEALTHCHECK
- Single stage is fine for dev base, multi-stage only if doing production build
- **Docker builds: always `--no-frozen-lockfile`** — lockfiles mismatch between envs
- **Local dev: always `--frozen-lockfile`** — CI default, catches dep drift

## Test command (Docker-only)
```bash
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml up --build test
```

## Agent spawn template (webbuilder team)
```bash
aatosteam spawn --team webbuilder --agent-name <role> --task "<goal>" --skip-permissions
```
Roles: backend-dev, frontend-dev, infra-ops

## Skills hierarchy
```
~/.hermes/skills/
  webbuilder-cto.md          ← this file (architecture decisions)
  webbuilder-backend.md      ← backend patterns (DB, API, worker)
  webbuilder-infra.md        ← infra patterns (Docker, Traefik)
  webbuilder-frontend.md     ← frontend patterns (React, Vite)
  verification-loop/          ← full verification protocol
    SKILL.md
    references/
      e2e-checklist.md
      ci-cd-checklist.md
      ux-checklist.md
    scripts/
      run-e2e.sh
      run-tests.sh
      verify-all.sh
```

## Discovering a better approach
When you find a better pattern: `skill_manage(action='patch', name='<skill>', old_string='...', new_string='...')`

## Quick Commands
- `skill-load webbuilder-cto` — Load this skill
