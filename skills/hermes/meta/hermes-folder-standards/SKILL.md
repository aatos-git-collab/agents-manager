---
name: hermes-folder-standards
description: "Hermes directory organization: keep ~/.hermes/skills/ (instructions) strictly separate from ~/.hermes/tools/ (working files, clones, binaries). Skills never hold duplicates of what lives in tools. Applies to all skills and tools."
tags: [organization, structure, hermes, skills, tools]
---

# Hermes Folder Standards

## Core Rule

**Skills = instructions. Tools = working files. Never duplicate.**

```
~/.hermes/skills/    ← skill.md + config + scripts + logs + manifests
~/.hermes/tools/     ← live clones, binaries, data, runtime files
```

## Why

- Clones in `skills/` get duplicated across skill updates → git conflicts, stale copies
- `skills/` is for text/config/scripts, not data or git repos
- `tools/` is the canonical home for anything that runs, syncs, or changes
- Skills reference `tools/` via `manifest.json` or explicit paths

## The Split

| Goes in `skills/` | Goes in `tools/` |
|-------------------|-------------------|
| SKILL.md | Live git clones |
| manifest.json | Binaries / executables |
| scripts/ (automation) | Data files / caches |
| config/ rule templates | Working directories |
| logs/ | Runtime state |
| state.json (if small) | Large state (db dumps, etc.) |

## Critical: Hidden Files When Moving Directories

When moving directories that may contain hidden files (especially `.git`):

```bash
# PROBLEM: glob * does NOT match hidden files like .git
mv /source/* /dest/        # .git stays behind in /source
cd /dest && git remote -v  # FAILS: not a git repo

# SOLUTION: use dotglob or rsync
shopt -s dotglob && mv /source/* /dest/
# OR
rsync -av /source/ /dest/
```

**Always verify after moving any git-related directory:**
```bash
cd /dest && git remote -v  # confirm .git moved with it
git status --short         # confirm repo is intact
```

Then manually remove the source if verification passes.

## Skill Structure Template

```
~/.hermes/skills/<skill-name>/
├── SKILL.md
├── manifest.json           # points to ~/.hermes/tools/<name>
├── scripts/
│   └── runner.py
├── config/
│   ├── rules.templates/
│   └── patterns/
└── logs/
```

```
~/.hermes/tools/<tool-name>/
├── .git/                  # if git clone
├── bin/
├── data/
└── README.md              # minimal — skill has the real docs
```

## Applying This to Rebranding

The `rebranding-tools` skill demonstrates the correct model:

- `SKILL.md` in `skills/rebranding-tools/` — explains what to do
- `manifest.json` — says which repos (in `tools/`) to operate on
- `scripts/watchdog.py` — automation that runs against `~/.hermes/tools/AatosTeam/`
- Actual clone: `~/.hermes/tools/AatosTeam/` — NOT inside the skill

When adding a new rebrand target:
1. Add entry to `manifest.json` (in skill)
2. `git clone` into `~/.hermes/tools/<Name>/` (NOT in skill)
3. Configure remotes in the clone
4. Run rebrand pass via `scripts/watchdog.py`

## Pitfalls

- Moving a git clone with `mv /*` loses `.git` — repo becomes a plain directory
- Storing clones in `skills/` causes git conflicts on `git pull` inside the skill repo
- `state.json` for a rebrand should stay in the skill (small, config-like) not in tools
- Always verify `.git` moved with the directory before deleting the source
## Quick Commands
- `skill-load hermes-folder-standards` — Load this skill
