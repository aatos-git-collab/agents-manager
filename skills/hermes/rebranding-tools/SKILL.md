---
name: rebranding-tools
description: rebranding-tools skill
  Rebranding pipeline — monitors upstream repos, applies rename/replace rules, logs diffs,
  pushes to origin, then syncs agent definitions to skills/. Also self-heals the tool by
  checking and repairing git state, dependencies, and profiles. Use when the user wants to
  rebrand, sync, track, or update a source repo to a branded fork, run the watchdog, check
  health, self-heal, or manually trigger tool↔skill sync.
tags: [rebrand, sync, watchdog, self-heal, git, clone, fork]
---

# Rebranding Tools

Self-healing bidirectional sync pipeline.

## Storage Model

```
~/.hermes/tools/                   ← live git clones (actual code)
~/.hermes/skills/rebranding-tools/ ← skill: SKILL.md + manifest + scripts + logs
~/.hermes/skills/<target>/         ← synced agent defs + refs (auto-generated)
```

Skill = instructions + config. Tools = actual clones. Never duplicate.

## Directory Structure

```
~/.hermes/skills/rebranding-tools/
├── SKILL.md
├── manifest.json              ← repo configs + rebrand rules
├── state.json                ← last-processed commit (auto-created)
├── scripts/
│   ├── watchdog.py           ← upstream → rebrand → push → sync
│   └── sync_to_skills.py    ← bidirectional sync engine
├── logs/                      ← dated diff reports
└── config/                    ← reusable rule templates + patterns
    ├── rules.templates/
    └── patterns/
```

## Bidirectional Sync

### Tool → Skill (watchdog, every 6h)

```
Upstream (HKUDS/ClawTeam) new commits
  → git pull upstream
  → apply rebrand rules (clawteam→aatosteam, etc.)
  → git commit + push to origin (aatos-git-collab/AatosTeam)
  → sync_to_skills.py (tool→skill)
  → agent YAMLs, CLI refs, SKILL.md synced to ~/.hermes/skills/autonomous-ai-agents/aatosteam/
```

### Skill → Tool (before every use)

```
aatosteam skill loaded
  → sync_to_skills.py --repo AatosTeam --check
  → verifies: git clean, deps installed, profiles valid
  → if broken: --fix auto-repairs
```

## Quick Commands

```bash
# === Self-heal (skill → tool) ===
# Check health before using aatosteam
python ~/.hermes/skills/rebranding-tools/scripts/sync_to_skills.py --repo AatosTeam --check

# Self-heal + repair
python ~/.hermes/skills/rebranding-tools/scripts/sync_to_skills.py --repo AatosTeam --fix

# === Tool → skill sync (manual) ===
python ~/.hermes/skills/rebranding-tools/scripts/sync_to_skills.py --repo AatosTeam

# === Watchdog (upstream → rebrand → push → sync) ===
# One-shot sync
python ~/.hermes/skills/rebranding-tools/scripts/watchdog.py --repo AatosTeam

# Dry run
python ~/.hermes/skills/rebranding-tools/scripts/watchdog.py --repo AatosTeam --dry-run

# Full rebrand pass (all files)
python ~/.hermes/skills/rebranding-tools/scripts/watchdog.py --repo AatosTeam --full

# Re-initialize / re-clone
python ~/.hermes/skills/rebranding-tools/scripts/watchdog.py --repo AatosTeam --init

# Background run
nohup python ~/.hermes/skills/rebranding-tools/scripts/watchdog.py --repo AatosTeam > /tmp/rebrand_ClawTeam.log 2>&1 &
```

## Repo Config (manifest.json)

Each repo entry defines:
- `source` — upstream URL to track
- `origin_url` — your rebranded fork URL
- `local_path` — path to the live clone in `~/.hermes/tools/`
- `skill_sync_target` — which skill folder to sync agent defs into
- `rebrand_rules` — ordered list of rename/replace operations
- `watch.schedule` — cron schedule

