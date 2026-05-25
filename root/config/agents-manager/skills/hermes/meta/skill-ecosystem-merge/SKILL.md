---
name: skill-ecosystem-merge
description: Safe merge of skill ecosystems between two roots (e.g. current vs backup). Compares by skill NAME, handles path differences, copies only-missing skills, validates YAML frontmatter. Used when restoring from backup or merging skill repos.
version: 1.0.0
category: meta
author: Aatos CTO
triggers:
  - merge skills from backup
  - restore skills from git backup
  - compare skill ecosystems
  - copy missing skills between repos
  - validate skill frontmatter at scale
---

# Skill Ecosystem Merge

Merge two skill ecosystems safely — current + reference backup — without overwriting existing skills.

## Core Principle

**Match by NAME (frontmatter), not by PATH.**

The same skill often lives at different paths in different repos:
- `/root/.hermes/skills/verification-loop/SKILL.md` (current)
- `/tmp/agents-backup/software-development/SKILL.md` (backup)

Both have `name: verification-loop`. They are the SAME skill. Path differs, content may differ.

---

## Merge Protocol

### Step 1: Accurate Comparison (Python — REQUIRED)

Bash `find` and `diff` give WRONG answers for skill comparison. Use Python:

```python
import os, yaml, hashlib
from pathlib import Path

def get_all_skills(base_path):
    """Find ALL SKILL.md files. Match by frontmatter name, not path."""
    skills = {}
    for skill_md in Path(base_path).rglob("SKILL.md"):
        rel = skill_md.relative_to(base_path)
        parts = rel.parts
        category = parts[0] if len(parts) > 1 else "top-level"
        
        content = skill_md.read_text(encoding="utf-8", errors="ignore")
        name = None
        if content.startswith("---"):
            try:
                _, fm_text, _ = content.split("---", 2)
                fm = yaml.safe_load(fm_text)
                if fm: name = fm.get("name", "")
            except:
                pass
        if not name:
            name = rel.parent.parts[-1] if len(parts) > 1 else "top-level"
        
        content_hash = hashlib.md5(content.encode()).hexdigest()
        info = {
            "name": name,
            "category": category,
            "content_hash": content_hash,
            "content_len": len(content),
            "rel_path": str(rel)
        }
        
        # Deduplicate by name — if name collides, qualify with category
        key = name
        if key in skills:
            key = f"{category}/{name}"
        skills[key] = info
    
    return skills

current = get_all_skills("/root/.hermes/skills")
backup = get_all_skills("/tmp/agents-backup")

# Classify
cur_names = {v["name"] for v in current.values()}
bak_names = {v["name"] for v in backup.values()}
common_names = cur_names & bak_names

SAME = []
MODIFIED = []
ONLY_CURRENT = []
ONLY_BACKUP = []

for name in common_names:
    c = next((v for k,v in current.items() if v["name"] == name), None)
    b = next((v for k,v in backup.items() if v["name"] == name), None)
    if c["content_hash"] == b["content_hash"]:
        SAME.append(name)
    else:
        MODIFIED.append(name)

ONLY_CURRENT = [v["name"] for v in current.values() if v["name"] not in bak_names]
ONLY_BACKUP = [v["name"] for v in backup.values() if v["name"] not in cur_names]

print(f"Current={len(current)}, Backup={len(backup)}")
print(f"SAME={len(SAME)}, MODIFIED={len(MODIFIED)}, ONLY_CURRENT={len(ONLY_CURRENT)}, ONLY_BACKUP={len(ONLY_BACKUP)}")
```

Expected output: SAME (identical content), MODIFIED (same name, different content — review manually), ONLY_CURRENT (keep all — custom-built), ONLY_BACKUP (copy these — missing from current).

### Step 2: Safe Copy (Directory AND File Level)

Skills can be:
1. **Directory skills** — entire subdirectory with SKILL.md + scripts/
2. **File-level skills** — a single SKILL.md file inside an existing category directory

The subagent error: only copying directories misses file-level SKILL.md files that live inside existing category dirs.

