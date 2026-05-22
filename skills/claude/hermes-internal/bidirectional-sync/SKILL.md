---
name: bidirectional-sync
description: bidirectional-sync skill
  Bidirectional sync between Hermes tools/ (actual git clones, installed packages) and
  skills/ (agent definitions, SKILL.md, references). Two loops: tool→skill (after
  git push) and skill→tool (self-heal before use). Use when setting up a tool+skill
  pair where agents live in tools/ but the skill must stay in sync, or when building
  a self-healing tool that auto-checks and auto-repairs itself.
category: hermes-internal
---

# Bidirectional Sync — Tool ↔ Skill

When a tool lives in `~/.hermes/tools/<Name>/` (git clone, pip installed) and its
documentation/agents live in `~/.hermes/skills/<Name>/` (Hermes skill), these two
loops keep them in sync automatically.

## Two Sync Loops

```
TOOL → SKILL (after every git push)
────────────────────────────────────
tool/ has new code
  → git commit + push to origin
  → sync script copies to skills/
    • agents/*.yaml        → skills/<target>/agents/
    • references/*.md      → skills/<target>/references/
    • SKILL.md (versioned) → skills/<target>/SKILL.md
```

```
SKILL → TOOL (before every tool use)
──────────────────────────────────────
skill loaded (e.g. aatosteam skill)
  → sync script --check
    • git clean? (no uncommitted changes)
    • deps installed? (CLI binary, tmux, etc.)
    • profiles valid?
  → if broken: --fix auto-repairs
    • git reset --hard origin/main
    • git pull origin main
    • pip install -e <tool_repo_path>
    • profile doctor (if applicable)
```

## File: sync_to_skills.py

Core functions to implement:

```python
def _try_run(cmd, **kwargs):
    """Run subprocess, return (stdout, stderr, returncode). FileNotFoundError → ('', 'not found', 1)."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
        return r.stdout.strip(), r.stderr.strip(), r.returncode
    except FileNotFoundError:
        return '', 'not found', 1

def sync_agent_definitions(tool_path, skill_base, repo_name):
    """Sync agents YAMLs from tool's skills/ folder to Hermes skill.
    Strip the top-level tool dir from relative paths.
    e.g. skills/aatosteam/agents/openai.yaml → skills/<target>/agents/openai.yaml"""
    for f in tool_skills.rglob("*.yaml"):
        rel = f.relative_to(tool_skills)
        parts = rel.parts
        if len(parts) > 1 and parts[0] in (repo_name.lower(), "clawteam", "aatosteam"):
            rel = Path(*parts[1:])   # strip top-level
        dest = skill_base / rel
        if not dest.exists() or dest.read_text() != f.read_text():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, dest)

def check_git_status(repo_path):
    """Returns: {clean, behind_upstream, ahead_upstream}"""
    # Use _try_run for all subprocess calls

def check_dependencies():
    """Check CLI binary, tmux, pip packages. Use _try_run."""
    # tmux: which tmux
    # cli: cli --version
    # python deps: pip show

def fix_git_reset_clean(repo_path):
    """git fetch origin && git reset --hard origin/main"""
    # Use _try_run

def fix_git_pull(repo_path):
    """git pull origin main"""
    # Use _try_run

def fix_pip_install(repo_path):
    """pip install -e <repo_path> --break-system-packages --ignore-installed <conflict>"""
    # Handle externally-managed-environment error
    # Handle cannot-uninstall-RECORD error with --ignore-installed
```

## manifest.json config

```json
{
  "repos": {
    "AatosTeam": {
      "source": "https://github.com/HKUDS/ClawTeam.git",
      "upstream_remote": "upstream",
      "working_remote": "origin",
      "local_path": "~/.hermes/tools/AatosTeam",
      "origin_url": "https://github.com/aatos-git-collab/AatosTeam.git",
      "skill_sync_target": "aatosteam",
      "rebrand_rules": [...]
    }
  }
}
```

Key field: `skill_sync_target` tells sync script which skill folder to write to.

## Version-gated SKILL.md sync

```python
def sync_skill_md(tool_skill_md, skill_skill_md):
    # Extract version from frontmatter: version: "0.3.1"
    vm = re.search(r'version:\s*"?([\d.]+)"?', content)
    tool_version = vm.group(1) if vm else "0.0.0"
    # Only copy if tool_version > current_version
```

## Pip install gotchas

| Error | Fix |
|-------|-----|
| `externally-managed-environment` | Add `--break-system-packages` |
| `Cannot uninstall PyJWT, RECORD file not found` | Add `--ignore-installed <pkg>` |

## Watchdog post-push hook

After `git push` in watchdog.py, call the sync script:

```python
pushed = push_to_origin(repo_path)
if pushed:
    r = subprocess.run(
        [sys.executable, str(sync_script), "--repo", repo_name],
        cwd=SKILL_DIR, capture_output=True, text=True
    )
```

## CLI interface

```bash
python sync_to_skills.py --repo AatosTeam          # tool → skill
python sync_to_skills.py --repo AatosTeam --check  # self-heal check
python sync_to_skills.py --repo AatosTeam --fix    # self-heal + repair
```
## Quick Commands
- `skill-load bidirectional-sync` — Load this skill
