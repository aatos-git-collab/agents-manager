---
name: skill-optimizer
description: Self-improvement engine for the Hermes ↔ Claude Code skill ecosystem. Analyzes watchdog logs, skill-health reports, and daily memory to identify broken patterns, propose new skills, and auto-apply fixes. Runs weekly. Use when "improve skills" / "fix broken patterns" / "analyze skill health" / "propose new skills".
category: meta
---

# skill-optimizer — Self-Improvement Engine

> The system learns what breaks. The system fixes what it learns.

## What it does

```
skill-optimizer (weekly)
    ├── Reads: watchdog.log → patterns of failures
    ├── Reads: skill-health-*.json → broken skills
    ├── Reads: daily/*.md → recurring pain points
    ├── Reads: skill-sync.log → sync failures
    └── Proposes: new skills / skill fixes / workflow improvements
```

## Pattern detection

| Pattern | Root cause | Action |
|---------|-----------|--------|
| Same cron dying repeatedly | Script bug | Fix script + alert |
| Skill with 3+ health failures | Abandoned skill | Archive or fix |
| Claude Code can't use a skill | Format mismatch | Create adapter skill |
| Same heal repeating | Fundamental issue | Address root cause |
| Missing watchdog for new system | Gap in coverage | Create watchdog skill |
| 5+ skills with same warn | Missing template | Update template |

## Quick commands

```bash
# Run analysis and generate improvement plan
bash ~/.hermes/skills/skill-optimizer/scripts/optimize.sh run

# Show only actionable items
bash ~/.hermes/skills/skill-optimizer/scripts/optimize.sh actions

# Auto-apply simple fixes (chmod, symlink repair)
bash ~/.hermes/skills/skill-optimizer/scripts/optimize.sh apply

# Install weekly cron
bash ~/.hermes/skills/skill-optimizer/scripts/optimize.sh install-cron
```

## Output

```
=== skill-optimizer [2026-04-24] ===
Sources analyzed:
  - watchdog.log (30 days)
  - skill-health-latest.json
  - daily/*.md (7 days)
  - skill-sync.log (30 days)

Patterns found: 4
  🔴 cron-die: hermes-memory watchdog (3x this month)
  🟡 skill-gap: No watchdog for graphify-bootstrap
  🟡 skill-gap: skill-sync has no self-heal
  🟢 stale-skill: pawnshop-nav-debug (unchanged 60d, no references)

Improvements proposed: 3
  1. [AUTO-FIX] Make all skill scripts executable → APPLIED
  2. [PROPOSE] Create graphify-bootstrap watchdog cron → REVIEW
  3. [ARCHIVE] Archive pawnshop-nav-debug → REVIEW

Report: ~/.hermes/memory/skill-optimizer-YYYY-MM-DD.json
```

## Quick Commands
- `skill-load skill-optimizer` — Load this skill
