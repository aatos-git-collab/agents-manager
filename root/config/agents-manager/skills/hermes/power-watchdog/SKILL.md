---
name: power-watchdog
description: Unified self-healing watchdog for the entire Hermes ↔ Claude Code skill ecosystem. Runs every 10 min. Checks: skill-sync cron alive, graphify-bootstrap cron, hermes-memory watchdog, all 65 symlinks valid, all Docker containers healthy, Honcho API alive, git backup repo healthy. Auto-heals everything. Logs everything.
category: meta
---

# power-watchdog — Unified Self-Healing System

> Every 10 minutes, everything is checked. Everything that can break, heals itself.

## What it watches

```
┌─────────────────────────────────────────────────────────────┐
│ power-watchdog (every 10 min)                                │
│                                                              │
│ ✅ skill-sync cron alive (every 15 min)                       │
│ ✅ hermes-memory watchdog alive (every 10 min)                │
│ ✅ graphify-bootstrap cron alive (every 15 min)               │
│ ✅ 65 skill symlinks → Claude Code                           │
│ ✅ Honcho API health (http://localhost:8000/health)           │
│ ✅ 3 Docker containers (honcho-api, honcho-db, honcho-redis)   │
│ ✅ Git backup repo healthy                                   │
│ ✅ skill-sync log recent                                     │
│ ✅ Memory dirs writable                                      │
│ ✅ graphify CLI available                                    │
└─────────────────────────────────────────────────────────────┘
```

## Quick commands

```bash
# Run the watchdog manually
bash ~/.hermes/skills/power-watchdog/scripts/watch.sh run

# Report only (no heal)
bash ~/.hermes/skills/power-watchdog/scripts/watch.sh report

# Install cron
bash ~/.hermes/skills/power-watchdog/scripts/watch.sh install-cron
```

## Self-heal actions

| Symptom | Fix |
|---------|-----|
| skill-sync cron missing | Reinstall `*/15 * * * *` |
| hermes-memory watchdog missing | Reinstall `*/10 * * * *` |
| graphify-bootstrap cron missing | Reinstall `*/15 * * * *` |
| Broken skill symlink | Delete + recreate |
| Honcho API down | `docker restart honcho-api-1 honcho-database-1 honcho-redis-1` |
| Git backup repo broken | Recreate bare repo |
| skill-sync.log not updating | Force run `sync.sh forward` |

## Cron schedule

```
# power-watchdog itself — every 10 min
*/10 * * * * bash ~/.hermes/skills/power-watchdog/scripts/watch.sh run

# Sub-crons installed by power-watchdog:
#   skill-sync:        */15 * * * *
#   hermes-memory:    */10 * * * *  (legacy, superseded)
#   graphify-bootstrap: */15 * * * *
```

## Report format

```
=== power-watchdog [HH:MM:SS] ===
⏱  4.2s | 🔋 health

✅ skill-sync cron:        alive (15min)
✅ hermes-memory watchdog: alive (10min)
✅ graphify-bootstrap:     alive (15min)
✅ Skill symlinks:         65/65 valid
✅ Honcho API:             healthy
✅ Docker containers:     3/3 running
✅ Git backup repo:       healthy
✅ Memory dirs:            writable
✅ Graphify CLI:           available
✅ skill-sync.log:        recent (2m ago)

Heals applied: 0
```

## Architecture

```
power-watchdog (10min)
├── Checks all sub-system crons
│   ├── skill-sync (15min)       → symlinks Hermes → Claude Code
│   ├── hermes-memory watchdog   → Honcho + graphify + memory dirs
│   └── graphify-bootstrap       → code knowledge graphs
├── Checks all symlinks (65 dirs)
├── Checks all Docker containers
├── Checks Honcho API
├── Checks git backup repo
└── Auto-heals anything broken
    └── Logs heals to: ~/.hermes/memory/watchdog.log
```

## Quick Commands
- `skill-load power-watchdog` — Load this skill
