#!/usr/bin/env python3
"""
skill-healer — Self-healing autofixer for Hermes skills ecosystem.
Fixes: missing Quick Commands, empty descriptions, missing YAML frontmatter.
"""
import re, sys, os
from pathlib import Path

SKILLS_DIR = Path(os.environ.get("SKILLS_DIR", "/root/.hermes/skills"))
DRY_RUN = "--dry-run" in sys.argv
VERBOSE = "--verbose" in sys.argv or "-v" in sys.argv

fixed = skipped = failed = 0

def get_fm(content):
    if content.startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            fm = {}
            for line in parts[1].split("\n"):
                if ": " in line:
                    idx = line.index(": ")
                    k = line[:idx].strip()
                    v = line[idx+1:].strip().strip('"').strip("'")
                    fm[k] = v
            return fm
    return {}

def has_fm(content):
    return content.startswith("---")

def has_qc(content):
    return bool(re.search(r"^## (Quick Commands|Usage|Commands)", content, re.M))

def is_empty_desc(desc):
    return not desc or len(desc) < 3 or desc == "empty"

def skill_name_from_path(path):
    parts = str(path).split("/")
    try:
        idx = parts.index("skills")
        return parts[idx+1]
    except (ValueError, IndexError):
        return parts[-1]

def heal_skill(skill_path):
    global fixed, skipped, failed
    sf = skill_path / "SKILL.md"
    if not sf.exists():
        return

    content = sf.read_text(errors="ignore")
    fm = get_fm(content)
    name = fm.get("name", "") or skill_name_from_path(skill_path)
    desc = fm.get("description", "") or ""

    issues = []
    if not has_fm(content): issues.append("no-fm")
    if is_empty_desc(desc): issues.append("empty-desc")
    if not has_qc(content): issues.append("no-qc")

    if not issues:
        if VERBOSE:
            print(f"  ok   {name}")
        skipped += 1
        return

    if DRY_RUN:
        print(f"[DRY] {name} — would fix: {', '.join(issues)}")
        return

    print(f"healing {name} ({', '.join(issues)})")

    # Fix frontmatter
    if not has_fm(content):
        new_fm = f"---\nname: {name}\ndescription: {desc or name + ' skill'}\n---\n"
        content = new_fm + content
        print(f"  + frontmatter added")

    fm = get_fm(content)
    desc = fm.get("description", "") or ""

    # Fix empty description
    if is_empty_desc(desc) and has_fm(content):
        content = re.sub(r"^description:.*$", f"description: {name} skill", content, flags=re.M)
        print(f"  + description fixed")

    # Fix missing Quick Commands
    if not has_qc(content):
        qc_text = f"\n## Quick Commands\n- `skill-load {name}` — Load this skill\n"
        content = content.rstrip() + qc_text
        print(f"  + Quick Commands added")

    sf.write_text(content)
    fixed += 1

skill_files = sorted(SKILLS_DIR.rglob("SKILL.md"))
print(f"Found {len(skill_files)} SKILL.md files")
print()

if DRY_RUN:
    print("DRY-RUN — no changes will be made\n")

for sf in skill_files:
    heal_skill(sf.parent)

print()
print("=" * 40)
print(f"  Fixed:   {fixed}")
print(f"  Skipped: {skipped}")
print(f"  Failed:  {failed}")
print("=" * 40)
