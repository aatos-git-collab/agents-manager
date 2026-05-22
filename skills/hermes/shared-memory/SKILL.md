---
name: shared-memory
description: Unified Graphify + Honcho memory shared between AatosTeam (Hermes) and Claude Code. Shared brain — one graph, both agents.
category: memory
---
# shared-memory — Unified Memory System for AatosTeam + Claude Code

> One brain. Two agents. Same memories.

**Goal:** AatosTeam (Hermes) and Claude Code share the same Graphify knowledge graph,
Honcho dialectic memory, and daily/weekly memory files — so both agents reason from
the same context and compound learning across sessions.

---

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │          SHARED MEMORY LAYER                 │
                    │                                             │
  AatosTeam  ──────►│  /root/pawnshop/graphify-out/              │
  (Hermes)          │      graph.json   (513 nodes, 273 edges)    │
                    │      GRAPH_REPORT.md                        │
                    │      graph.html                             │
                    │      cache/                                 │
  Claude Code ─────►│                                             │
  (Claude Code)     │  ~/.hermes/memory/                          │
                    │      daily/   weekly/   graphify/ ──────────┼── symlinks → graphify-out/
                    │                                             │
                    │  Honcho server: http://localhost:8000        │
                    │  (pgvector: sessions, peer cards, models)    │
                    │                                             │
                    │  Backup: ~/.hermes/memory-backup.git         │
                    └─────────────────────────────────────────────┘
```

### What each agent uses

| Resource | AatosTeam | Claude Code | Notes |
|----------|-----------|-------------|-------|
| Graphify graph | ✅ `/root/pawnshop/graphify-out/` | ✅ same path | Both read GRAPH_REPORT.md |
| graphify CLI | ✅ venv | ✅ venv | Same source `/root/graphify/` |
| Honcho server | ✅ localhost:8000 | ✅ localhost:8000 | Same workspace API key |
| Daily memory | ✅ `~/.hermes/memory/daily/` | ✅ same | Both write here |
| Weekly memory | ✅ `~/.hermes/memory/weekly/` | ✅ same | Both write here |
| Watchdog | ✅ every 10 min | ❌ | Only AatosTeam runs it |

---

## Quick Status

```bash
bash ~/.hermes/skills/shared-memory/scripts/status.sh
```

---

## Setup (Run Once)

### 1. Graphify — install for both agents

```bash
# Graphify source is at /root/graphify/ (already installed)
# Verify both agents can use it:
graphify --help | head -5
python3 -c "import graphify; print('ok')"

# If not in Claude Code's venv, install it:
~/.claude/venv/bin/pip install -e /root/graphify 2>/dev/null || \
/root/.claude/venv/bin/pip install -e /root/graphify 2>/dev/null || \
sudo /root/.claude/venv/bin/pip install -e /root/graphify
```

### 2. Symlink graphify-out to memory dir (for backup)

```bash
ln -sfn /root/pawnshop/graphify-out/graph.json \
    ~/.hermes/memory/graphify/graph.json
ln -sfn /root/pawnshop/graphify-out/GRAPH_REPORT.md \
    ~/.hermes/memory/graphify/GRAPH_REPORT.md
ln -sfn /root/pawnshop/graphify-out/graph.html \
    ~/.hermes/memory/graphify/graph.html
ln -sfn /root/pawnshop/graphify-out/cache \
    ~/.hermes/memory/graphify/cache
```

### 3. Graphify CLI hooks in Claude Code

```bash
cd /root/pawnshop && graphify hook install
# Runs graphify update after every git commit
```

### 4. Verify both agents access same graph

```bash
# AatosTeam
graphify explain "next.js page" --graph /root/pawnshop/graphify-out/graph.json

# Claude Code (from same machine, same graphify binary)
~/.claude/venv/bin/graphify explain "next.js page" --graph /root/pawnshop/graphify-out/graph.json
```

---

## Graphify Data Layout

```
/root/pawnshop/graphify-out/
├── graph.json        # Full AST graph (272KB) — the knowledge graph
├── GRAPH_REPORT.md   # Human-readable summary (75KB)
├── graph.html        # Interactive visualization
└── cache/            # Cached embeddings (1.4MB)
```

**Backup strategy:**
- `graph.json` + `GRAPH_REPORT.md` + `graph.html` + `cache/` are all symlinked
  from `~/.hermes/memory/graphify/` so they back up to `~/.hermes/memory-backup.git`
- The graph is regenerated via `graphify update /root/pawnshop/` — backup is for
  convenience (avoids 5-min rebuild), but losing it is not fatal
- Full restore: clone backup → `graphify update` to rebuild graph from source

---

## Honcho (Dialectic Memory)

Honcho runs at `http://localhost:8000`. Both agents use the same workspace.

```bash
# Check status
curl -s http://localhost:8000/health

# Create a session (test connectivity)
curl -s -X POST http://localhost:8000/v3/workspaces/default/sessions \
  -H "Authorization: Bearer $(cat ~/.honcho/config.json | python3 -c 'import sys,json; print(json.load(sys.stdin)["api_key"])')" \
  -H "Content-Type: application/json" \
  -d '{"id": "test", "metadata": {"source": "aatosteam"}}'
```

