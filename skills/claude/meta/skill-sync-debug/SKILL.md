---
name: skill-sync-debug
description: Debug why Hermes skills aren't syncing to Claude Code. Use when "skills not showing in claude code" / "only X skills visible" / "symlinks broken" / "skill sync failing". Diagnoses the real state vs reported state, fixes broken status scripts, and heals broken symlinks.
category: meta
---

# skill-sync-debug — Diagnose Hermes → Claude Code Skill Sync Issues

## The Core Problem Pattern

**Symptom:** "Only 65 skills visible in Claude Code but we have 400+"
**Root cause found (2026-04-24):** This is almost always a **false negative from a broken status script**, not an actual sync problem.

The real architecture:
```
~/.hermes/skills/ (69 top-level dirs)
  ├── marketing/ (category dir — symlinked to ~/.claude/skills/)
  │   ├── ads-google/SKILL.md
  │   ├── ads-meta/SKILL.md
  │   └── ... (34 total)
  ├── mlops/ (category dir — symlinked)
  │   ├── training/SKILL.md
  │   └── ... (41 total)
  └── [37 categories × nested skills] ≈ 489 total
```

Claude Code sees ALL nested skills through category symlinks. The 65 count was the top-level dir count, not the actual skill count.

## Diagnostic Steps

```bash
# 1. Get the REAL count (Python avoids bash find bugs)
python3 -c "
import os
hermes = os.path.expanduser('~/.hermes/skills')
claude = os.path.expanduser('~/.claude/skills')
total_hermes = 0
via_symlinks = 0
for cat in os.listdir(hermes):
    hp = os.path.join(hermes, cat)
    if not os.path.isdir(hp): continue
    total_hermes += sum(1 for r,_,f in os.walk(hp) if 'SKILL.md' in f)
    cp = os.path.join(claude, cat)
    if os.path.islink(cp) and os.path.realpath(cp) == hp:
        via_symlinks += sum(1 for r,_,f in os.walk(hp) if 'SKILL.md' in f)
print(f'Hermes total: {total_hermes}')
print(f'Via Claude symlinks: {via_symlinks}')
"

# 2. Check if symlinks resolve correctly
ls -la ~/.claude/skills/marketing/
find ~/.claude/skills/marketing/ -name "SKILL.md" | wc -l  # Should show 34

# 3. Run the actual sync (force)
bash ~/.hermes/skills/skill-sync/scripts/sync.sh forward

# 4. Run power-watchdog to verify everything
bash ~/.hermes/skills/power-watchdog/scripts/watch.sh run
```

## Common Bugs Found

### Bug 1: `find` returning 0 (status script false negative)

**Bad:**
```bash
count=$(find "$cat" -name "SKILL.md" | wc -l)  # Can return 0 if find fails
```

**Good (Python):**
```python
import os
count = sum(1 for r, _, f in os.walk(path) if 'SKILL.md' in f)
```

**Good (bash with fallback):**
```bash
count=$(find "$cat" -name "SKILL.md" 2>/dev/null | wc -l || echo 0)
```

### Bug 2: Category dirs counted as skills

**Bad:** Loop over `~/.hermes/skills/*/` and count all dirs as skills.
**Fix:** Only count dirs that have `SKILL.md` at the top level.

```bash
# Skip category dirs (no SKILL.md at top)
for dir in ~/.hermes/skills/*/; do
    [ -f "$dir/SKILL.md" ] || continue  # skip category dirs
    # it's a real skill
done
```

### Bug 3: `((x++))` with `set -e` aborts on first increment

When `x=0`, `((x++))` evaluates to 1 but returns exit code 1. With `set -e`, the script exits.

**Always use:**
```bash
((x++)) || true
```

This affects counters in loops and status functions.

### Bug 4: Cron management — substring grep removes wrong lines

```bash
# WRONG: removes ANY line containing "skill-sync"
(crontab -l | grep -v "skill-sync") | crontab -

# RIGHT: remove only the exact line
current=$(crontab -l 2>/dev/null || true)
current=$(echo "$current" | grep -vF "exact cron line text")
echo "$current" | crontab -
```

Use `grep -vF` (fixed string, not regex) for cron removal.

## Self-Heal Commands

```bash
# Force full sync
bash ~/.hermes/skills/skill-sync/scripts/sync.sh forward

# Check all crons
crontab -l 2>/dev/null | grep -v "^#"

# Check symlink validity
python3 -c "
import os
hermes = os.path.expanduser('~/.hermes/skills')
claude = os.path.expanduser('~/.claude/skills')
for name in os.listdir(hermes):
    hp = os.path.join(hermes, name)
    cp = os.path.join(claude, name)
    if os.path.islink(cp) and not os.path.exists(cp):
        print(f'BROKEN: {name}')
    elif not os.path.exists(cp):
        print(f'MISSING: {name}')
"
```
## Quick Commands
- `skill-load skill-sync-debug` — Load this skill
