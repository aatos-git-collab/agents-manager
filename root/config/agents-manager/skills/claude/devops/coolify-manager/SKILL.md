---
name: coolify-manager
description: Coolify API reference — all operations, dev workflow, and troubleshooting in one place. Check /root/.hermes/skills/devops/coolify-manager/scripts/functions.sh for reusable bash functions.
---

# Coolify Manager — Consolidated Reference

## Connection Setup

```bash
# 1. Check if env vars are already set
echo "$COOLIFY_MASTER_URL"
echo "$COOLIFY_TOKEN"

# 2. If not set, set them before any API call:
export COOLIFY_MASTER_URL="https://your-coolify-domain.com"   # ASK USER or check /data/coolify/source/.env
export COOLIFY_TOKEN="your-token-from-settings"                # Settings → Keys & Tokens → API Tokens
AUTH_HEADER="Authorization: Bearer $COOLIFY_TOKEN"
BASE_URL="${COOLIFY_MASTER_URL}/api/v1"

# 3. Verify connection
curl "$BASE_URL/health"
```

**Auth format:** `Authorization: Bearer <token>`
**Token source:** Settings → Keys & Tokens → API Tokens (create new, copy immediately — shown once only)
**No-auth endpoints:** `/health`, `/feedback`, `/v1`

---

## Authorization — Common Errors

| Response | Meaning |
|----------|---------|
| `{"message":"Unauthenticated."}` | Token invalid, expired, or wrong format |
| `{"message":"Not found.","docs":"https://coolify.io/docs"}` | Auth passed, endpoint doesn't exist |
| `{"OK"}` (plain text) | Health endpoint — no auth needed |

**Token format issues:**
- Looks like `1|AW03...` or `AW03...cba2` → **Laravel encrypted cookie — WILL NOT WORK**
- Must be a token generated from Settings → Keys & Tokens → API Tokens

---

## Get Started — First Steps

```bash
# Health check (no auth needed)
curl "$BASE_URL/health"

# List all resources
curl "$BASE_URL/resources" -H "$AUTH_HEADER"

# List servers — get server UUID
curl "$BASE_URL/servers" -H "$AUTH_HEADER"

# List projects — get project UUID
curl "$BASE_URL/projects" -H "$AUTH_HEADER"

# Get project details (includes environment UUIDs)
curl "$BASE_URL/projects/$PROJECT_UUID" -H "$AUTH_HEADER"
```

---

## Applications

### Deploy from Public Git
```bash
curl -X POST "$BASE_URL/applications/public" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "project_uuid": "'"$PROJECT_UUID"'",
    "environment_uuid": "'"$ENV_UUID"'",
    "git_repository": "owner/repo",
    "git_branch": "main",
    "build_pack": "nixpacks",
    "port": 3000
  }'
```

### Deploy from Dockerfile
```bash
curl -X POST "$BASE_URL/applications/dockerfile" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-docker-app",
    "project_uuid": "'"$PROJECT_UUID"'",
    "environment_uuid": "'"$ENV_UUID"'",
    "git_repository": "owner/repo",
    "dockerfile": "Dockerfile"
  }'
```

### Deploy from Docker Compose (base64 encoded)
```bash
COMPOSE=$(echo "services:
  app:
    image: nginx:latest
    ports:
      - '8080:80'" | base64 -w 0)

curl -X POST "$BASE_URL/services" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-compose-app",
    "docker_compose_raw": "'"$COMPOSE"'",
    "server_uuid": "'"$SERVER_UUID"'",
    "project_uuid": "'"$PROJECT_UUID"'",
    "environment_uuid": "'"$ENV_UUID"'"
  }'
```

### Application Lifecycle
```bash
# Get status
curl "$BASE_URL/applications/$UUID" -H "$AUTH_HEADER"

# Get logs
curl "$BASE_URL/applications/$UUID/logs" -H "$AUTH_HEADER"

# Start / Stop / Restart
curl "$BASE_URL/applications/$UUID/start" -H "$AUTH_HEADER"
curl "$BASE_URL/applications/$UUID/stop" -H "$AUTH_HEADER"
curl "$BASE_URL/applications/$UUID/restart" -H "$AUTH_HEADER"
```

### Environment Variables
```bash
# Add env var
curl -X POST "$BASE_URL/applications/$UUID/envs" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"key": "DATABASE_URL", "value": "postgres://...", "is_build_time": false}'

# Bulk update
curl -X PATCH "$BASE_URL/applications/$UUID/envs/bulk" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"envs": [{"key": "NODE_ENV", "value": "production"}]}'

# List all envs
curl "$BASE_URL/applications/$UUID/envs" -H "$AUTH_HEADER"
```

---

## Databases

```bash
# Create PostgreSQL
curl -X POST "$BASE_URL/databases/postgresql" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-db",
    "project_uuid": "'"$PROJECT_UUID"'",
    "environment_uuid": "'"$ENV_UUID"'",
    "postgres_version": "15"
  }'

# Create Redis / MySQL / MariaDB / MongoDB
curl -X POST "$BASE_URL/databases/redis" ...
curl -X POST "$BASE_URL/databases/mysql" ...

# Backup
curl -X POST "$BASE_URL/databases/$UUID/backups" -H "$AUTH_HEADER"
```

---

## Servers

```bash
# List servers
curl "$BASE_URL/servers" -H "$AUTH_HEADER"

# Add server
curl -X POST "$BASE_URL/servers" ...

# Get server details
curl "$BASE_URL/servers/$UUID" -H "$AUTH_HEADER"
```

---

## Projects

