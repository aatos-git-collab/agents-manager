---
name: global-install
description: global-install skill
  Full server setup — installs Hermes Agent, Claude Code, and AatosTeam globally
  on a fresh Linux server so any user can run them. Use when:
    - "setup a new server", "install everything", "global install"
    - "make hermes work for all users"
    - First time setting up a deployment machine

  This skill delegates to workspace-manager scripts which handle the actual
  installation. Those scripts are idempotent and can also be run standalone.
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [setup, global-install, server-setup, infrastructure]
    related_skills: [workspace-manager, vault-security]
---

# global-install — Full Server Setup

Installs Hermes Agent, Claude Code, and AatosTeam globally on a fresh Linux server.

## Two Ways to Use

### Option A: One-shot (recommended for fresh server)

```bash
# Run the full setup script
bash /root/.hermes/skills/devops/global-install/scripts/install.sh

# Then create first workspace
sudo /root/.hermes/skills/devops/workspace-manager/scripts/create-workspace.sh engineering
```

### Option B: Workspace-first (creates workspace + auto-installs globals)

```bash
# Create workspace — auto-installs globals if missing
sudo /root/.hermes/skills/devops/workspace-manager/scripts/create-workspace.sh engineering
```

**Option B is simpler** — `setup-workspace.sh` auto-installs all missing global tools before configuring the workspace. No separate global-install step needed.

## What Gets Installed

| Tool | Location | Accessible to | Installed by |
|------|----------|---------------|-------------|
| Claude Code | `/opt/claude/bin/claude` | All users | install.sh |
| Hermes Agent | `/opt/hermes/` | All users | install.sh |
| AatosTeam | `/opt/aatosteam/` | All users | install.sh |
| AatosTeam MCP | `/opt/aatosteam/bin/aatosteam-mcp` | All users | install.sh |
| Global Skills | `/opt/skills/` | All users | install.sh |
| Global AI Config | `/opt/hermes/config/` | All users (read-only) | install.sh |

## Directory Structure After Setup

```
/root/.hermes/                    ← PRIVATE (700, root-only)
├── tools/                       ← Source repos (for dev, not needed at runtime)
├── skills/                     ← Root's internal skills (staging, rejected)
└── ... (sessions, logs, memories, cache)

/opt/                             ← PUBLIC (755, world-readable)
├── hermes/                       ← Hermes venv
│   ├── bin/hermes
│   └── lib/python3.12/site-packages/
├── aatosteam/
│   ├── bin/aatosteam
│   └── bin/aatosteam-mcp
├── claude/bin/claude
├── config/                       ← Global AI configuration
│   ├── global-api.json          ← AI providers: OpenAI, Anthropic, Google, etc.
│   ├── model-config.json         ← Default model routing for all agents
│   └── provider-credentials/    ← API keys
└── skills/                       ← Global skills (world-readable, no symlinks)
    ├── autonomous-ai-agents/
    ├── devops/
    ├── mlops/
    └── ... (all skills)

/usr/local/bin/                   ← In everyone's PATH
├── claude  → /opt/claude/bin/claude
├── hermes  → /opt/hermes/bin/hermes
└── aatosteam → /opt/aatosteam/bin/aatosteam

/home/<workspace>/.hermes/config/
├── global-api.json → /opt/hermes/config/global-api.json (symlink, read-only)
├── model-config.json → /opt/hermes/config/model-config.json (symlink, read-only)
├── agent-config.json  ← Personal integrations (Gmail, Slack, etc.)
└── skills-config.json ← Enable/disable which global skills agent can use
```

## install.sh Script

Located at: `scripts/install.sh`

Does the same thing as `setup-workspace.sh` but in a single standalone script. Useful when you want to verify the global tools first before creating any workspaces.

```bash
bash /root/.hermes/skills/devops/global-install/scripts/install.sh
```

## Source Locations

Source repos (git clones) live inside `/root/.hermes/tools/`:

| Tool | Source Path |
|------|-------------|
| Hermes | `/root/.hermes/tools/hermes-agent` |
| AatosTeam | `/root/.hermes/tools/aatosteam` |
| Claude | `/root/.hermes/tools/claude` (symlink) |

Installed runtimes live inside `/root/.hermes/runtime/`:

| Tool | Runtime Path |
|------|-------------|
| Hermes | `/root/.hermes/runtime/hermes` |
| AatosTeam | `/root/.hermes/runtime/aatosteam` |
| Claude | `/root/.hermes/runtime/claude` |

## Verification

After setup, verify globally:

```bash
# As any user
claude --version
hermes --version
aatosteam --version

# As specific user
sudo -u engineering hermes --version
```

## Troubleshooting

### "Hermes source not found at /root/.hermes/tools/hermes-agent"
The scripts need the hermes-agent source code. Clone it:
```bash
git clone https://github.com/NousResearch/hermes-agent.git /root/.hermes/tools/hermes-agent
```

### "AatosTeam source not found at /root/.hermes/tools/aatosteam"
Same — clone AatosTeam:
```bash
git clone <aatosteam-repo> /root/.hermes/tools/aatosteam
```

### "uv installation failed"
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Permission denied on /root/.hermes/skills
```bash
chmod 755 /root /root/.hermes /root/.hermes/skills
```

### Restore original /opt/ layout
If you need to revert to old `/opt/` paths, run:
```bash
sudo mv /root/.hermes/runtime/hermes /opt/hermes
sudo mv /root/.hermes/runtime/aatosteam /opt/aatosteam
sudo mv /root/.hermes/runtime/claude /opt/claude
```
And restore `/usr/local/bin/` symlinks to point to `/opt/`.
## Quick Commands
- `skill-load global-install` — Load this skill
