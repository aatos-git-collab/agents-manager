---
name: hermes-agent-docker-build
description: hermes-agent-docker-build skill
  Build and verify the hermes-agent Company-in-a-Box Docker image.
  Use when: building the hermes-agent Docker image, adding skills to the image,
  adding dependencies, or auditing what's baked into the container vs what runs at runtime.
version: 1.0.0
category: devops
tags: [docker, hermes-agent, dockerfile, company-in-a-box, container-build]
---

# Hermes Agent Docker Build — Company-in-a-Box

Source repo: `/root/hermes-agent/`
Image: `ghcr.io/aatos-git-collab/hermes-agent:latest` (or custom tag)

## Pre-Build Checklist (MUST verify before building)

### 1. SSH daemon is installed
```bash
grep "openssh-server" /root/hermes-agent/Dockerfile
```
**If missing:** Add `openssh-server` to the apt-get install line.

### 2. All skill subdirectories are complete
Skills that have subdirectories (like `vault/`) or extra files (like `SKILL.md`) must be verified:
```bash
# Check source repo has SKILL.md
ls /root/hermes-agent/skills/devops/workspace-manager/SKILL.md

# Check vault/ subdirectory
ls /root/hermes-agent/skills/devops/workspace-manager/vault/

# If missing from source repo, copy from live /root/.hermes/skills/:
cp /root/.hermes/skills/devops/workspace-manager/SKILL.md \
   /root/hermes-agent/skills/devops/workspace-manager/SKILL.md
cp -r /root/.hermes/skills/devops/workspace-manager/vault/ \
   /root/hermes-agent/skills/devops/workspace-manager/vault/
```

### 3. /opt/skills symlink exists
The `setup-workspace.sh` hardcodes `/opt/skills` as the global skills directory. The Dockerfile MUST create the symlink:
```bash
grep "/opt/skills" /root/hermes-agent/Dockerfile
```
**If missing:** Add to Dockerfile:
```dockerfile
RUN ln -sfn /opt/hermes/skills /opt/skills
```

### 4. Skills are copied into image
The `COPY skills/...` line in Dockerfile only copies `workspace-manager/scripts/`. Skills with SKILL.md + subdirs must also be included.

## Image Architecture

### What's baked in (read-only, shared globally):
```
/opt/hermes/           ← hermes-agent source + pip install
/opt/hermes/skills/    ← ALL skills (SKILL.md + scripts)
/opt/skills/           ← symlink → /opt/hermes/skills (for setup-workspace.sh compatibility)
/opt/workspace-scripts/ ← infrastructure scripts (create-workspace.sh, verify-and-fix.sh, etc.)
/usr/local/bin/hermes  ← hermes CLI (from pip install)
```

### Per-workspace (persistent volume /opt/data):
```
/opt/data/
  .env                 ← API keys (copied from .env.example on first boot)
  config.yaml          ← model defaults (copied from cli-config.yaml.example)
  SOUL.md              ← agent identity
  .setup_done          ← first-boot flag
  home/<user>/         ← workspace user homes (ceo, etc.)
```

### Workspace user home structure:
```
/home/<user>/
  .hermes/
    .env               ← own API keys
    config.yaml        ← own hermes config (MiniMax-M2.7 defaults)
    skills/            ← local/writable skills
    sessions/          ← chat sessions
  .ssh/                ← SSH keys (generated on first boot)
  projects/
  logs/
  tests/
  reports/
```

## Default Model Config (in cli-config.yaml.example — baked into /opt/data/.env on first boot)
```yaml
model:
  default: "MiniMax-M2.7"
  provider: "minimax"
  base_url: "https://api.minimax.io/v1"
```

## Build Command
```bash
cd /root/hermes-agent
docker build -t ghcr.io/aatos-git-collab/hermes-agent:latest .
```

## Run Command
```bash
docker run -d \
  --name hermes-company-in-a-box \
  -v /data/hermes/CEO-AATOS:/opt/data \
  -v /data/hermes/CEO-AATOS/SOUL.md:/root/.hermes/SOUL.md \
  -p 2222:22 \
  ghcr.io/aatos-git-collab/hermes-agent:latest
```

## First Boot Behaviour
1. SSH daemon starts on port 22 (mapped to 2222 on host)
2. First boot: `prepare_dirs()` creates `.env`, `config.yaml`, `SOUL.md` in /opt/data
3. First boot: `first_boot_setup()` runs infrastructure setup
   - Self-heals global tools
   - Creates workspace user (default: `ceo`)
   - Generates SSH keys at `/home/ceo/.ssh/`
   - Runs `setup-workspace.sh`
4. Subsequent boots: skips setup, verifies user exists, execs as `ceo`

## Get SSH Access
```bash
# Get ceo user's SSH public key from volume
cat /data/hermes/CEO-AATOS/home/ceo/.ssh/id_ed25519.pub

# SSH in
ssh -i /data/hermes/CEO-AATOS/home/ceo/.ssh/id_ed25519 ceo@<container-ip>
```

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `sshd: command not found` | openssh-server not in apt-get | Add to Dockerfile |
| Skills not found in workspace | `/opt/skills` symlink missing | Add symlink to Dockerfile |
| `setup-workspace.sh` fails | SKILL.md missing from source repo | Copy from `/root/.hermes/skills/` |
| Vault features broken | `vault/` subdir missing | Copy from `/root/.hermes/skills/` |
| hermes: command not found for ceo user | PATH not set in .bashrc/.profile | setup-workspace.sh adds PATH |

## Adding New Skills to the Image
1. Copy skill dir into `/root/hermes-agent/skills/<category>/<skill>/`
2. Include ALL files: `SKILL.md`, `scripts/`, `vault/`, `references/`, etc.
3. Ensure `/opt/skills` symlink is in Dockerfile (already points to `/opt/hermes/skills`)
4. Rebuild
## Quick Commands
- `skill-load hermes-agent-docker-build` — Load this skill
