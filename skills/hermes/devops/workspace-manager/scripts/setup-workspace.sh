#!/bin/bash
# =============================================================================
# setup-workspace.sh - Configure workspace with global tools
# =============================================================================
# Run AFTER create-workspace.sh. Idempotent — safe to re-run.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_UTILS="$SCRIPT_DIR/_tool-utils.sh"
[[ -f "$TOOL_UTILS" ]] && source "$TOOL_UTILS"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
STEP()    { echo -e "${BLUE}[STEP]${NC} $1"; }

USERNAME="${1:-}"
[[ -n "$USERNAME" ]] || { echo "Usage: sudo $0 <username>"; exit 1; }
USER_HOME="/home/$USERNAME"

[[ $(id -u) -eq 0 ]] || ERROR "Must run as root"
id "$USERNAME" &>/dev/null || ERROR "User does not exist: $USERNAME"
[[ -d "$USER_HOME" ]] || ERROR "Home dir missing: $USER_HOME"

export DEBIAN_FRONTEND=noninteractive

# =============================================================================
# STEP 0: Self-heal global tools FIRST
# =============================================================================
STEP "[0/7] Self-healing global tools..."
set +e
verify_and_fix_all >/dev/null 2>&1
FIX_RESULT=$?
set -e
[[ $FIX_RESULT -eq 0 ]] && INFO "Tools healthy" || INFO "Tools repaired"

# =============================================================================
# STEP 1: Global config (read-only, defines AI providers and defaults)
# =============================================================================
STEP "[1/7] Global config..."
mkdir -p "$USER_HOME/.hermes/config"
chmod 755 "$USER_HOME/.hermes/config"

# Each workspace gets its own hermes .env and config.yaml
# Copy from root's templates if they don't exist yet (skip in RESTORE mode — keep restored files)
if [[ ! -f "$USER_HOME/.hermes/.env" && "${RESTORE_MODE:-false}" != "true" ]]; then
    cp /root/.hermes/.env "$USER_HOME/.hermes/.env"
    chmod 600 "$USER_HOME/.hermes/.env"
fi

if [[ ! -f "$USER_HOME/.hermes/config.yaml" && "${RESTORE_MODE:-false}" != "true" ]]; then
    cp /root/.hermes/config.yaml "$USER_HOME/.hermes/config.yaml"
    chmod 644 "$USER_HOME/.hermes/config.yaml"
fi

# Global AI config (read-only symlinks)
if [[ ! -L "$USER_HOME/.hermes/config/global-api.json" ]]; then
    ln -sf /opt/hermes/config/global-api.json "$USER_HOME/.hermes/config/global-api.json"
fi
if [[ ! -L "$USER_HOME/.hermes/config/model-config.json" ]]; then
    ln -sf /opt/hermes/config/model-config.json "$USER_HOME/.hermes/config/model-config.json"
fi

# Copy agent-config.json template (personal integrations: Gmail, Slack, etc.)
# Skip in RESTORE mode — keep whatever was restored
if [[ ! -f "$USER_HOME/.hermes/config/agent-config.json" && "${RESTORE_MODE:-false}" != "true" ]]; then
    cp /opt/hermes/config/templates/agent-config.json "$USER_HOME/.hermes/config/agent-config.json"
    sed -i "s/\"agent_id\": \"\"/\"agent_id\": \"$USERNAME\"/" "$USER_HOME/.hermes/config/agent-config.json"
    sed -i "s/\"workspace_name\": \"\"/\"workspace_name\": \"$USERNAME\"/" "$USER_HOME/.hermes/config/agent-config.json"
    chmod 600 "$USER_HOME/.hermes/config/agent-config.json"
fi

