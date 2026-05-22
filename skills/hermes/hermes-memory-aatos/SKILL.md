---
name: hermes-memory-aatos
description: hermes-memory-aatos skill
  Hermes AI memory system — graphify (codebase knowledge graphs, self-hosted) +
  Honcho (self-hosted on port 8000 with Minimax/ Anthropic-compatible API) +
  daily text memory. Full lifecycle: auto-install, self-heal watchdog, git backup/restore.
  Built by Aatos CTO for the NOVEM multi-billion startup mission.
---

# Hermes Memory System

**Graphify** (self-hosted) + **Honcho** (self-hosted, Minimax-powered) + **Daily Text Files**.

> **Honcho is self-hosted** on this machine at `http://localhost:8000`.
> Uses Minimax via Anthropic-compatible API (`https://api.minimax.io/anthropic`).
> All memory data lives in the Honcho postgres+pgvector database.
> Critical files to back up: `~/.honcho/config.json` + `/root/honcho/.jwt_secret`.

---

## Quick Commands

```bash
# Check Honcho server status
curl -s http://localhost:8000/health

# Check Docker containers
docker ps --format "table {{.Names}}\t{{.Status}}" | grep honcho

# Lifecycle checks
bash ~/.hermes/skills/hermes-memory-aatos/scripts/run.sh status
bash ~/.hermes/skills/hermes-memory-aatos/scripts/run.sh verify
bash ~/.hermes/skills/hermes-memory-aatos/scripts/run.sh heal

# Watchdog (every 10 min — auto-heals)
bash ~/.hermes/skills/hermes-memory-aatos/scripts/watchdog.sh run
bash ~/.hermes/skills/hermes-memory-aatos/scripts/watchdog.sh report

# Git backup / restore (EVERYTHING below is backed up)
bash ~/.hermes/skills/hermes-memory-aatos/scripts/backup.sh              # All memory
bash ~/.hermes/skills/hermes-memory-aatos/scripts/backup.sh graphify    # Graphify only
bash ~/.hermes/skills/hermes-memory-aatos/scripts/backup.sh honcho      # Honcho config only
bash ~/.hermes/skills/hermes-memory-aatos/scripts/backup.sh daily       # Daily memory only
bash ~/.hermes/skills/hermes-memory-aatos/scripts/restore.sh             # Full restore from git
bash ~/.hermes/skills/hermes-memory-aatos/scripts/restore.sh honcho     # Honcho-only restore

# Graphify (self-hosted, no account)
graphify update /path/to/code     # Build graph
graphify query "How does auth work?"  # Query graph
graphify watch /path/to/code     # Watch mode (CI)
```

---

## What Gets Backed Up (and Why Each Matters)

### Honcho — `~/.honcho/config.json` + `/root/honcho/.jwt_secret` (CRITICAL)

Honcho is **100% self-hosted** on this machine. All memory data lives in the
docker postgres+pgvector database. Two files need backup:

**`~/.honcho/config.json`** — Workspace API key + server URL:
```json
{
  "base_url": "http://localhost:8000",
  "api_key": "eyJhbG..."
}
```

**`/root/honcho/.jwt_secret`** — JWT secret for key generation (16+ lines, random hex).
Used to create new workspace keys if needed.

```
~/.honcho/config.json     ← BACK UP. Workspace API key + base URL.
~/.honcho/.env.secrets    ← BACK UP. Contains MINIMAX_API_KEY + AUTH_JWT_SECRET.
/root/honcho/.jwt_secret  ← BACK UP. JWT secret for key generation.
/root/honcho/docker-compose.yml  ← BACK UP. Full Honcho stack definition.
```

The actual memory data (peer cards, sessions, conclusions, user models) lives in
the docker postgres volume (`honcho_pgdata`). This is NOT in the git backup.
The git backup protects the credentials to access that data.

If you lose these files:
1. Restore `~/.honcho/config.json` from git
2. If JWT secret is lost: restart Honcho with a new `AUTH_JWT_SECRET`, recreate workspace key
3. All data in postgres is intact

### Graphify — `~/.hermes/memory/graphify/`

