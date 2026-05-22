---
name: workspace-manager
description: workspace-manager skill
  Create and manage isolated Linux user workspaces for AI agent teams.
  Each workspace is a passwordless SSH-key Linux user with Claude Code,
  Hermes Agent, and AatosTeam accessible via PATH.
version: 6.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [workspace, isolated, multi-agent, claude-code, hermes, aatosteam, linux-user]
    related_skills: [claude-code-setup, autonomous-ai-agents, global-install, ai-migrate-tools]
---

# Workspace Manager

## Architecture

```
ROOT (Main Hermes — infrastructure owner):
  /opt/claude/bin/claude      ← Claude binary
  /opt/hermes/                ← Hermes venv
  /opt/aatosteam/             ← AatosTeam venv
  /usr/local/bin/{claude,hermes,aatosteam}  ← symlinks
  /opt/skills/                  ← approved skills symlinked to workspaces (ai-migrate-tools here)
  /root/workspace-scripts/       ← infra scripts

WORKSPACE (e.g. ceo user):
  /home/<user>/
  ├── projects/          ← code repos
  ├── logs/              ← agent logs
  ├── tests/             ← test outputs
  ├── reports/           ← build reports
  ├── .hermes/
  │   ├── .env           ← own API keys (copied from root template)
  │   ├── config.yaml    ← own hermes config
  │   ├── skills/        ← local skills dir (writable)
  │   ├── skills-local/  ← draft skills
  │   ├── skills-staged/ ← proposed skills
  │   └── sessions/      ← chat sessions
  └── .claude/
      ├── settings.json  ← env block only (model, provider, agent teams)
      └── claude.json    ← top-level fields only (hasCompletedOnboarding)
```

## Access

| Action | Command |
|--------|---------|
| Enter workspace | `su -s /bin/bash <user> -i` |
| Workspace health check | `sudo -u <user> -i bash -lc 'claude --version'` |
| Root infra health | `sudo /root/.hermes/skills/devops/workspace-manager/scripts/infrastructure-manager.sh health` |
| Create new workspace | `sudo /root/.hermes/skills/devops/workspace-manager/scripts/create-workspace.sh <name>` (auto-adds user to `docker` + `sudo` (NOPASSWD) groups — **required**, workspace creation fails if docker is missing) |

## Scripts

All in `/root/.hermes/skills/devops/workspace-manager/scripts/`:

| Script | Who runs | Purpose |
|--------|---------|---------|
| `infrastructure-manager.sh` | **root** | Everything infra: workspaces, skills, health, self-heal |
| `create-workspace.sh` | **root** | Create workspace user + dirs |
| `setup-workspace.sh` | **root** | Configure workspace + global tools |
| `verify-and-fix.sh` | **root** | Self-heal global tools |
| `workspace-request.sh` | **workspace user** | CEO → Root communication |
| `_tool-utils.sh` | sourced by root | Repair functions |

## Claude config — TWO separate files in `~/.claude/`

Claude Code uses **two** config files with different schemas:

**`~/.claude/settings.json`** — env block only (model, provider, agent teams)
```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.minimax.io/v1",
    "ANTHROPIC_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.7",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "10",
    "teammateMode": "tmux"
  }
}
```

**`~/.claude/claude.json`** — top-level fields only (NO env block)
```json
{
  "hasCompletedOnboarding": true
}
```

> ⚠️ **Common mistake:** putting `hasCompletedOnboarding` inside `settings.json` — it belongs in `claude.json`. These are two separate files with different schemas.

## Troubleshooting

### Shell Heredoc Escaping Bug (wrapper scripts)
When writing shell scripts that contain `${VAR}`, backslashes, or other special chars from **inside a shell heredoc**, bash interpolates them before the content reaches the target file. This causes:
- `${ANTHROPIC_BASE_URL:-default}` → literal text instead of runtime expansion
- Backslash sequences like `\\n` → actual newlines

**Fix:** Use Python raw string to write the script directly:
```bash
python3 - "$target_path" << 'PYEOF'
path = sys.argv[1]
wrapper = r'''#!/bin/bash
# literal content — no shell interpretation
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.minimax.io/v1}"
exec /opt/claude/bin/claude-real "$@"
'''
with open(path, 'w') as f:
    f.write(wrapper)
PYEOF
chmod +x "$target_path"
```

### Embedded Git Repository in `git add -A`
When staging directories that contain embedded git repos (e.g. `tools/aatosteam/` which is itself a git clone), `git add -A` fails with:
```
fatal: unknown index entry format 0x3d2e0000
fatal: 'git status --porcelain=2' failed in submodule
```
**Fix:** Remove the embedded repo from the index before staging:
```bash
git rm --cached <path-to-embedded-repo>
rm -rf <path-to-embedded-repo>  # if you don't need it
git add <other-paths>
```
The `r'''` Python raw string passes content through verbatim. The `'PYEOF'` delimiter (with quotes) prevents any variable substitution on the Python code itself.

## Root Commands

```bash
# Infrastructure health
sudo /root/workspace-scripts/infrastructure-manager.sh health

# Self-heal global tools
sudo /root/workspace-scripts/infrastructure-manager.sh self-heal

# Workspace management
sudo /root/workspace-scripts/infrastructure-manager.sh workspace list
sudo /root/workspace-scripts/infrastructure-manager.sh workspace create <name>
sudo /root/workspace-scripts/infrastructure-manager.sh workspace delete <name>

# Skill management
sudo /root/workspace-scripts/infrastructure-manager.sh skill stage-list
sudo /root/workspace-scripts/infrastructure-manager.sh skill approve <name>
sudo /root/workspace-scripts/infrastructure-manager.sh skill reject <name> <reason>
sudo /root/workspace-scripts/infrastructure-manager.sh skill sync-all
```

## CEO Commands (no sudo)

```bash
su -s /bin/bash ceo -i

# Inside CEO workspace:
~/request.sh workspace create <name>   # request new workspace
~/request.sh skill propose <skill>     # propose skill for review
~/request.sh status                    # check pending requests

# Use tools directly (no sudo needed):
claude --version
hermes --version
aatosteam --version
```
## Quick Commands
- `skill-load workspace-manager` — Load this skill
