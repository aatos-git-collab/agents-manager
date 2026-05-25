# agents-manager

Global shared install for Hermes and Claude agents with workspace management.

## Architecture

```
agents-manager/
├── actions.sh              # Main entry point (unified launcher)
├── extensions/             # Modular scripts organized by function
│   ├── install/            # Agent installation
│   │   ├── _common.sh      # Shared install utilities
│   │   ├── global.sh       # Global shared install
│   │   ├── hermes.sh       # Hermes CLI install + config
│   │   └── claude.sh       # Claude CLI install + config
│   ├── workspace/          # Workspace management
│   │   ├── _common.sh      # Shared workspace utilities
│   │   ├── create.sh       # Create workspace + user
│   │   ├── delete.sh       # Delete workspace + user
│   │   ├── test.sh         # Test workspace health
│   │   ├── list.sh         # List all workspaces
│   │   ├── mount.sh        # Mount workspace to /home/<user>
│   │   └── umount.sh       # Unmount workspace
│   └── agent/              # Agent management
│       └── status.sh       # Check agent status
├── skills/                 # Agent skills (global shared)
└── presets/               # Configuration presets
```

## Quick Start

### Root Setup (one-time global install)

```bash
sudo bash /magicai/agents-manager/actions.sh install global
```

This syncs the shared base to `/usr/local/share/agents-manager/` and creates launchers in `/usr/local/bin/`.

### Per-User Setup

```bash
bash /magicai/agents-manager/actions.sh install hermes    # Install/update Hermes
bash /magicai/agents-manager/actions.sh install claude    # Install/update Claude
```

Or use launchers directly:

```bash
hermes-install   # Install/update Hermes
claude-install  # Install/update Claude
```

## Commands

### Unified Interface (actions.sh)

```bash
bash actions.sh <extension> <command> [options]
```

**Extensions:**

| Extension | Description |
|-----------|-------------|
| `install` | Install agents (global, hermes, claude) |
| `workspace` | Workspace management |
| `agent` | Agent management |

**Install Commands:**

```bash
bash actions.sh install global              # Global shared install (root only)
bash actions.sh install hermes [username]  # Install Hermes (user or specify user)
bash actions.sh install claude [username]  # Install Claude (user or specify user)
```

**Workspace Commands:**

```bash
bash actions.sh workspace create <username>   # Create workspace + user
bash actions.sh workspace delete <username>  # Delete workspace + user
bash actions.sh workspace test <username>    # Test workspace health
bash actions.sh workspace list               # List all workspaces
bash actions.sh workspace mount <username>   # Mount workspace to /home/<user>
bash actions.sh workspace umount <username>   # Unmount workspace
```

**Agent Commands:**

```bash
bash actions.sh agent status hermes   # Check Hermes status
bash actions.sh agent status claude  # Check Claude status
```

## Workspace Management

Workspaces are isolated Linux user environments with bind mounts (docker-style, not symlinks):

```bash
# Create workspace for user
bash actions.sh workspace create jdoe

# Test workspace (ownership, agents, write access)
bash actions.sh workspace test jdoe

# List all workspaces
bash actions.sh workspace list

# Delete workspace
bash actions.sh workspace delete jdoe

# Mount/Unmount manually
bash actions.sh workspace mount jdoe
bash actions.sh workspace umount jdoe
```

### Workspace Structure

```
/workspaces/<username>/
├── projects/    # Work files
├── skills/      # User-specific skills
├── memories/    # User memories
├── sessions/    # Chat sessions
├── tasks/       # Task files
└── logs/        # Log files

/home/<username> → /workspaces/<username>  (bind mount)
```

### Bind Mounts

- **Systemd systems**: Uses systemd mount units (`/etc/systemd/system/home-<username>.mount`)
- **Container environments**: Uses `mount --bind` or symlink fallback
- **Ownership**: All folders are `user:user` to avoid permission issues
- **Secrets**: `.env` files stay private (excluded from global sync)

## What's Shared vs Private

**Shared (global, read-only for users):**

| Path | Description |
|------|-------------|
| `/usr/local/share/agents-manager/skills` | All agent skills |
| `/usr/local/share/agents-manager/presets` | Configuration presets |

**Private (per user):**

| Path | Description |
|------|-------------|
| `~/.hermes/.env` | API keys, Mattermost tokens |
| `~/.hermes/` | Hermes config, memories, sessions |
| `~/.claude/` | Claude config, skills |
| `/workspaces/<username>/` | User workspace |

## Launchers

After global install, these are available system-wide:

- `hermes-install` — Install/update Hermes
- `claude-install` — Install/update Claude
- `agents-manager` — Unified launcher (auto mode)
- `actions` — Workspace & agent management (symlink to actions.sh)

## Container Notes

- rsync is auto-installed if missing
- `.env` files are excluded from global sync (secrets stay private)
- Hermes gateway runs manually in containers (no systemd)
- pnpm uses `/config/.local/share/pnpm` path

## Environment Variables

The install scripts use these keys from `.env`:

| Variable | Purpose |
|----------|---------|
| `MINIMAX_API_KEY` | MiniMax API key (same as ANTHROPIC_API_KEY for MiniMax proxy) |
| `ANTHROPIC_API_KEY` | Required for hermes `provider: anthropic` with MiniMax proxy |
| `MINIMAX_ANTHROPIC_BASE_URL` | Proxy endpoint (default: `https://api.minimax.io/anthropic`) |
| `HERMES_TUI_THEME` | TUI theme (default: dark) |

**Important**: Both `MINIMAX_API_KEY` and `ANTHROPIC_API_KEY` are needed when using `provider: anthropic` with MiniMax's proxy endpoint — they typically have the same value.

## Updating

Root updates the global base:

```bash
sudo bash /magicai/agents-manager/actions.sh install global
```

All users automatically use the updated version on next run.