#!/bin/bash
# =====================================================================
# env-from-container.sh — Capture Docker container env and create .env
# =====================================================================
# Run this BEFORE install to prepopulate .env from container environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/.env}"

echo "Capturing container environment to: $ENV_FILE"

# Key vars to capture from container env
KEY_VARS="
ANTHROPIC_AUTH_TOKEN
ANTHROPIC_API_KEY
ANTHROPIC_BASE_URL
ANTHROPIC_MODEL
ANTHROPIC_DEFAULT_SONNET_MODEL
ANTHROPIC_DEFAULT_OPUS_MODEL
ANTHROPIC_DEFAULT_HAIKU_MODEL
MINIMAX_API_KEY
MINIMAX_ANTHROPIC_BASE_URL
LLM_MODEL
HERMES_TUI_THEME
HERMES_TUI_LIGHT
MATTERMOST_URL
MATTERMOST_TOKEN
MATTERMOST_ALLOWED_USERS
MATTERMOST_REPLY_MODE
MATTERMOST_REQUIRE_MENTION
"

# Also include any CLAUDE_CODE_* and ANTHROPIC_* vars
EXTRA_VARS=$(env | grep -E "^(CLAUDE_CODE_|ANTHROPIC_|TEAMMATE_)" | cut -d= -f1 | grep -v "TOKEN" | tr '\n' ' ')
ALL_VARS="${KEY_VARS} ${EXTRA_VARS}"

: > "$ENV_FILE"

for var in $ALL_VARS; do
    # Get value from environment
    value="${!var:-}"

    # Skip empty values
    [ -z "$value" ] && continue

    # Skip template strings (don't copy {{...}} literally)
    [[ "$value" == \{\{*\}\} ]] && continue

    # Skip values that look like template references
    [[ "$value" == *'{{'* ]] && continue

    # Write to .env
    echo "${var}=${value}" >> "$ENV_FILE"
    echo "  $var: captured"
done

# Derive MINIMAX_API_KEY from ANTHROPIC_AUTH_TOKEN if needed
if ! grep -q "MINIMAX_API_KEY=sk-" "$ENV_FILE" 2>/dev/null; then
    if grep -q "ANTHROPIC_AUTH_TOKEN=sk-" "$ENV_FILE" 2>/dev/null; then
        anthropic_key=$(grep "ANTHROPIC_AUTH_TOKEN=" "$ENV_FILE" | cut -d'=' -f2)
        echo "MINIMAX_API_KEY=${anthropic_key}" >> "$ENV_FILE"
        echo "  MINIMAX_API_KEY: derived from ANTHROPIC_AUTH_TOKEN"
    fi
fi

echo ""
echo "Done! .env written to: $ENV_FILE"
echo ""
echo "Now run: bash $SCRIPT_DIR/actions.sh install global"