# Copy skills-config.json template (controls which global skills this agent can use)
if [[ ! -f "$USER_HOME/.hermes/config/skills-config.json" && "${RESTORE_MODE:-false}" != "true" ]]; then
    cp /opt/hermes/config/templates/skills-config.json "$USER_HOME/.hermes/config/skills-config.json"
    sed -i "s/\"workspace_name\": \"\"/\"workspace_name\": \"$USERNAME\"/" "$USER_HOME/.hermes/config/skills-config.json"
    chmod 600 "$USER_HOME/.hermes/config/skills-config.json"
fi

chown -R "$USERNAME:$USERNAME" "$USER_HOME/.hermes/config"

# Copy SOUL.md template (agent identity)
if [[ ! -f "$USER_HOME/.hermes/SOUL.md" ]]; then
    cp /opt/hermes/config/templates/PROFILE/SOUL.md "$USER_HOME/.hermes/SOUL.md"
    chmod 644 "$USER_HOME/.hermes/SOUL.md"
fi

INFO "Hermes .env: ~/.hermes/.env (each workspace has own API keys)"
INFO "Agent config: ~/.hermes/config/agent-config.json (personal integrations)"
INFO "SOUL.md: ~/.hermes/SOUL.md (agent identity)"

# =============================================================================
# STEP 2: Workspace directories
# =============================================================================
STEP "[2/7] Workspace directories..."
for dir in projects logs tests reports .config; do
    mkdir -p "$USER_HOME/$dir"
done

mkdir -p "$USER_HOME/.hermes/sessions"
mkdir -p "$USER_HOME/.hermes/config"

if [[ ! -f "$USER_HOME/.hermes/config.yaml" && "${RESTORE_MODE:-false}" != "true" ]]; then
    cat > "$USER_HOME/.hermes/config.yaml" << EOF
# Workspace: $USERNAME
model:
  default: MiniMax-M2.7
  provider: minimax
agent:
  max_turns: 90
  tool_use_enforcement: auto
EOF
fi

cat > "$USER_HOME/.config/workspace.env" << EOF
WORKSPACE_NAME=$USERNAME
WORKSPACE_ROOT=$USER_HOME/projects
WORKSPACE_LOGS=$USER_HOME/logs
WORKSPACE_TESTS=$USER_HOME/tests
WORKSPACE_REPORTS=$USER_HOME/reports
HERMES_HOME=$USER_HOME/.hermes
SKILLS_DIR=$USER_HOME/.hermes/skills
REQUESTS_DIR=$USER_HOME/.hermes/requests
EOF

if ! grep -q "WORKSPACE_NAME" "$USER_HOME/.profile" 2>/dev/null && "${RESTORE_MODE:-false}" != "true"; then
    cat >> "$USER_HOME/.profile" << 'EOF'

# === AI AGENT WORKSPACE ===
export WORKSPACE_NAME="USERNAME_REPLACE"
export WORKSPACE_ROOT="$HOME/projects"
export HERMES_HOME="$HOME/.hermes"
export REQUESTS_DIR="$HERMES_HOME/requests"
export PATH="/opt/claude/bin:/opt/hermes/bin:/opt/aatosteam/bin:/usr/local/bin:$PATH"
EOF
    sed -i "s/USERNAME_REPLACE/$USERNAME/" "$USER_HOME/.profile"
fi

# Also add tools PATH to .bashrc (for non-login shells like `su -s /bin/bash -c`)
if ! grep -q "WORKSPACE_NAME" "$USER_HOME/.bashrc" 2>/dev/null && "${RESTORE_MODE:-false}" != "true"; then
    cat >> "$USER_HOME/.bashrc" << 'EOF'

# === AI AGENT WORKSPACE ===
export WORKSPACE_NAME="$USERNAME"
export WORKSPACE_ROOT="$HOME/projects"
export HERMES_HOME="$HOME/.hermes"
export REQUESTS_DIR="$HERMES_HOME/requests"
export PATH="/opt/claude/bin:/opt/hermes/bin:/opt/aatosteam/bin:/usr/local/bin:$PATH"
EOF
fi

