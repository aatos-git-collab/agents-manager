---
name: claude-code-install
description: Automated installation of Claude Code CLI for root + user accounts in a container/VM. Installs curl, wget, sqlite3, jq, creates a passwordless user, then installs and configures Claude Code with MiniMax API settings and dangerouslyAlwaysAllow.
trigger: "install claude|claude install|setup claude|claude code install|install-claude"
---

# Claude Code Install Skill

Automated, idempotent installation of Claude Code CLI for both root and a `user` account in a containerized Linux environment. Runs on Debian/Ubuntu-based systems.

## What it does

1. Installs system packages: `curl wget sqlite3 jq`
2. Creates `/etc/sudoers.d/` if missing (required on minimal containers)
3. Creates a `user` account with passwordless sudo
4. Installs Claude Code via the official `https://claude.ai/install.sh` script for both root and user
5. Writes `~/.claude/settings.json` with MiniMax API config + `dangerouslyAlwaysAllow: true`
6. Writes `~/.claude.json` with `hasCompletedOnboarding: true`
7. Adds `~/.local/bin` to `$PATH` in both `.bashrc` files

## Run

```bash
bash /opt/data/global/skills/claude-code-install/install-claude.sh
```

## Verified

- Idempotent: re-running is safe (detects existing user, existing install)
- Works in Docker/LXC containers with no `sudo` binary (uses `su`)
- Both root and user have valid `settings.json` (JSON validated ✓)
- Claude Code version: **2.1.100**

## Files produced

| Path | Description |
|------|-------------|
| `/root/.local/bin/claude` | Root Claude Code binary |
| `/root/.claude/settings.json` | Root Claude settings |
| `/root/.claude.json` | Root onboarding marker |
| `/home/user/.local/bin/claude` | User Claude Code binary |
| `/home/user/.claude/settings.json` | User Claude settings |
| `/home/user/.claude.json` | User onboarding marker |
| `/etc/sudoers.d/user` | Passwordless sudo for user |

## Key settings in settings.json

- `ANTHROPIC_BASE_URL: https://api.minimax.io/anthropic`
- `ANTHROPIC_MODEL: MiniMax-M2.7`
- `dangerouslyAlwaysAllow: true`
- `skipDangerousModePermissionPrompt: true`
- `teammateMode: tmux`
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: 10`

## Pitfalls

- **`/etc/sudoers.d/` missing**: The original script failed on first run because this dir didn't exist. Fixed by `mkdir -p /etc/sudoers.d && chmod 755 /etc/sudoers.d` before writing the sudoers file.
- **No `sudo` binary**: Container environments often lack `sudo`. Use `su - user` instead when running as root.
- **Malformed JSON in heredoc**: Be careful with `allow` array entries — complex objects inside string arrays cause parse failures. Keep it simple (plain strings only).
- **Duplicate install output**: The Claude Code installer prints output twice per user — this is expected (installer behavior, not a bug).
- **debconf warnings**: `TERM not set` warnings from apt are cosmetic and harmless in headless containers.

## Quick Commands
- `skill-load github` — Load this skill