**Safe copy algorithm:**
```bash
# For each ONLY_BACKUP skill:
DEST="/root/.hermes/skills/$RELATIVE_PATH_FROM_BACKUP"
if [ -f "$DEST" ]; then
    echo "SKIP (file exists): $DEST"
elif [ -d "$DEST" ]; then
    echo "SKIP (dir exists): $DEST"
else
    mkdir -p "$(dirname "$DEST")"
    cp -r "$SRC_DIR_OR_FILE" "$DEST"
    echo "COPIED: $DEST"
fi
```

### Step 3: Validate YAML Frontmatter

Category-level SKILL.md files from backup often have NO frontmatter or missing `name:` field.

**Fix all missing frontmatter at once:**
```python
from pathlib import Path

SKILLS = Path("/root/.hermes/skills")
for skill_md in SKILLS.rglob("SKILL.md"):
    content = skill_md.read_text(encoding="utf-8", errors="ignore")
    
    if not content.startswith("---"):
        # No frontmatter — add it
        name = skill_md.parent.name
        heading = ""
        for line in content.split("\n"):
            if line.startswith("# "):
                heading = line[2:].strip()
                break
        
        new_content = f"""---
name: {name}
description: {heading or name.replace("-", " ").replace("_", " ").title()}
---

{content}"""
        skill_md.write_text(new_content)
        print(f"Added frontmatter: {skill_md}")
        continue
    
    # Has frontmatter but missing name:
    parts = content.split("---", 2)
    if len(parts) >= 3 and "name:" not in parts[1]:
        fm_text = parts[1]
        body = parts[2]
        name = skill_md.parent.name
        
        fm_lines = fm_text.strip().split("\n")
        fm_lines.insert(0, f"name: {name}")
        
        new_content = f"---\n" + "\n".join(fm_lines) + "\n---\n" + body
        skill_md.write_text(new_content)
        print(f"Added name to frontmatter: {skill_md}")
```

### Step 4: Run skill-health

```bash
bash /root/.hermes/skills/skill-health/scripts/test.sh run 2>&1 | tail -3
```

Goal: 0 failures. Warnings (missing Quick Commands) are acceptable — fix separately.

### Step 5: Git Backup

```bash
cd /tmp/agents-backup  # already a git clone with origin configured
cp -r /root/.hermes/skills/* .
git add -A
git commit -m "Merge: $(find . -name 'SKILL.md' | wc -l) skills — $(date +%Y-%m-%d)"
git push origin skill-branch
```

---

## Common Mistakes

1. **Matching by path hash** — gives wrong counts. Same skill at different paths = different hash = falsely reported as "different". Always match by `name:` frontmatter field.

2. **Only copying directories** — SKILL.md files at category level (e.g. `mlops/SKILL.md`) are inside existing dirs. Copying directories skips these file-level additions.

3. **Overwriting existing skills** — ALWAYS check if destination exists before copying. ONLY copy if NOT present.

4. **Using bash arithmetic in `set -e` scripts** — `((x++))` returns exit code 1 when x=0, causing premature exit. Use `((x++)) || true`.

5. **`echo "..." | crontab -` only installs one line** — use file-based: `crontab /tmp/new_crontab`.

6. **`SKILL_DIR` env var pollution** — if set, `find` looks inside the skill-health skill itself. Unset before running: `SKILL_DIR= bash test.sh`.

---

## Decision Tree

```
Is skill in current? 
  YES → Does content match?
    SAME (hash equal) → Keep current, do nothing
    MODIFIED (hash diff) → Compare lengths:
      Current is longer → Keep current (we improved it)
      Backup is longer → Review manually, decide per-skill
      Both are stubs (<200 chars) → Replace with backup
  NO  → Is it in backup?
    YES → Copy to current (safe — doesn't exist here)
    NO  → Error — shouldn't happen
```

---

## Verification Checklist

- [ ] Python comparison gave accurate counts (name-based, not path-based)
- [ ] Directory skills copied (entire subdirs)
- [ ] File-level SKILL.md files copied (inside existing category dirs)
- [ ] All SKILL.md have valid frontmatter with `name:` field
- [ ] skill-health: 0 failures
- [ ] Git backup pushed to agents-backup skill-branch
- [ ] skill-sync ran to propagate to Claude Code symlinks
## Quick Commands
- `skill-load skill-ecosystem-merge` — Load this skill
