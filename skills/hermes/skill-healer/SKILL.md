---
name: skill-healer
description: Self-healing autofixer for Hermes skills ecosystem
---

## What it does

Auto-fixes missing Quick Commands, empty descriptions, and missing frontmatter in Hermes skills. Ensures all skills conform to the skill specification by healing common issues automatically.

## How it works

1. Reads each skill's `SKILL.md` file
2. Detects issues: missing Quick Commands section, empty description, missing YAML frontmatter
3. Auto-adds Quick Commands section using skill name and description from frontmatter
4. Auto-fixes description if empty
5. Skips skills that already have Quick Commands (idempotent)

## Usage

```bash
# Full heal - fix ALL skills in /root/.hermes/skills/
./heal.sh

# Single skill - fix just one skill by name
./heal.sh skill-name

# Dry-run mode - shows what would change without making changes
./heal.sh --dry-run

# Single skill dry-run
./heal.sh --dry-run skill-name
```

## Integration

The `power-watchdog` skill calls this when `skill-health` reports failures. This creates a self-healing loop where:

1. `skill-health` detects skill issues
2. `power-watchdog` triggers `skill-healer`
3. `skill-healer` auto-fixes the issues
4. System recovers automatically

## Quick Commands

- `skill-load skill-healer` — Load this skill
