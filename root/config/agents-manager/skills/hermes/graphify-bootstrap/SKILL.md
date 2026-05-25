---
name: graphify-bootstrap
description: Auto-setup graphify knowledge graph for any new project. Use when starting a new project, cloning a repo, or when user says "set up graphify" / "bootstrap this project" / "prepare project for graphify". Detects project type, installs graphify if needed, builds initial graph, installs git hooks, and creates CLAUDE.md entry. One command = graphify-ready project.
category: memory
---

# graphify-bootstrap — One-command graphify setup for any project

> Run once per project. After that, git hooks keep the graph fresh automatically.

## When to use

- "new project" / "set up this project" / "bootstrap this repo"
- "add graphify to [project]" / "prepare [project] for graphify"
- After cloning a repo that doesn't have graphify hooks yet
- When a project's graph is missing or broken

## One-command setup

```bash
bash ~/.hermes/skills/graphify-bootstrap/scripts/bootstrap.sh /path/to/project
```

Or if you're already in the project directory:

```bash
bash ~/.hermes/skills/graphify-bootstrap/scripts/bootstrap.sh .
```

## What it does (step by step)

```
1. DETECT project type
   ├── package.json          → Node.js/Next.js
   ├── pyproject.toml        → Python
   ├── Cargo.toml            → Rust
   ├── go.mod                → Go
   └── composer.json         → PHP
   Default: auto-detect (walks up to find root marker)

2. VERIFY graphify CLI
   └── If not found: pip install -e /root/graphify

3. CREATE output directory
   └── <project-root>/graphify-out/ (gitignored)

4. BUILD initial graph
   └── graphify update <project-root> --output graphify-out

5. INSTALL git hooks
   └── post-commit: rebuild graph after every commit
   └── post-checkout: rebuild graph after checkout/switch

6. CREATE CLAUDE.md entry
   └── Appends graphify section to <project-root>/CLAUDE.md
       (creates CLAUDE.md if it doesn't exist)

7. SYMLINK to shared memory
   └── ~/.hermes/memory/graphify/<project-name>/ → graphify-out/
       (so backup.sh backs it up automatically)

8. VERIFY
   └── graphify explain "main" --graph <project-root>/graphify-out/graph.json
```

## Git hook: post-commit

```bash
#!/bin/bash
# Auto-rebuild graph after git commit
graphify update "$(git rev-parse --show-toplevel)" --output graphify-out
```

## Shared memory integration

Each project's graph is symlinked to `~/.hermes/memory/graphify/<project-name>/` so:
- Watchdog backs it up via `~/.hermes/memory-backup.git`
- Both AatosTeam (Hermes) and Claude Code access the same graph
- Backup is automatic (no extra action needed)

## Quick reference

| Task | Command |
|------|---------|
| Bootstrap a project | `bash ~/.hermes/skills/graphify-bootstrap/scripts/bootstrap.sh /path/to/project` |
| Rebuild graph manually | `graphify update /path/to/project --output graphify-out` |
| Check graph stats | `python3 -c "import json; g=json.load(open('graphify-out/graph.json')); print(f'{len(g[\"nodes\"])} nodes, {len(g[\"edges\"])} edges')"` |
| Explain a node | `graphify explain "ComponentName" --graph graphify-out/graph.json` |
| Remove graphify from project | `rm -rf graphify-out && rm .git/hooks/post-commit .git/hooks/post-checkout` |

## Bash `set -e` + arithmetic increment bug

**Symptom:** Script with `set -e` exits prematurely on the first `((counter++))` when counter starts at 0.

**Why:** `((0++))` evaluates to 0 (false), returning exit code 1. With `set -e`, this kills the script.

**Fix:** Append `|| true` to all `((counter++))` in `set -e` scripts:

```bash
# WRONG (exits on first increment when counter=0)
((synced++))
((broken++))

# CORRECT
((synced++)) || true
((broken++)) || true

# OR use : for clarity
: $((synced++))
: $((broken++))
```

**Detection:** Run with `bash -x script.sh` — script dies at first `((var++))` with exit code 1.

---

## Troubleshooting

**"graphify: command not found" after install:**
```bash
pip install -e /root/graphify
# Or if that fails:
/root/.hermes/hermes-agent/venv/bin/pip install -e /root/graphify
```

**Git hooks not firing:**
```bash
# Verify hooks are executable
ls -la .git/hooks/post-commit .git/hooks/post-checkout
# Re-install if needed
bash ~/.hermes/skills/graphify-bootstrap/scripts/bootstrap.sh .
```

**Graph out of date after many changes:**
```bash
# Force rebuild
graphify update /path/to/project --output graphify-out
```

## Quick Commands
- `skill-load graphify-bootstrap` — Load this skill
