---
name: coolify-auth-discovery
description: Coolify authentication mechanisms — self-hosted vs cloud token differences
category: devops
---
# Coolify Authentication: Self-Hosted vs Cloud

## Key Distinction

| Environment | Auth Type | Token Prefix | REST API Access |
|-------------|-----------|--------------|-----------------|
| Self-hosted (beta.470) | Cookie-based (Laravel) | `1\|...` | **NOT supported** — only web UI or direct docker |
| Cloud (master.nexeraa.io) | API Token | `2\|...` | Full REST API access |

## Self-Hosted Coolify (e.g., localhost:8000, 89.167.96.223)

- Uses Laravel cookie session auth for web UI
- API tokens via `personal_access_tokens` table exist but are **not used** by the API
- To interact programmatically: either use web UI directly, or use docker CLI on the host
- Database query to check: `docker exec coolify-db psql -U coolify -d coolify -c "SELECT * FROM personal_access_tokens LIMIT 5;"`

## Cloud Coolify (master.nexeraa.io)

- Uses Bearer token auth with `2\|...` prefixed tokens
- Full REST API access with header: `Authorization: Bearer 2\|...`
- Token created via web UI Settings → API Tokens

## DANGEROUS: docker compose in /data/coolify/source

**NEVER run `docker compose` or `docker-compose` commands in `/data/coolify/source/` without extreme caution.**

This directory contains the Coolify stack's docker-compose file. Running `docker compose down/up/restart` here will:
- Restart `coolify-db` container
- Potentially wipe the PostgreSQL database (volume remount + fresh init)
- Disconnect Coolify UI from all managed applications
- Leave orphaned containers running but invisible to Coolify

**What survives:** Named volumes (`coolify-db`, `coolify-redis`) — but the DATABASE inside them can be reset to empty.

**What gets orphaned:** Application containers keep running with their volumes, but Coolify loses all metadata (projects, applications, servers, teams).

**If you must interact with Coolify containers directly:**
```bash
# SAFE — only target specific application containers by name
docker stop onedev-ebsx0anlwb5w4k3cixh8o3qn

# NEVER do this on self-hosted Coolify host:
cd /data/coolify/source && docker compose down  # WILL CAUSE DATA LOSS

# If you need to restart Coolify itself, use the web UI or:
docker restart coolify
```

## Implications

- **Cannot use REST API to redeploy** on self-hosted Coolify from an external agent
- **Can use docker directly** on the host: `docker stop`, `docker run` — but only target application containers by their EXACT name
- **Can use web UI** with browser automation (cookie session)
- **NEVER** run `docker compose` in `/data/coolify/source/`

## Context

- Self-hosted Coolify: `localhost:8000` or `http://89.167.96.223:8081`
- Cloud Coolify: `https://master.nexeraa.io`
- Database inspect: `docker exec coolify-db psql -U coolify -d coolify`
## Quick Commands
- `skill-load coolify-auth-discovery` — Load this skill