**Backup:** `~/.honcho/config.json` (workspace API key) + `/root/honcho/` server files
are backed up to git. The actual memory (pgvector) is in the Docker volume
`honcho_pgdata` — backed up via `pg_dump` to `honcho-db.sql.gz`.

---

## Daily + Weekly Memory

Both agents write to:
- `~/.hermes/memory/daily/YYYY-MM-DD.md`
- `~/.hermes/memory/weekly/WW-YYYY-WNN.md`

These are plain markdown files. Both agents can read and write them.

---

## Graphify Commands

```bash
# Build/rebuild the graph (do this after major code changes)
graphify update /root/pawnshop/

# Explain a node
graphify explain "BlogCard" --graph /root/pawnshop/graphify-out/graph.json

# Find shortest path between two nodes
graphify path "CtaBanner" "Hero" --graph /root/pawnshop/graphify-out/graph.json

# Query the graph with a question
graphify query "how is the blog newsletter component structured?"

# Update after every git commit (auto-installed via graphify hook install)
graphify hook install
```

---

## Critical Patterns (Trial & Error)

### 1. Git cannot track symlink targets — only the link itself

Git stores symlinks as text (the target path), not the dereferenced content.
- `rsync -a` follows symlinks as regular files (empty dirs if not dereferenced)
- **Solution:** `ln -sfn /root/pawnshop/graphify-out/graph.json ~/.hermes/memory/graphify/graph.json`
- On restore: git clones, symlinks are recreated pointing at the same live data
- On `git clone` to a fresh machine: symlinks point to non-existent paths — re-run setup
- **Key insight:** For true portability, also keep a plain `graph.json` backup (not just symlink)

### 2. Graphify PreToolUse hook uses RELATIVE paths — fix with absolute

`graphify claude install` writes `graphify-out/graph.json` (relative) — works only when
Claude Code's working directory is `/root/pawnshop/`. Claude Code can run from anywhere.
- **Fix:** Edit `~/.claude/settings.json` directly, use `/root/pawnshop/graphify-out/`
- The hook command: `[ -f /root/pawnshop/graphify-out/graph.json ] && echo '{"hookSpecificOutput":...}'`

### 3. pg_dump from inside a Docker container

The Honcho database runs in `honcho-database-1`. Backup with:
```bash
docker exec honcho-database-1 pg_dump -U postgres -d postgres | gzip > honcho-db.sql.gz
```
Restore: `gunzip < honcho-db.sql.gz | docker exec -i honcho-database-1 psql -U postgres -d postgres`

### 4. Docker healthcheck must use container-available commands

Honcho API container has Python but NO `curl` or `wget`.
- **Wrong:** `curl -sf http://localhost:8000/health`
- **Correct:** `python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"`

### 5. docker-compose.yml patch accidentally replaces `true` with `***`

The `patch` tool matched `AUTH_USE_AUTH=true` where `***` happened to appear in the file,
corrupting it. **Fix:** always rewrite entire YAML files, never patch multi-line YAML.

### 6. Symlink healing in watchdog

If `~/.hermes/memory/graphify/graph.json` is a broken symlink (target deleted or machine
rebooted), watchdog detects it with `[ -e "$link" ]` and re-links.

---

## Troubleshooting

### Graphify not found in Claude Code
```bash
~/.claude/venv/bin/pip install -e /root/graphify
```

### Claude Code PreToolUse hook not firing
The hook is in `~/.claude/settings.json` under `hooks.PreToolUse`. If the path is relative,
fix it directly:
```bash
python3 -c "
import json
settings = json.load(open('/root/.claude/settings.json'))
for h in settings.get('hooks',{}).get('PreToolUse',[]):
    if 'graphify' in str(h):
        h['hooks'][0]['command'] = h['hooks'][0]['command'].replace(
            '[ -f graphify-out/', '[ -f /root/pawnshop/graphify-out/')
json.dump(settings, open('/root/.claude/settings.json','w'), indent=2)
"
```

### Honcho server down
```bash
cd /root/honcho && docker compose up -d
sleep 5 && curl -s http://localhost:8000/health
```

### Graph out of date
```bash
graphify update /root/pawnshop/
```

### Restore from backup
```bash
bash ~/.hermes/skills/hermes-memory-aatos/scripts/restore.sh all
```

### Git clone breaks symlinks on new machine — re-create:
```bash
mkdir -p ~/.hermes/memory/graphify
ln -sfn /root/pawnshop/graphify-out/graph.json ~/.hermes/memory/graphify/graph.json
ln -sfn /root/pawnshop/graphify-out/GRAPH_REPORT.md ~/.hermes/memory/graphify/
ln -sfn /root/pawnshop/graphify-out/graph.html ~/.hermes/memory/graphify/
ln -sfn /root/pawnshop/graphify-out/cache ~/.hermes/memory/graphify/
```

## Quick Commands
- `skill-load shared-memory` — Load this skill