```bash
# List projects
curl "$BASE_URL/projects" -H "$AUTH_HEADER"

# Create project
curl -X POST "$BASE_URL/projects" ...

# Get project + environment UUIDs
curl "$BASE_URL/projects/$PROJECT_UUID" -H "$AUTH_HEADER"
```

---

## Deployments

```bash
# List deployments
curl "$BASE_URL/deployments" -H "$AUTH_HEADER"

# Get deployment status
curl "$BASE_URL/deployments/$UUID" -H "$AUTH_HEADER"
```

---

## Service Lifecycle

```bash
curl -X POST "$BASE_URL/services/$SERVICE_UUID/start" -H "$AUTH_HEADER"
curl -X POST "$BASE_URL/services/$SERVICE_UUID/stop" -H "$AUTH_HEADER"
curl -X POST "$BASE_URL/services/$SERVICE_UUID/restart" -H "$AUTH_HEADER"
curl -X DELETE "$BASE_URL/services/$SERVICE_UUID" -H "$AUTH_HEADER"
```

---

## Bash Helper Functions

Source from: `scripts/functions.sh`

```bash
source /root/.hermes/skills/devops/coolify-manager/scripts/functions.sh

coolify_get_resources
coolify_get_servers          # returns server UUID
coolify_get_projects         # returns id|uuid|name
coolify_get_env_uuid "$project_uuid"
coolify_create_service "$name" "$compose_yaml" "$server_uuid" "$project_uuid" "$env_uuid"
coolify_start_service "$service_uuid"
coolify_stop_service "$service_uuid"
coolify_restart_service "$service_uuid"
coolify_deploy "$name" "$compose_yaml" "$project_name"
```

Requires env vars: `COOLIFY_MASTER_URL`, `COOLIFY_TOKEN`

---

## MCP / Laravel Tools (Inside Coolify Container)

```bash
# Connect to Coolify container
docker exec <coolify-container-name> php artisan boost:mcp

# This provides:
# - list-artisan-commands
# - tinker (execute PHP in app context)
# - database-query (read-only DB queries)
# - search-docs (search Laravel docs)
```

---

## Dev Workflow

**Path:** `/root/AI-SmartPanel/coolify/`

### Pre-Checks Before Starting Dev
```bash
# Check production status
docker ps --format "{{.Names}}: {{.Ports}}" | grep -E "coolify|postgres|redis|soketi"

# Check port conflicts
docker ps --format "{{.Names}}: {{.Ports}}" | grep -E "5432|6379|6001|8000|9000|5173"
```

### If Production Running — Use Alternative Dev Ports
```bash
cd /root/AI-SmartPanel/coolify

FORWARD_DB_PORT=5434 FORWARD_REDIS_PORT=6380 FORWARD_SOKETI_PORT=6010 \
  FORWARD_VITE_PORT=5174 FORWARD_MINIO_PORT=9010 \
  docker compose -f docker-compose.dev.yml -p coolify-dev up -d
```

### Port Map (Dev vs Prod)
| Service | Prod Port | Dev Port |
|---------|-----------|----------|
| Coolify | 8000 | 8010 |
| Postgres | 5432 | 5434 |
| Redis | 6379 | 6380 |
| Soketi | 6001 | 6010 |
| Vite | — | 5174 |
| Minio | 9000 | 9010 |

### Network Isolation — CRITICAL
All services MUST have explicit `networks:` in docker-compose, otherwise Coolify creates separate networks per service and they can't communicate → 500 errors.

### Start Dev Script
```bash
/root/AI-SmartPanel/coolify/scripts/local/start-dev.sh
# Auto-detects SERVER_IP, sets env vars, starts docker compose
```

### First Time After Start
```bash
docker exec coolify-dev-coolify-1 php artisan db:seed --force
```

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `docker_compose_raw should be base64 encoded` | Use `base64 -w 0` not `base64` |
| `project_uuid is required` | Get from `/api/v1/projects` |
| `environment_uuid is required` | Get from `/api/v1/projects/$PROJECT_UUID` |
| 401 Unauthorized | Token invalid or expired — recreate token |
| Connection refused | Check COOLIFY_MASTER_URL is correct |
| 500 on /login | Seed DB: `php artisan db:seed --force` |
| 500 — missing vendor | `composer install --no-interaction --ignore-platform-reqs` |
| RedisException AUTH | Redis has no password but env says it does — set `REDIS_PASSWORD=` |
| Services can't communicate | Check all on same Docker network |

### Docker Commands Reference
```bash
docker ps --filter name=coolify           # Check Coolify status
docker logs -f coolify                    # View logs
docker restart coolify                    # Restart
docker exec coolify coolify:status        # CLI status
```

---

## Tested Deployment Flow

1. Create project: `POST /api/v1/projects`
2. Get project UUID + environment UUID from response
3. Ensure server is visible (team_id must match user's team)
4. Deploy from git: `POST /api/v1/applications/public`
   - Required: `server_uuid`, `project_uuid`, `environment_uuid`, `git_repository`, `git_branch`, `build_pack`, `ports_exposes`
5. Start: `GET /api/v1/applications/{uuid}/start`
6. Monitor `status` field: `running` / `exited` / `degraded`

---

## Production Setup Notes

1. Docker socket must be mounted: `- /var/run/docker.sock:/var/run/docker.sock`
2. Server must have `team_id` set to user's team to appear in API
3. API requires: `is_api_enabled=true`, user+token in DB
4. FQDN must be set in `instance_settings.fqdn`
5. Token is stored as SHA256 hash in DB, but the raw token is shown only once at creation
## Quick Commands
- `skill-load coolify-manager` — Load this skill
