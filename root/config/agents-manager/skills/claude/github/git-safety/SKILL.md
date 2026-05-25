---
name: git-safety
description: Server-wide Git safety — ALL repos must be private. Blocks public pushes, public repo creation, and unauthorized remote URLs. Use when creating repos, pushing code, adding remotes, or any git operation involving remotes.
tags: [git, safety, private-repo, security, privacy]
---

# Git Safety — Private Repo Policy

**Policy: ALL Aatos repos are PRIVATE. No exceptions.**

## Core Rules

1. **No public repos** — any repo created must be `private: true`
2. **No pushes to public remotes** — blocked by pre-push hook
3. **Allowed orgs only** — only push to:
   - `github.com/aatos-git-collab/` (primary)
   - `github.com/HKUDS/` (research org)
   - `github.com/nousresearch/` (Hermes upstream — read-only)

## ⛔ CRITICAL: agents-backup Skill-Branch Isolation

**The `agents-backup/skill-branch` repo is the CLEAN/OLD reference. Your current `~/.hermes/skills/` is FULLY CUSTOM/BUILT by this agent.**

Cloning or pulling `skill-branch` directly into `~/.hermes/skills/` will **OVERWRITE and destroy** everything that makes your system unique:
- All marketing skills (34 skills)
- All productivity skills (46 skills)
- All software-development skills (85 skills)
- ALL self-built system skills: skill-sync, skill-health, skill-optimizer, power-watchdog, graphify-bootstrap, hermes-memory-aatos, shared-memory, verification-loop, etc.

**SAFE workflow — ALWAYS use /tmp:**
```bash
# 1. Clone to /tmp (NEVER into ~/.hermes/skills/)
GITHUB_TOKEN=$(grep "^GITHUB_TOKEN=" /root/.hermes/.env | cut -d= -f2 | tr -d '"')
git clone --branch skill-branch https://${GITHUB_TOKEN}@github.com/aatos-git-collab/agents-backup.git /tmp/agents-backup

# 2. Inspect BEFORE touching anything real
ls /tmp/agents-backup/
diff -rq /tmp/agents-backup/ ~/.hermes/skills/

# 3. Merge manually per-skill, never wholesale replace
```

**git-safety.py should block this pattern:**
- ❌ `git clone *agents-backup* ~/.hermes/skills/` — **BLOCK**
- ❌ `git clone *agents-backup* /root/.hermes/skills/` — **BLOCK**
- ❌ `git pull` into `~/.hermes/skills/` from agents-backup — **BLOCK**
- ✅ `git clone` to `/tmp/agents-backup` — **ALLOWED** (read-only inspection)

## Files

```
~/.hermes/skills/github/git-safety/
├── git_safety.py       # Main script
├── hooks/pre-push.py   # Git pre-push hook
├── SKILL.md            # This file
└── logs/               # Safety audit logs
```

## Quick Commands

```bash
# Check if a remote URL is allowed
python3 ~/.hermes/skills/github/git-safety/git_safety.py check-remote https://github.com/org/repo

# Create a new private repo
python3 ~/.hermes/skills/github/git-safety/git_safety.py create-repo my-new-repo

# Audit all remotes on the server
python3 ~/.hermes/skills/github/git-safety/git_safety.py audit-remotes

# Install pre-push hook to a specific repo
python3 ~/.hermes/skills/github/git-safety/git_safety.py install-hook /path/to/repo

# Install global hook (all repos — RECOMMENDED)
python3 ~/.hermes/skills/github/git-safety/git_safety.py install-global
```

## Pre-Push Hook (Global)

Installed via `git config --global core.hooksPath ~/.git/hooks`. Runs automatically before every `git push` and blocks if:
- Remote is not in allowed orgs
- Repo is public on GitHub
- Remote host is not GitHub

## Allowed Remotes

| Org | Push | Notes |
|-----|------|-------|
| `aatos-git-collab` | ✅ Full | Primary org |
| `HKUDS` | ✅ Full | Research org |
| `nousresearch` | ✅ Read-only | Hermes upstream |

All other remotes (gitlab.com, bitbucket.org, personal accounts, etc.) are **BLOCKED**.

## Workflow: Creating a New Repo

```bash
# WRONG — will be blocked:
git remote add origin https://github.com/someuser/myrepo.git
git push -u origin main   # BLOCKED

# RIGHT:
# 1. Create via safety tool (always private)
python3 ~/.hermes/skills/github/git-safety/git_safety.py create-repo my-new-repo

# 2. Clone/add the private URL
git remote add origin https://github.com/aatos-git-collab/my-new-repo.git
git push -u origin main   # ALLOWED
```

## Workflow: Adding a Remote

```bash
# ALWAYS check before adding:
python3 ~/.hermes/skills/github/git-safety/git_safety.py check-remote https://github.com/org/repo

# If BLOCKED — do not add, do not push
```

## Audit

To scan all repos for unsafe remotes:
```bash
python3 ~/.hermes/skills/github/git-safety/git_safety.py audit-remotes ~/
```

## If Blocked

If a legitimate push is blocked:
1. Check that the remote is in allowed orgs
2. If it's a new repo, create it first: `git_safety.py create-repo <name>`
3. Check GitHub — repo must be set to Private
4. Never disable the hook — find the correct private URL instead

## Current Allowed Orgs

- `aatos-git-collab` — Aatos primary org
- `HKUDS` — HKUDS research org
- `nousresearch` — Hermes upstream (read-only)

**Personal accounts, other orgs, gitlab.com, bitbucket.org — always BLOCKED.**