chown -R "$USERNAME:$USERNAME" "$USER_HOME/.hermes" "$USER_HOME/.config" 2>/dev/null || true

# =============================================================================
# STEP 3: Claude config
# =============================================================================
STEP "[3/7] Claude config..."
mkdir -p "$USER_HOME/.claude"

# Copy global settings.json (not symlink - avoid shared mutations)
if [[ -f /root/.claude/settings.json && ! -f "$USER_HOME/.claude/settings.json" ]]; then
    cp /root/.claude/settings.json "$USER_HOME/.claude/settings.json"
fi

# Add hasCompletedOnboarding to .claude.json
CLAUDE_JSON="$USER_HOME/.claude.json"
if [[ -f "$CLAUDE_JSON" ]]; then
    if ! grep -q 'hasCompletedOnboarding' "$CLAUDE_JSON" 2>/dev/null; then
        python3 -c "
import json, sys
f='$CLAUDE_JSON'
with open(f, 'r') as fp: data=json.load(fp)
data['hasCompletedOnboarding']=True
with open(f, 'w') as fp: json.dump(data, fp, indent=2)
" 2>/dev/null || true
    fi
else
    echo '{"hasCompletedOnboarding": true}' > "$CLAUDE_JSON"
fi

mkdir -p "$USER_HOME/.claude/projects"
mkdir -p "$USER_HOME/.claude/sessions"
mkdir -p "$USER_HOME/.claude/cache"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.claude" 2>/dev/null || true

# =============================================================================
# STEP 3.5: Bind mount skills and agents (source of truth = /root/.hermes/tools/)
# =============================================================================
STEP "[3.5/7] Skills & agents bind mounts..."

# Mount /root/.claude/skills/ (symlinks to /root/.hermes/tools/) into workspace
# This gives Claude Code workers access to all skills without duplication
if [[ -d /root/.claude/skills && ! -z "$(ls -A /root/.claude/skills 2>/dev/null)" ]]; then
    if ! mount --bind /root/.claude/skills "$USER_HOME/.claude/skills" 2>/dev/null; then
        # Already mounted or permission issue - check if it's already correct
        if mountinfo=$(cat /proc/self/mountinfo 2>/dev/null | grep "$USER_HOME/.claude/skills "); then
            INFO "Skills mount: already in place"
        else
            WARN "Skills mount: using symlink fallback"
            # Fallback: create dir and symlink each skill individually
            mkdir -p "$USER_HOME/.claude/skills"
            for src in /root/.claude/skills/*/; do
                [[ -d "$src" ]] || continue
                skill_name=$(basename "$src")
                if [[ ! -L "$USER_HOME/.claude/skills/$skill_name" && ! -d "$USER_HOME/.claude/skills/$skill_name" ]]; then
                    ln -sfn "$src" "$USER_HOME/.claude/skills/$skill_name"
                fi
            done
        fi
    else
        INFO "Skills bind mount: /root/.claude/skills -> ~/.claude/skills"
    fi
fi

# Mount /root/.claude/agents/ (company-in-a-box + ai-marketing agents) into workspace
if [[ -d /root/.claude/agents && ! -z "$(ls -A /root/.claude/agents 2>/dev/null)" ]]; then
    mkdir -p "$USER_HOME/.claude/agents"
    if ! mount --bind /root/.claude/agents "$USER_HOME/.claude/agents" 2>/dev/null; then
        if mountinfo=$(cat /proc/self/mountinfo 2>/dev/null | grep "$USER_HOME/.claude/agents "); then
            INFO "Agents mount: already in place"
        else
            WARN "Agents mount: using symlink fallback"
            for src in /root/.claude/agents/*/; do
                [[ -d "$src" ]] || continue
                agent_name=$(basename "$src")
                if [[ ! -L "$USER_HOME/.claude/agents/$agent_name" && ! -d "$USER_HOME/.claude/agents/$agent_name" ]]; then
                    ln -sfn "$src" "$USER_HOME/.claude/agents/$agent_name"
                fi
            done
        fi
    else
        INFO "Agents bind mount: /root/.claude/agents -> ~/.claude/agents"
    fi
