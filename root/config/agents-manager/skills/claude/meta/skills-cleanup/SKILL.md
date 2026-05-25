---
name: skills-cleanup
description: Reorganize, nest, or consolidate Hermes skills directories. Use when skills are flat, orphaned, or miscategorized.
triggers:
  - "organize skills"
  - "cleanup skills"
  - "nest skills"
  - "reorganize skills"
  - "group skills"
---

# Skills Cleanup Playbook

## Principle
**Observe → Move → Fix → Verify → Report.**
Never enumerate everything. Only report what changed and what remains problematic.

## Rules
1. Every skill is either a **category** (has sub-skills) or a **sub-skill** (inside a category)
2. Genuine top-level categories: `aatos`, `agent-brains`, `autonomous-ai-agents`, `github`, `mlops`, `security`, `marketing`, `productivity`, `software-development`, `meta`, `devops`, etc. — these hold sub-skills
3. A skill that is NOT a genuine top-level category and has no sub-skills should NOT be flat at top level — move it into the correct parent category
4. If no existing category fits, create a new one
5. When moving a skill, update all path references in its SKILL.md

## Execution

### Step 1 — Identify moves (execute_code)
```python
import os, shutil

hermes = os.path.expanduser("~/.hermes/skills")
moves = []  # (src, dst) tuples

# Example: move aatosteam/ → autonomous-ai-agents/aatosteam/
src = f"{hermes}/aatosteam"
dst = f"{hermes}/autonomous-ai-agents/aatosteam"
if os.path.exists(src) and not os.path.exists(dst):
    shutil.move(src, dst)
    moves.append((src, dst))
```

### Step 2 — Fix path references in moved SKILL.md
After moving, update any hardcoded path references in the skill's own SKILL.md.

### Step 3 — Fix global pre-push hook if git-safety moved
If git-safety was moved, update `~/.git/hooks/pre-push` — it likely references the old path.

### Step 4 — Update referring skills
Check and update any other SKILL.md that references the old path:
```bash
grep -r "old/path" ~/.hermes/skills/ --include="*.md" -l
```

### Step 5 — Verify
```python
# Verify the skill loads
import subprocess
result = subprocess.run(
    ["python3", f"{hermes}/rebranding-tools/scripts/sync_to_skills.py", "--repo", "AatosTeam", "--check"],
    capture_output=True, text=True
)
print(result.stdout)
```

### Step 6 — Report
Only report:
- What was moved
- Any references that needed fixing
- What still needs attention
- Final structure (just the changed section)

## Common Moves (Reference)
| Skill | From | To |
|-------|------|-----|
| aatosteam | `skills/aatosteam/` | `skills/autonomous-ai-agents/aatosteam/` |
| git-safety | `skills/git-safety/` | `skills/github/git-safety/` |
| webbuilder-* | `skills/webbuilder-*/` | `skills/projects/webbuilder/*/` |

## Pitfalls
- Don't enumerate all categories — only report what changed
- Global pre-push hook breaks silently when git-safety moves (always check `~/.git/hooks/pre-push`)
- Symlinks in `~/.git/hooks/` are NOT followed by `cat` — use `ls -la ~/.git/hooks/`
## Quick Commands
- `skill-load skills-cleanup` — Load this skill
