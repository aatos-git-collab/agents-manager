---
name: skill-health
description: Automated test suite for all 490 Hermes skills. Verifies SKILL.md syntax, required files, script executability, and reference links. Runs weekly + after new skill creation. Reports pass/fail to memory/daily and to skill-optimizer for improvement decisions.
category: meta
---

# skill-health — Automated Skill Testing

> Every skill gets tested. Every failure gets fixed or flagged.

## What it tests

For every skill (`SKILL.md` found in `~/.hermes/skills/`):

| Check | Pass | Fail Action |
|-------|------|-------------|
| `SKILL.md` exists | ✅ | ❌ Flag skill as broken |
| YAML frontmatter valid | ✅ | ❌ Log parse error |
| `name:` field present | ✅ | ❌ Flag missing name |
| `description:` not empty | ✅ | ⚠️ Warn (cosmetic) |
| Required scripts exist (if skill has scripts/) | ✅ | ❌ Flag missing script |
| Scripts are executable | ✅ | 🔧 Auto-fix chmod |
| SKILL.md has required sections | ⚠️ | ⚠️ Warn (cosmetic) |
| References files exist (if listed) | ✅ | ⚠️ Warn |

## Quick commands

```bash
# Run full test suite
bash ~/.hermes/skills/skill-health/scripts/test.sh run

# Quick status (no full run)
bash ~/.hermes/skills/skill-health/scripts/test.sh quick

# Run only broken skills (from last run)
bash ~/.hermes/skills/skill-health/scripts/test.sh broken

# Install weekly cron
bash ~/.hermes/skills/skill-health/scripts/test.sh install-cron
```

## Output

```
=== skill-health [2026-04-24 17:45] ===
Tested: 490 skills | ✅ Pass: 487 | ❌ Fail: 1 | ⚠️ Warn: 2

❌ BROKEN: pawnshop-global-styling (missing script: run.sh)
⚠️ WARN: aatosteam-orchestration (no description)
⚠️ WARN: design-system (missing references/checklist section)

Full report: ~/.hermes/memory/skill-health-YYYY-MM-DD.json
```

## Integration

- Called by `power-watchdog` every 2 hours
- Called by `skill-optimizer` before improvement analysis
- Results written to `~/.hermes/memory/skill-health-YYYY-MM-DD.json`
- Summary written to `~/.hermes/memory/daily/YYYY-MM-DD.md`

## Quick Commands
- `skill-load skill-health` — Load this skill
