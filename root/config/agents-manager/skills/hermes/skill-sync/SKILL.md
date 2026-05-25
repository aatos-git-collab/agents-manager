---
name: skill-sync
description: Bidirectional skill sync between Hermes (AatosTeam brain) and Claude Code executor. Use when "sync skills to claude code" / "sync from hermes" / "promote skill" / "new skill created in hermes" / periodic cron (every 15 min). Maintains symlinks: Hermes skills → Claude Code skills dir. Monitors Claude Code ck memory-bank for patterns to promote to Hermes skills via skill-creator.
category: meta
---

# skill-sync — Bidirectional skill bridge: Hermes ↔ Claude Code

> **Hermes is the brain. Claude Code is the skilled executor. skill-sync keeps them in sync.**

## The architecture

```
Hermes (AatosTeam brain)                    Claude Code (skilled executor)
┌──────────────────────────────┐            ┌──────────────────────────────┐
│ /root/.hermes/skills/        │◄──sync───►│ ~/.claude/skills/            │
│  490 skills (nested dirs)    │  forward   │  489 via category symlinks   │
│  All skills live here        │            │  + 17 top-level skill symlinks│
└──────────────────────────────┘            └──────────────────────────────┘
         │
         │ symlinks only
         ▼
Every category dir in hermes/skills/ is symlinked to ~/.claude/skills/
→ Claude Code sees ALL 490 Hermes skills through category symlinks
```

## Forward sync (Hermes → Claude Code)

Every skill in Hermes is symlinked into Claude Code via category directories.

```bash
bash ~/.hermes/skills/skill-sync/scripts/sync.sh forward
```

**What it syncs:**
- All category directories (e.g. `marketing/`, `mlops/`, `software-development/`)
- All top-level skill directories (e.g. `graphify-bootstrap/`, `shared-memory/`)
- All skills nested inside categories (e.g. `marketing/ads-microsoft/`)
- AatosTeam tools skills: `aatosteam/`, `clawteam-dev/`, `frontend-design/`

**Sync rules:**
- If target is already a valid symlink pointing to the correct source → skip (no-op)
- If target is a broken symlink → recreate it
- If target exists as a real file/dir (e.g. `nginx-proxy-manager`) → skip (preserve user content)
- AatosTeam skills synced: `skills/aatosteam/`, `.agents/skills/clawteam-dev/`, `.agents/skills/frontend-design/`

## Reverse sync (Claude Code → Hermes) — promotion flow

Claude Code learns patterns via `ck` (memory bank). skill-sync scans for promotion candidates.

```bash
bash ~/.hermes/skills/skill-sync/scripts/sync.sh reverse
```

**Promotion candidates identified by:**
- `skill-candidate: true` in YAML frontmatter
- `promote_to: <skill-name>` frontmatter field
- `## skill-promo` header

**Workflow:** Candidate flagged → `skill-creator` invoked → new skill created → auto-syncs to Claude Code.

## Quick commands

```bash
bash ~/.hermes/skills/skill-sync/scripts/sync.sh status    # Show all symlinks and sync status
bash ~/.hermes/skills/skill-sync/scripts/sync.sh forward   # Force forward sync
bash ~/.hermes/skills/skill-sync/scripts/sync.sh reverse   # Scan and promote
bash ~/.hermes/skills/skill-sync/scripts/sync.sh install-cron  # Install 15-min cron
bash ~/.hermes/skills/skill-sync/scripts/sync.sh verify     # Verify both directions working
```

## Cron

Runs every 15 min via `power-watchdog` (see `power-watchdog` skill), not standalone cron.
Installs via: `bash ~/.hermes/skills/skill-sync/scripts/sync.sh install-cron`

## Status output

```
=== skill-sync status ===
Forward (Hermes → Claude Code):
  Category symlinks: 37 categories → Claude Code
  Total skills visible to Claude Code: 489/490
  ⚠️  nginx-proxy-manager (real dir in Claude — preserved, not overwritten)
  ✅ aatosteam (AatosTeam tool) → symlinked

Reverse (Claude Code → Hermes):
  ⏭️  No promotion candidates in ck memory-bank
```

## Integration

- Forward sync is called by `power-watchdog` every 15 min
- Reverse sync is called by `power-watchdog` every 1 hour
- skill-sync status is displayed by `power-watchdog` report

## Quick Commands
- `skill-load skill-sync` — Load this skill