fi

# =============================================================================
# STEP 4: Permissions
# =============================================================================
STEP "[4/7] Permissions..."
find "$USER_HOME" -type d -exec chmod 755 {} \; 2>/dev/null || true
chmod 755 "$USER_HOME/.hermes"
chmod 755 "$USER_HOME/.hermes/config"

# Requests directory (workspace → root communication)
mkdir -p "$USER_HOME/.hermes/requests"
chmod 777 "$USER_HOME/.hermes/requests"  # workspace agent writes here
chmod +t "$USER_HOME/.hermes/requests"  # sticky bit

# =============================================================================
# STEP 5: Skills directory
# =============================================================================
STEP "[5/7] Skills directory..."

# Agent's local skills directory (writable by agent, hermes writes .hub cache here)
mkdir -p "$USER_HOME/.hermes/skills"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.hermes/skills"
chmod 700 "$USER_HOME/.hermes/skills"

# Add /opt/skills to external_dirs so hermes finds global skills
# (hermes writes .hub cache into ~/.hermes/skills, but reads SKILL.md from external_dirs)
_cfg="$USER_HOME/.hermes/config.yaml"
python3 - << PYEOF
import re
cfg = '$_cfg'
with open(cfg, 'r') as f: content = f.read()

# If already correct, nothing to do
if re.search(r'external_dirs:\s*\n\s*-\s*/opt/skills\s*\n', content):
    pass
elif 'external_dirs: []' in content:
    content = content.replace('external_dirs: []', 'external_dirs:\n    - /opt/skills')
else:
    # Rewrite the section properly
    lines = content.split('\n')
    new_lines = []
    skip = False
    for line in lines:
        if 'external_dirs' in line and '[]' not in line:
            skip = True
            new_lines.append('  external_dirs:')
            new_lines.append('    - /opt/skills')
        elif skip and line.strip().startswith('-'):
            pass  # skip old list items
        elif skip and line.strip() and not line.startswith('  '):
            skip = False
            new_lines.append(line)
        else:
            new_lines.append(line)
    content = '\n'.join(new_lines)

with open(cfg, 'w') as f: f.write(content)
PYEOF

# Agent's local skills (drafts, writable by agent only)
mkdir -p "$USER_HOME/.hermes/skills-local"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.hermes/skills-local"
chmod 700 "$USER_HOME/.hermes/skills-local"

# Agent's staged skills (proposed for approval)
mkdir -p "$USER_HOME/.hermes/skills-staged"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.hermes/skills-staged"
chmod 700 "$USER_HOME/.hermes/skills-staged"

INFO "Global skills: /opt/skills/ (via external_dirs in config.yaml)"
INFO "Local skills: ~/.hermes/skills-local/ (draft, writable)"

# =============================================================================
# STEP 6: Verification
# =============================================================================
STEP "[6/7] Verification..."
echo ""

FAILED=0
for tool in claude hermes aatosteam ai-migrate; do
    ver=$(timeout 10 sudo -u "$USERNAME" -i bash -lc "$tool --version 2>&1" | head -1)
    exitcode=$?
    if [[ $exitcode -eq 0 && -n "$ver" ]]; then
        echo "  $tool: $ver"
    else
        echo "  $tool: FAIL (exit $exitcode)"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo "  ============================================="
    INFO "Workspace '$USERNAME' fully configured!"
    echo "  ============================================="
else
    echo "  ============================================="
    ERROR "Workspace '$USERNAME' has $FAILED broken tool(s)"
    echo "  ============================================="
fi

echo ""
INFO "Quick test: sudo -u $USERNAME -i bash -lc 'claude --version'"
INFO "Root health: sudo $SCRIPT_DIR/infrastructure-manager.sh health"
echo ""