**Rule types:**
- `rename_dir` — rename directory trees
- `content_replace` — regex replace in file content (`i` = case-insensitive, `g` = global)

## ClawTeam → AatosTeam Details

**Upstream:** `https://github.com/HKUDS/ClawTeam.git`
**Origin:** `https://github.com/aatos-git-collab/AatosTeam.git`
**Clone path:** `~/.hermes/tools/AatosTeam`
**Skill sync target:** `~/.hermes/skills/autonomous-ai-agents/aatosteam/`

**What the rebrand changes:**
1. `clawteam/` dir → `aatosteam/`
2. `claw-team/` dir → `aatos-team/`
3. All content: `clawteam` → `aatosteam`, `ClawTeam` → `AatosTeam`, `claw_team` → `aatos_team`

**Synced to skill after each watchdog push:**
- `agents/*.yaml` → `~/.hermes/skills/autonomous-ai-agents/aatosteam/agents/`
- `references/*.md` → `~/.hermes/skills/autonomous-ai-agents/aatosteam/references/`
- `SKILL.md` → `~/.hermes/skills/autonomous-ai-agents/aatosteam/SKILL.md` (if version newer)

## Checking Status

```bash
# Last watchdog run state
cat ~/.hermes/skills/rebranding-tools/state.json

# Recent watchdog logs
ls -lt ~/.hermes/skills/rebranding-tools/logs/

# Git status of tool
git -C ~/.hermes/tools/AatosTeam status --short
git -C ~/.hermes/tools/AatosTeam log --oneline -5

# Compare upstream vs origin
git -C ~/.hermes/tools/AatosTeam log upstream/main --oneline -5
git -C ~/.hermes/tools/AatosTeam log origin/main --oneline -5

# Synced skill contents
find ~/.hermes/skills/autonomous-ai-agents/aatosteam -type f | sort
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `aatosteam: MISSING` | `pip install -e ~/.hermes/tools/AatosTeam --break-system-packages` |
| Local uncommitted changes | `sync_to_skills.py --fix` (resets to origin/main) |
| Behind upstream | Run watchdog once: `watchdog.py --repo AatosTeam` |
| Files not rebranded | Check file extensions — binary files are skipped |
| Skill not updated after push | Run `sync_to_skills.py --repo AatosTeam` manually |
| Crontab not running | `crontab -e` — verify watchdog cron entry exists |

## Cron Setup (watchdog auto-run)

```bash
crontab -e

# Every 6 hours: upstream → rebrand → push → sync to skills
0 */6 * * * python ~/.hermes/skills/rebranding-tools/scripts/watchdog.py --repo AatosTeam >> ~/.hermes/skills/rebranding-tools/logs/cron.log 2>&1

# Verify
crontab -l
```

## Diff Report Format

Each log (`logs/<Repo>_YYYYMMDD_HHMMSS.log`) contains:
- Timestamp, upstream commit range, commits synced, files changed, errors

## Reusable Rule Templates

Templates in `config/rules.templates/`:

| Template | Description | Variables |
|----------|-------------|------------|
| `org-rename` | Rename org handle everywhere | `{{from_org}}` → `{{to_org}}` |
| `dir-case-swap` | Swap dir name case variants | `{{from}}` → `{{to}}` |

## Regex Pattern Library

Patterns in `config/patterns/`:
- `github-handles.re` — matches `@org` / `github.com/org` patterns
- `import-paths.re` — matches `from X import` / `require('X')` patterns

## Pitfalls

- Binary files (`.png`, `.jpg`, `.ico`, `.lock`, `.wasm`, `.pyc`) are **always skipped**
- Large repos: use `--dry-run` first to check scope
- `state.json` deletion forces re-processing all upstream commits from scratch
- If upstream force-pushes, `state.json` becomes stale → re-process (normal and safe)
- The `aatosteam/` directory rename must stay in sync with CI (`ci.yml`) and hardcoded paths
