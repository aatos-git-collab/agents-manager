---
name: config-backup-restore
description: Auto-backup, diff, and self-heal Hermes config + skills. Restores from /tmp/agents-backup-restore/ (chro branch) on github.com/aatos-git-collab/agents-backup.git. Triggers on: startup, cron schedule, or manual invoke.
---

# Config Backup Restore Skill

Self-healing backup system for Hermes configuration. Backs up config.yaml, SOUL.md, skills, memory, and user files. Detects drift and auto-restores from the canonical backup repo.

## Backup Repo Anatomy

The backup repo `github.com/aatos-git-collab/agents-backup.git` is a **bare git repo** stored at `/tmp/agents-backup-check/`. It has multiple branches:
- `chro` — primary working branch (checked out by this skill)
- `hermes-custom` — alternate
- `skill-branch` — alternate
- `stealth-browser-chro` — alternate

The bare repo must be **cloned** (not pulled into directly) to get a working tree. The clone target is `/tmp/agents-backup-restore/`.

## Backup Sources

| Type | Location |
|------|----------|
| Primary backup repo | `github.com/aatos-git-collab/agents-backup.git` (branch: `chro`) |
| Bare repo (do not use directly) | `/tmp/agents-backup-check/` |
| Working clone | `/tmp/agents-backup-restore/` |
| Local backup | `~/.hermes/backup/` (created by this skill) |
| Manifest tracking | `~/.hermes/skills/config-backup-restore/manifests/backup-manifest.json` |

## Commands

```bash
# Full self-heal (backup → detect drift → restore)
bash ~/.hermes/skills/config-backup-restore/scripts/self-heal.sh

# Backup current state only
bash ~/.hermes/skills/config-backup-restore/scripts/backup-only.sh

# Restore from backup repo only
bash ~/.hermes/skills/config-backup-restore/scripts/restore-from-backup.sh

# Check what differs between current and backup
bash ~/.hermes/skills/config-backup-restore/scripts/diff-check.sh

# View backup manifest
cat ~/.hermes/skills/config-backup-restore/manifests/backup-manifest.json
```

## What Gets Backed Up

- `~/.hermes/config.yaml` — main Hermes config
- `~/.hermes/SOUL.md` — Aatos CTO personality
- `~/.hermes/USER.md` — user profile
- `~/.hermes/USER-HABITS.md` — user habits
- `~/.hermes/memories/` — memory files
- `~/.hermes/skills/` — all skills (except this skill itself)
- `~/.hermes/hermes-agent/agent/ceo/` — CEO agent files
- `~/.hermes/.env` — secrets (encrypted reference, not content)
- `~/.git-hooks/pre-push` — git push safety hook

## Auto-Heal Triggers

1. **Startup**: On Hermes boot, if last backup > 24h old
2. **Cron**: Every 6 hours via `config-backup-restore-watchdog` cron job
3. **Manual**: User invokes skill or runs self-heal command
4. **Crash recovery**: On terminal reconnect after crash

## Self-Heal Logic

```
1. Pull latest from backup repo (chro branch)
2. Compare current files vs backup files (MD5)
3. If drift detected:
   a. Log what changed
   b. Auto-restore config.yaml, SOUL.md, USER.md, USER-HABITS.md
   c. Restore missing skills (diff skills/ count)
   d. Restore CEO agent files if missing
   e. Verify hermes-browser camofox health (port 9377)
   f. Verify git push safety hook is installed
4. Report: [BACKUP OK] / [RESTORED X FILES] / [ACTION REQUIRED]
```

## Config Merge Strategy

**CRITICAL RULE — NEVER auto-downgrade config:**

When restoring config.yaml, always compare `_config_version` numbers first:
- If `current_version > backup_version` → **keep current** (newer is better)
- If `backup_version > current_version` → restore backup
- If equal → either is fine

Specific overrides:
- `reasoning_effort`: if backup had `xhigh` and current has `high`, prefer `xhigh` (user preference — restore it)
- `compression.threshold`: prefer `0.75` over `0.5` (less aggressive, fewer compressions)
- `auxiliary.*.timeout`: prefer higher values (120-360s over 30s)
- `summary_model`: prefer MiniMax-M2.7 with explicit minimax provider (no extra API key)
- `stealth-browser` section: if completely absent in current but present in backup, restore it

## Pitfalls

- `~` does NOT expand in cp commands — use `$HOME` or absolute paths
- Backup repo may have older agent/*.py — never overwrite newer versions
- Skills self-heal: missing skills are restored, but modified skills are NOT overwritten (preserve custom changes)
- Config restore: NEVER auto-restore config.yaml if backup is older version — merge manually

## Manifest Format

```json
{
  "last_backup": "2026-04-23T06:00:00Z",
  "last_restore": null,
  "backup_commit": "b2e4daadb22450bfbe12d2de8775b66624792a26",
  "files_tracked": ["config.yaml", "SOUL.md", "USER.md", ...],
  "skills_count": 52,
  "drift_events": []
}
```

## Cron Setup

This skill auto-sets up its own cron job on first run:

```bash
# Cron: every 6 hours
0 */6 * * * bash ~/.hermes/skills/config-backup-restore/scripts/self-heal.sh >> ~/.hermes/skills/config-backup-restore/logs/cron.log 2>&1
```

## Quick Commands
- `skill-load config-backup-restore` — Load this skill
