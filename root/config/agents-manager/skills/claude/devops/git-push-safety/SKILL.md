---
name: git-push-safety
description: Multi-layer git push protection - prevents accidental pushes to non-aatos repos (upstream sources, public repos). Setup script for new servers/profiles.
version: 1.0
category: devops
author: Aatos
tags: [git, safety, security, devops]
---

# Git Push Safety

Multi-layer protection against accidental git pushes to wrong repositories.

## Purpose

- Block pushes to upstream source repos (e.g., coollabsio/coolify)
- Block pushes to non-aatos organizations
- Only allow pushes to approved aatos repos
- Works globally across all git repos on the system

## Quick Start

```bash
# Install
bash /root/.hermes/scripts/git-push-safety.sh

# Verify
bash /root/.hermes/scripts/git-push-safety.sh --verify

# Uninstall
bash /root/.hermes/scripts/git-push-safety.sh --uninstall
```

## Safety Layers

| Layer | Protection |
|-------|------------|
| 1. Pre-push hook | Blocks non-aatos org pushes AND public repo pushes at git level |
| 2. Remote pushurl | Sets `upstream` to `NO_PUSH_ALLOWED` |
| 3. Global config | `core.hooksPath` points to safe hook |

## Allowed Orgs/Repos (PRIVATE ONLY)

- `aatos-git-collab`
- `aatos`
- `aatos-cloud`

### Private Repo Requirement

**Push is allowed ONLY to private repos.** The hook verifies this via:

1. **GitHub API check** (unauthenticated): `GET https://api.github.com/repos/{owner}/{repo}`
   - `200` → repo is public → **BLOCKED**
   - `404` → private or doesn't exist → continue to step 2
2. **Authenticated check** (if SSH/gh token available):
   - Uses `gh cli` or `github.token` git config to confirm `private: true`
   - Falls back to `IS_PRIVATE=true` (safe default) if cannot verify
3. **Non-GitHub URLs**: Skips API check, relies on org allowlist only (assumes private)

### Decision Logic

```
Push URL → matches allowed org?
  NO  → BLOCKED (non-aatos repo)
  YES → is it a private GitHub repo?
          PUBLIC  → BLOCKED (public repo check)
          PRIVATE → ALLOWED
          CANT_TELL → ALLOWED (safe default: assume private)
```

## Setup Script Location

```
/root/.hermes/scripts/git-push-safety.sh
```

## What It Does

1. **Creates:** `~/.git-hooks/pre-push` (global hook)
2. **Configures:** `git config --global core.hooksPath ~/.git-hooks`
3. **Sets:** `push.default = current`
4. **Protects:** Any repo with `upstream` remote (sets pushurl to `NO_PUSH_ALLOWED`)

## For New Server/Profile Setup

Add to your server setup script or profile:

```bash
# In your server setup script or ~/.bashrc
if [ ! -f ~/.git-hooks/pre-push ]; then
    bash /root/.hermes/scripts/git-push-safety.sh --silent
fi
```

## Verification

```bash
$ bash /root/.hermes/scripts/git-push-safety.sh --verify

==========================================
Git Push Safety Verification
==========================================

1. Pre-Push Hook:
  /root/.git-hooks/pre-push (executable)
  Allowed orgs: aatos-git-collab,aatos,aatos-cloud

2. Global Git Config:
  core.hooksPath = /root/.git-hooks
  push.default = current

3. Current Repository:
  origin: https://github.com/aatos-git-collab/coolify-custom.git (push allowed)
  upstream: https://github.com/coollabsio/coolify.git (fetch-only)
```

## If Blocked

If you NEED to push to a different repo temporarily:

```bash
# Disable hook temporarily
git config --global --unset core.hooksPath

# Push your changes
git push custom-remote branch

# Re-enable hook
git config --global core.hooksPath ~/.git-hooks
```

## Manual Setup (Without Script)

```bash
# 1. Create hook
mkdir -p ~/.git-hooks
cat > ~/.git-hooks/pre-push << 'EOF'
#!/bin/bash
ALLOWED_ORGS="aatos-git-collab,aatos,aatos-cloud"
REMOTE_URL=$(git remote get-url --push origin 2>/dev/null)
if [ "$REMOTE_URL" = "NO_PUSH_ALLOWED" ]; then
    echo "Push disabled for this remote"
    exit 1
fi
ALLOWED=false
IFS=',' read -ra ORG_ARRAY <<< "$ALLOWED_ORGS"
for org in "${ORG_ARRAY[@]}"; do
    if echo "$REMOTE_URL" | grep -qi "$org"; then
        ALLOWED=true
        break
    fi
done
if [ "$ALLOWED" = "false" ]; then
    echo "ERROR: Blocked - not aatos repo: $REMOTE_URL"
    exit 1
fi
exit 0
EOF
chmod +x ~/.git-hooks/pre-push

# 2. Configure git
git config --global core.hooksPath ~/.git-hooks
git config --global push.default current

# 3. For any repo with upstream
git remote set-url --push upstream NO_PUSH_ALLOWED
```
## Quick Commands
- `skill-load git-push-safety` — Load this skill