All local. Built from your codebases. Back up:
- `graph.json` — full knowledge graph (rebuilt from code, but loses annotations)
- `memory/qa/*.json` — saved Q&A results (feedback loop, irreplaceable)
- `GRAPH_REPORT.md` — human-readable summary

```
~/.hermes/memory/graphify/
├── graph.json          ← Rebuildable from code via `graphify update`
├── graph.html          ← Rebuildable
├── GRAPH_REPORT.md     ← Rebuildable
└── memory/qa/          ← NOT rebuildable — save Q&A results!
    └── *.json
```

### Daily Memory — `~/.hermes/memory/daily/`

Plain text, always local. Back up everything:
```
~/.hermes/memory/daily/YYYY-MM-DD.md   ← Session summaries
~/.hermes/memory/weekly/YYYY-Www.md     ← Weekly compilations
```

---

## Architecture

```
This Machine (Docker)
┌─────────────────────────────────────────────────────────────────┐
│ docker compose (honcho/)                                         │
│                                                                  │
│  ┌──────────────┐   ┌─────────────────┐   ┌────────────────┐  │
│  │ honcho-api-1 │   │ honcho-database  │   │ honcho-redis-1 │  │
│  │ :8000        │──→│ :5433 (pgvector)│   │ :6379          │  │
│  │ FastAPI+LLM  │   │  • peer_cards   │   │  Cache         │  │
│  │ Minimax API  │   │  • sessions     │   └────────────────┘  │
│  └──────────────┘   │  • conclusions  │                        │
│         ↑          │  • users        │                        │
│  AUTH_USE_AUTH=true└─────────────────┘                        │
│  AUTH_JWT_SECRET=...                                          │
└─────────────────────────────────────────────────────────────────┘
         ↑
         │ HTTP + JWT workspace key
         │
         │ ~/.honcho/config.json
         ▼
  ┌──────────────────────────────────────┐
  │ Hermes Agent                          │
  │  • Honcho plugin (syncs via API)     │
  │  • Graphify (local CLI)              │
  │  • Daily memory (plain text)          │
  └──────────────────────────────────────┘
         ↓ BACKUP (git)
  ~/.hermes/memory-backup.git/
```

### Honcho Stack Details

| Container | Port | What It Does |
|-----------|------|-------------|
| `honcho-api-1` | 8000 | FastAPI server + Minimax LLM integration |
| `honcho-database-1` | 5433 | PostgreSQL 15 + pgvector (actual memory data) |
| `honcho-redis-1` | 6379 | Redis cache |

**API endpoint:** `http://localhost:8000` (local only, no external exposure)
**Auth:** JWT-based. Workspace key in `~/.honcho/config.json`.
**LLM:** Minimax via `https://api.minimax.io/anthropic` (MiniMax-M2.7 model)

### Critical Secrets

```
/root/honcho/.jwt_secret         — JWT secret for key generation (keep private)
/root/honcho/.env.secrets        — MINIMAX_API_KEY + AUTH_JWT_SECRET
~/.honcho/config.json            — Workspace API key (backup this!)
```

---

## Honcho Setup (Already Done — For Reference)

The Honcho stack is already running. To rebuild from scratch:

```bash
# 1. Clone Honcho repo
git clone https://github.com/plastic-labs/honcho.git /root/honcho

# 2. Get MINIMAX_API_KEY from ~/.hermes/.env
# 3. Generate JWT secret
python3 -c "import secrets; print(secrets.token_hex(32))"

# 4. Write docker-compose.yml (see /root/honcho/docker-compose.yml for reference)
# Key env vars: LLM_API_KEY, LLM_BASE_URL, AUTH_USE_AUTH=true, AUTH_JWT_SECRET

# 5. Start
cd /root/honcho && docker compose up -d --build

# 6. Wait for healthy
sleep 5 && curl -s http://localhost:8000/health

# 7. Generate admin JWT + workspace key (see scripts/run.sh)
# 8. Create ~/.honcho/config.json with workspace key
# 9. Verify: curl http://localhost:8000/v3/workspaces/list -H "Authorization: Bearer $WORKSPACE_KEY"
```

