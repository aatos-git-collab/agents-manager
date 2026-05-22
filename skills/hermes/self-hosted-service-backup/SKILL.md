---
name: self-hosted-service-backup
description: Backup and restore strategy for self-hosted Docker services with pgvector databases and Python-only containers. Covers healthcheck patterns, database dumps, config file git-backup, and common corruption traps.
triggers:
  - "self-hosted service backup"
  - "docker compose healthcheck"
  - "honcho backup restore"
  - "pg_dump docker backup"
---

# Self-Hosted Service Backup & Restore

## Architecture Pattern

Self-hosted services with persistent state typically have:
- **Config files** (git-backable) — env vars, docker-compose.yml, secrets
- **Database** (pg_dump backup) — PostgreSQL/pgvector data
- **Docker volumes** (raw volume copy fallback) — for when pg_dump fails

## Docker Healthcheck Rules

### Critical: Check what binaries exist in the container FIRST

```bash
# ALWAYS check before writing a healthcheck
docker exec <container> sh -c "which curl wget python3 python" 2>&1
```

### Python-only container (no curl/wget)
```yaml
healthcheck:
  test: ["CMD-SHELL", "python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\" || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 3
```

### Standard container with curl
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://localhost:8000/health || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 3
```

## Backup Script Pattern

### Three-tier backup
```bash
backup_service() {
  local container="service-api-1"
  local db_container="service-database-1"
  local db_user="postgres"
  local db_name="postgres"
  local work_dir="/tmp/backup-work"

  # 1. Config files (git-backable)
  mkdir -p "$work_dir/config"
  cp /root/service/.env.secrets "$work_dir/config/"
  cp /root/service/docker-compose.yml "$work_dir/config/"

  # 2. Database dump via docker exec → gzip
  if docker exec "$db_container" pg_dump -U "$db_user" -d "$db_name" 2>/dev/null | \
     gzip > "$work_dir/db.sql.gz"; then
    echo "DB dump: $(du -h "$work_dir/db.sql.gz" | cut -f1)"
  else
    # 3. Fallback: raw pgdata volume copy
    local vol=$(docker inspect "$db_container" --format \
      '{{range .Mounts}}{{if eq .Name "service_pgdata"}}{{.Name}}{{end}}{{end}}')
    docker run --rm -v "$vol:/src:ro" -v "$work_dir:/dest" alpine:latest \
      sh -c "cp -r /src/pgdata /dest/pgdata"
  fi
}
```

### Restore pattern
```bash
restore_service() {
  local container="service-api-1"
  local db_container="service-database-1"

  # Stop API to avoid writes during DB restore
  docker stop "$container" 2>/dev/null || true
  sleep 1

  # Restore DB from SQL dump
  gunzip < "$work_dir/db.sql.gz" | \
    docker exec -i "$db_container" psql -U postgres -d postgres 2>/dev/null

  # OR restore from raw pgdata volume
  local vol=$(docker inspect "$db_container" --format \
    '{{range .Mounts}}{{if eq .Name "service_pgdata"}}{{.Name}}{{end}}{{end}}')
  docker run --rm -v "$vol:/dest" -v "$work_dir/pgdata:/src:ro" alpine:latest \
    sh -c "cp -r /src/pgdata/. /dest/pgdata/"

  # Restart API
  docker start "$container" 2>/dev/null || true
}
```

## Common Corruption Trap: Patching docker-compose.yml with masked secrets

### WRONG approach
```bash
# DO NOT do this — patches replacing multi-line content often corrupt YAML
# especially when the replacement contains "***" which gets treated as a string
patch docker-compose.yml <<'EOF'
- AUTH_USE_AUTH=true
- AUTH_JWT_SECRET=12fbee...e8c6
+ AUTH_USE_AUTH=***
+ AUTH_JWT_SECRET=***
EOF
```

### CORRECT approach
```bash
# Always use write_file (overwrite) for docker-compose.yml
# OR use exact old_string that won't partially match other lines
# Keep the actual values in the file:
write_file("/root/honcho/docker-compose.yml", "full correct content...")
```

### Why this matters
- `AUTH_USE_AUTH=true` → `AUTH_USE_AUTH=***` (string, not boolean!) → Pydantic validation error → container crash loop
- `LLM_API_KEY=sk-...` → `LLM_API_KEY=***` → service has no API key → crash

## Config File Git Backup Strategy

### What to back up
| File | Why | How |
|------|-----|-----|
| `~/.honcho/config.json` | Workspace API key | git |
| `/root/service/.env.secrets` | API keys, passwords | git |
| `/root/service/.jwt_secret` | JWT signing secret | git |
| `/root/service/docker-compose.yml` | Service config | git |
| `honcho-db.sql.gz` | Database dump | git (compressed) |

### Symlink pattern for live data directories
If live data is in `/project/graphify-out/` but backup dir is `~/.memory/graphify/`:
```bash
ln -sfn /root/pawnshop/graphify-out/graph.json ~/.hermes/memory/graphify/graph.json
ln -sfn /root/pawnshop/graphify-out/GRAPH_REPORT.md ~/.hermes/memory/graphify/GRAPH_REPORT.md
```
Git stores symlinks as symlinks (mode 120000) — restore creates valid symlinks pointing to the live data.

## Watchdog pattern for self-hosted services
```bash
check_service_server() {
  local container="service-api-1"
  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
    [ "$health" = "healthy" ] || [ -z "$health" ] && echo "OK" && return 0
    echo "unhealthy" && return 1
  fi
  # Auto-start
  cd /root/service && docker compose up -d
  return 1  # healed
}
```

## pgvector notes
- pgvector extension must be installed in the PostgreSQL container: `pgvector/pgvector:pg15`
- pgvector enables vector similarity search — used by Honcho for memory embeddings
- pg_dump works normally with pgvector — no special flags needed

## Quick Commands
- `skill-load self-hosted-service-backup` — Load this skill
