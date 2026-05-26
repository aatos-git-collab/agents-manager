#!/bin/bash
set -e

echo "**** Starting Codex Container ****"

# Set environment variables from args
export HOME="/config"

# Create claude settings directories and configs
mkdir -p /root/.claude/settings
mkdir -p /config/.claude/settings

# Write root claude config
python3 << 'PYEOF'
import os, json
settings = {
    "skipDangerousModePermissionPrompt": True,
    "env": {
        "ANTHROPIC_BASE_URL": os.environ.get("MINIMAX_ANTHROPIC_BASE_URL", ""),
        "ANTHROPIC_MODEL": os.environ.get("LLM_MODEL", ""),
        "ANTHROPIC_DEFAULT_SONNET_MODEL": os.environ.get("LLM_MODEL", ""),
        "ANTHROPIC_DEFAULT_OPUS_MODEL": os.environ.get("LLM_MODEL", ""),
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": os.environ.get("LLM_MODEL", ""),
        "CLAUDE_CODE_SUBAGENT_MODEL": os.environ.get("LLM_MODEL", ""),
        "ANTHROPIC_AUTH_TOKEN": os.environ.get("ANTHROPIC_API_KEY", ""),
        "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "10",
        "teammateMode": "tmux",
        "MINIMAX_API_KEY": os.environ.get("MINIMAX_API_KEY", ""),
        "GITHUB_TOKEN": os.environ.get("GITHUB_TOKEN", ""),
        "MATTERMOST_URL": os.environ.get("MATTERMOST_URL", ""),
        "MATTERMOST_TOKEN": os.environ.get("MATTERMOST_TOKEN", "")
    },
    "dangerouslyAlwaysAllow": True,
    "allow": ["Edit", "Write", "Bash", "Read", "Glob", "Grep", "WebFetch", "WebSearch", "TodoRead", "TodoWrite"]
}
os.makedirs("/root/.claude/settings", exist_ok=True)
with open("/root/.claude/settings.json", "w") as f:
    json.dump(settings, f, indent=2)
print("wrote /root/.claude/settings.json")
PYEOF

# Write .claude.json for root (skip onboarding)
echo '{"hasCompletedOnboarding": true}' > /root/.claude.json

# Add PATH to bashrc
if ! grep -q '.local/bin' /root/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /root/.bashrc
fi

# Create code-server settings directory
mkdir -p /config/.config/code-server/User

# Copy VSCode settings if exists
if [ -f /config/agents-manager/settings.json ]; then
    cp /config/agents-manager/settings.json /config/.config/code-server/User/settings.json
    echo "copied VSCode settings"
fi

# Create symlinks for agents-manager
if [ -f /config/agents-manager/actions.sh ]; then
    ln -sf /config/agents-manager/actions.sh /usr/local/bin/agents-manager 2>/dev/null || true
    ln -sf /config/agents-manager/actions.sh /usr/local/bin/actions 2>/dev/null || true
    echo "created agents-manager symlinks"
fi

echo "**** Codex setup complete, starting code-server ****"

# Execute the CMD
exec "$@"