---

## Self-Healing System

### Watchdog Cron (every 10 min)

```
hermes-memory-watchdog  */10 * * * *
→ Check Honcho API health (http://localhost:8000/health)
→ Verify ~/.honcho/config.json exists
→ Verify graphify CLI available
→ Verify memory dirs writable
→ Verify git backup repo healthy
→ If drift detected: auto-repair + log
→ If Honcho config missing: warn
```

### Self-Heal Triggers

| Symptom | Fix |
|---------|-----|
| Honcho API down | `cd /root/honcho && docker compose restart` |
| Graphify CLI missing | `graphify hermes install` |
| Honcho config gone | Restore from git backup, then `docker compose restart` |
| Memory dirs missing | Create them |
| Git backup repo broken | Recreate bare repo |

---

## Backup & Restore

### Backup Everything

```bash
bash ~/.hermes/skills/hermes-memory-aatos/scripts/backup.sh
```

This backs up:
- `~/.hermes/memory/graphify/` (all files including Q&A memory)
- `~/.hermes/memory/daily/` (plain text session memory)
- `~/.hermes/memory/weekly/` (weekly compilations)
- `~/.honcho/config.json` (CRITICAL: Workspace API key + base URL)
- `/root/honcho/.jwt_secret` (JWT secret for key generation)
- `/root/honcho/docker-compose.yml` (Full Honcho stack definition)

### Restore Everything

```bash
# Full restore from git backup
bash ~/.hermes/skills/hermes-memory-aatos/scripts/restore.sh

# Restore only Honcho (e.g. after losing config.json)
bash ~/.hermes/skills/hermes-memory-aatos/scripts/restore.sh honcho
```

### Honcho Restore Flow

```
~/.honcho/config.json missing
    ↓ Restore from git
~/.honcho/config.json restored (with workspace key)
    ↓ Docker containers running?
    ↓ All data in honcho_pgdata volume is intact
All peer cards, sessions, conclusions = back
```

### Git Backup Repo

```
~/.hermes/memory-backup.git/   ← Bare git repo (backup storage)
~/.hermes/memory/             ← Working copy
```

---

## File Locations

| Path | What It Is | Backed Up | Recoverable |
|------|-----------|-----------|-------------|
| `/root/honcho/` | Honcho repo + docker-compose | ✅ Yes (via skill) | Re-clone + reconfigure |
| `/root/honcho/docker-compose.yml` | Stack definition | ✅ Yes | Recreate from skill docs |
| `/root/honcho/.jwt_secret` | JWT secret | ✅ Yes | Regenerate with new secret |
| `~/.honcho/config.json` | Workspace API key + URL | ✅ CRITICAL | Restore from git, key still works |
| `~/.hermes/memory/honcho/` | Hermes plugin cache | ✅ (transient) | Recreated on startup |
| `~/.hermes/memory/graphify/graph.json` | Code knowledge graph | ✅ Yes | Rebuildable via `graphify update` |
| `~/.hermes/memory/graphify/memory/qa/*.json` | Saved Q&A results | ✅ Yes | NOT rebuildable |
| `~/.hermes/memory/daily/*.md` | Plain text daily memory | ✅ Yes | Always local |
| `~/.hermes/memory/weekly/*.md` | Weekly compilations | ✅ Yes | Always local |
| `honcho_pgdata` (Docker volume) | PostgreSQL + pgvector data | ❌ No | All Honcho memory data |

---

## Versions

| Date | Version | Change |
|------|---------|--------|
| 2026-04-24 | v3.0.0 | Honcho is self-hosted on port 8000 with Minimax API. JWT auth enabled. Full docker stack with pgvector. Auth tokens backed up via git. |
| 2026-04-24 | v2.1.0 | Honcho is fully cloud — backup `~/.honcho/config.json` only. |
| 2026-04-24 | v2.0.1 | Clarified Honcho cloud-only (no self-hosted). |
| 2026-04-24 | v2.0.0 | Full rewrite. Graphify + Honcho + daily memory. Stealth-browser-style lifecycle. Git backup/restore. |
