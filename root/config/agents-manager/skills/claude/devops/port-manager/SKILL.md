---
name: port-manager
description: Port management skill — prevents conflicts, maps all services to ports, checks availability before deployment
triggers:
  - "check ports"
  - "what port is"
  - "is port available"
  - "port conflict"
  - "start service on port"
  - "docker start"
category: devops
---

# Port Manager Skill

**Port-gated deployment system** — ALL docker deployments MUST pass port conflict checks before launching. No exceptions.

## Core Principles

1. **Port check is MANDATORY** — before ANY `docker up`, `docker start`, `docker compose up`, `deploy`
2. **Fail fast** — if any port is in use, deployment BLOCKS with clear diagnostics
3. **One source of truth** — port registry is the single source for allocations
4. **No manual overrides** — no bypass flags, no `--force`, no "I know it's ok"

---

## Deployment Workflow (MANDATORY)

```
USER REQUEST → PORT CHECK → PASS? → DEPLOY → REPORT
                    ↓
               FAIL → BLOCK → DIAGNOSTIC → FIX → RETRY
```

**Every docker deployment goes through this gate.** No exceptions.

## Port Registry

| Service | Internal | External | Protocol | Notes |
|---------|----------|----------|----------|-------|
| coolify | 8080 | 8081 | HTTP | Prod Coolify |
| coolify-dev | 8080 | 8010 | HTTP | Dev Coolify |
| coolify-proxy | 80, 443 | 80, 443 | HTTP/HTTPS | Traefik |
| coolify-mail | 1025, 8025 | 1025, 8025 | SMTP/SMTP | Mailpit |
| coolify-minio | 9000, 9001 | 9000, 9001 | S3 | MinIO |
| coolify-redis | 6379 | 6379 | TCP | Redis |
| coolify-postgres | 5432 | 5432 | TCP | PostgreSQL |
| coolify-soketi | 6001 | 6001 | WebSocket | Soketi |
| coolify-dev-redis | 6379 | 6379 | TCP | Dev Redis |
| coolify-dev-postgres | 5432 | 5432 | TCP | Dev Postgres |
| coolify-dev-soketi | 6001 | 6001 | WebSocket | Dev Soketi |
| coolify-vite | 5173 | 5174 | HMR | Vite dev server |
| code-server | 8443 | 8453 | HTTPS | VSCode Web IDE |
| mission-control | 3000 | 3333 | HTTP | Agent orchestration |
| webbuilder-traefik | 80, 443, 8080 | 8880, 8443, 8881 | HTTP | Bolt builder |
| open-webui | 8080 | - | HTTP | Ollama WebUI |
| mattermost | 8065, 8067, 8074-8075 | - | HTTP/WS | Team edition |
| lead-gen | 5000 | 5000 | HTTP | Flask app |
| payment | 5001 | 5001 | HTTP | Flask app |
| delivery | 5002 | 5002 | HTTP | aiohttp app |
| creator-tools | 5003 | 5003 | HTTP | Flask app |
| stealth-browser | 9377 | 9377 | HTTP | Camoufox browser |
| npm | 80, 443 | 344, 81 | HTTP/HTTPS | nginx proxy manager (coexistence: 344/81; full: 80/443) |

## Deployment Gate Scripts

### port-check.sh
**MANDATORY** — checks all allocated ports before any deployment. Fails if any port is in use.

```bash
# Check system ports
bash /root/.hermes/skills/devops/port-manager/scripts/port-check.sh

# Check with a compose file (extracts ports automatically)
bash /root/.hermes/skills/devops/port-manager/scripts/port-check.sh /path/to/docker-compose.yml
```

### docker-gate.sh
**PORT-GATED docker wrapper** — use INSTEAD of raw `docker` commands. Blocks deployment if ports conflict.

```bash
# Install alias (add to ~/.bashrc)
alias dockerg='/root/.hermes/skills/devops/port-manager/scripts/docker-gate.sh'

# Safe commands (pass through without check)
dockerg ps
dockerg logs -f container_name

# Deployment commands (MUST pass port check)
dockerg up -d
dockerg compose up -d
dockerg start
```

## Before Starting Any Service — MANDATORY WORKFLOW

```
1. dockerg ps                           # check what's running
2. dockerg up -d                        # port gate auto-runs
   ↓
   PORT GATE PASSES? → YES → deploy     NO → fix first
   ↓
3. Verify: ss -tlnp | grep :PORT        # confirm port binding
4. Document: update registry above
```

## Quick Commands

```bash
# Show all allocated ports
ss -tlnp | grep LISTEN

# Check specific port
ss -tlnp | grep ':PORT'

# Kill whatever is on a port
fuser -k PORT/tcp

# Show docker-bound ports
docker ps --format '{{.Ports}}' | grep -oE '0\.0\.0\.0:[0-9]+|::: [0-9]+' | sort -u

# Full conflict scan
bash /root/.hermes/skills/devops/port-manager/scripts/port-check.sh
```

## Allocation Rules

| Range | Purpose | Examples |
|-------|---------|----------|
| < 1024 | System reserved | 22, 53, 80, 443 |
| 1024-8999 | Application ports | 5000-5003 |
| 9000-9999 | Infrastructure | 9000-9001 (MinIO), 8081 (Coolify) |
| 8000-8999 | Dev/internal | 8010 (dev Coolify), 8880 (webbuilder) |

**Rule: 8080 = internal only. Never expose directly.**

## Integration Points

### For Coolify Deployments
Coolify has its own AI health monitoring. Port conflicts should be caught BEFORE containers start. The `port-check.sh` script should be run as a pre-deployment validation step.

### For Bolt Builder Deployments
The Bolt Builder deploys via docker-compose raw to Coolify. Before deploying:
```bash
bash /root/.hermes/skills/devops/port-manager/scripts/port-check.sh /path/to/docker-compose.yml
```

### For NPM Domain Gateway

NPM (nginx proxy manager) manages external domain routing + SSL termination.

**Two modes:**

1. **COEXISTENCE (current — dev not complete):**
   ```bash
   # NPM on alternate ports (344/81) alongside Coolify on 80/443
   bash /root/AI-SmartPanel/coolify/npm/start-npm-coexist.sh
   ```

2. **FULL TAKEOVER (when dev is complete):**
   ```bash
   # Takes 80/443 from coolify-proxy. ONE-WAY MIGRATION.
   # Loses auto-SSL for Coolify deployments
   bash /root/AI-SmartPanel/coolify/npm/migrate-to-npm.sh
   ```

**NPM proxy hosts to configure:**
| Domain | Forward To | Notes |
|--------|-----------|-------|
| dev.coolify.io | http://coolify-dev-coolify-1:8080 | Dev Coolify |
| coolify.dash.nexeraa.io | http://coolify:8080 | Prod Coolify |
| openwebui.dash.nexeraa.io | http://open-webui-*:8080 | Already has SSL cert |

**Import existing SSL certs from Traefik:**
```bash
cp /var/lib/docker/volumes/coolify_dev_coolify_data/_data/proxy/acme.json /root/AI-SmartPanel/coolify/npm/data/
# Then in NPM UI: SSL Certificates → Import → paste cert + key
```

### Adding New Services
When adding a new service that binds a port:
1. Pick from unallocated range
2. Run port-check to confirm it's free
3. Add to registry above
4. Commit updated skill
