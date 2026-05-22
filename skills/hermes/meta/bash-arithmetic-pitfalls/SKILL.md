---
name: bash-arithmetic-pitfalls
description: Bash scripting pitfalls that break scripts with `set -e`. Counter increments, arithmetic expressions, and grep pipe failures. Use whenever writing or debugging bash scripts in the Hermes/Claude Code ecosystem.
category: meta
---

# Bash Arithmetic Pitfalls with `set -e`

Scripts in `~/.hermes/skills/*/scripts/*.sh` use `set -euo pipefail`. This causes silent failures in common patterns.

## Pitfall 1: `((x++))` returns exit code 1 when x=0

```bash
set -e
count=0
((count++))   # Exit code 1! Returns 1 but fails because x=0
# Script exits here
```

**Why:** `((expr))` returns exit code 0 if expr≠0, exit code 1 if expr=0. When x=0, `x++` returns 1 (the new value) but the expression result is 0.

**Fix — always use `|| true`:**
```bash
((count++)) || true
```

This applies to ALL arithmetic in `set -e` scripts:
```bash
((total++))   || true
((errors++))  || true
((fixed++))   || true
((heals++))   || true
```

## Pitfall 2: `grep | wc -l` returns 0 on no match

```bash
count=$(grep -c "pattern" file 2>/dev/null)
# If no match: grep exits 1, wc returns 0 — but this is fine
# If file missing: grep exits 2 — THIS fails with set -e
```

**Fix:**
```bash
count=$(grep -c "pattern" "$file" 2>/dev/null || echo 0)
```

## Pitfall 3: `find | wc -l` can return empty with set -e

```bash
count=$(find "$dir" -name "*.md" | wc -l)
# find writes to stdout, wc reads stdin — works
# BUT: find writing to /dev/null might cause issues
```

**Fix (always):**
```bash
count=$(find "$dir" -name "*.md" 2>/dev/null | wc -l || echo 0)
```

## Pitfall 4: Pipeline with grep that might match nothing

```bash
crontab -l | grep "skill-sync"   # Exit code 1 if no match → set -e exits
```

**Fix:**
```bash
crontab -l 2>/dev/null | grep "skill-sync" || true
```

## The Safe Counter Pattern

```bash
#!/bin/bash
set -euo pipefail

# All counters use || true
passed=0; failed=0; skipped=0; fixed=0

increment() { local counter=$1; ((counter++)) || true; }

# In loops:
for item in "${items[@]}"; do
    if condition; then
        ((passed++)) || true
    else
        ((failed++)) || true
    fi
done

# In conditionals:
if ((failed > 0)); then
    echo "FAIL"
fi
```

## The Safe Grep Pattern

```bash
# Count matches (safe with set -e)
count=$(grep -c "pattern" "$file" 2>/dev/null || echo 0)

# Check if pattern exists (safe)
if grep -q "pattern" "$file" 2>/dev/null; then
    echo "found"
fi

# Grep with pipe (safe)
crontab -l 2>/dev/null | grep "pattern" || true
```

## Why These Bugs Hide

With `set -e`, the script exits **silently** at the failing statement. You won't see an error message — the script just stops. This is especially dangerous in:
- Loops (partially completed work)
- Cron jobs (missing log output looks like success)
- Functions that return status

**Rule:** In any bash script using `set -e`, every `((x++))` MUST be followed by `|| true`. Every `grep` pipeline MUST have `|| true` if it might match nothing.
## Quick Commands
- `skill-load bash-arithmetic-pitfalls` — Load this skill
