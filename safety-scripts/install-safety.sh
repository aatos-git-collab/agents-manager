#!/bin/bash
# install-safety.sh — installs all system-wide safety scripts
# Run once per host. Idempotent. Self-locating — works from any home directory.
set -euo pipefail

# Self-locate: derive AGENTS_HOME from script location
if [ -z "${AGENTS_HOME:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ "$(basename "$SCRIPT_DIR")" = "safety-scripts" ]; then
        AGENTS_HOME="$(dirname "$SCRIPT_DIR")"
    else
        AGENTS_HOME="$SCRIPT_DIR"
    fi
    export AGENTS_HOME
fi

HOOKS_DIR="$AGENTS_HOME/git-hooks"
SAFETY_DIR="$AGENTS_HOME/safety-scripts"
CRON_SAFETY="/etc/cron.d/agents-manager-cron-safety"
GLOBAL_HOOKS="$HOME/.git-hooks-global"

echo "=== Installing System Safety Scripts ==="
echo "  AGENTS_HOME: $AGENTS_HOME"

# 1. Git hooks — global git hooksPath (applies to ALL repos for this user)
mkdir -p "$GLOBAL_HOOKS"
for hook in pre-push pre-commit post-init; do
    [ -f "$HOOKS_DIR/$hook" ] && cp "$HOOKS_DIR/$hook" "$GLOBAL_HOOKS/$hook" && chmod +x "$GLOBAL_HOOKS/$hook"
done
git config --global core.hooksPath "$GLOBAL_HOOKS"
echo "  Git hooks: $GLOBAL_HOOKS"

# 2. Safety scripts — make executable (no sudo needed)
for f in "$SAFETY_DIR"/*.sh; do
    [ -f "$f" ] && chmod +x "$f" && echo "  Safety: $(basename $f)"
done

# 3. Cron safety (root-level, survives crontab resets)
[ -f "$CRON_SAFETY" ] && echo "  cron-safety: $CRON_SAFETY (hourly)"

echo ""
echo "=== Available to ALL agents ==="
ls -la "$SAFETY_DIR/"
echo ""
echo "=== Usage ==="
echo "  port-guard check <port> <label>    # check if port is free"
echo "  port-guard reserve <port> <label> <pid>  # lock a port for process lifetime"
echo "  port-guard release <port> <label>  # release a reservation"
echo "  container-guard check <file.yml>    # validate compose before deploy"
echo ""
echo "  Git hooks: pre-push (blocks non aatos-git-collab pushes), pre-commit (blocks secrets)"