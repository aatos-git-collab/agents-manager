#!/bin/bash
# Detect AGENTS_HOME — allows install on any user home
if [ -z "$AGENTS_HOME" ]; then
    _self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Traverse up to find .agents-manager directory
    if [ "$(basename "$_self")" = "safety-scripts" ]; then
        AGENTS_HOME="$(dirname "$_self")"
    elif [ "$(basename "$_self")" = "watchdogs" ]; then
        AGENTS_HOME="$(dirname "$(dirname "$_self")")"
    elif [ "$(basename "$_self")" = ".monitor" ]; then
        AGENTS_HOME="$(dirname "$_self")"
    elif [ "$(basename "$_self")" = "git-hooks" ]; then
        AGENTS_HOME="$(dirname "$_self")"
    elif [ "$(basename "$_self")" = ".monitor/watchdogs" ]; then
        AGENTS_HOME="$(dirname "$(dirname "$_self")")"
    else
        AGENTS_HOME="/root/.agents-manager"
    fi
    export AGENTS_HOME
fi

# Gateway watchdog — NO kill, NO SIGTERM, ONLY observe and restart
# Escalation: systemd → hermes CLI → Claude Code agent
set -euo pipefail

LOG="$AGENTS_HOME/.monitor/logs/watchdog.log"
NOW=$(date '+%Y-%m-%d %H:%M:%S')
GATEWAY_LOG=""$HERMES_HOME/logs/gateway.log""

log() { echo "[$NOW] $1" | tee -a "$LOG"; }

# ─── STEP 1: Is gateway process alive? ───
GATEWAY_PID=$(systemctl show --property MainPID --value hermes-gateway.service 2>/dev/null || echo "0")
GATEWAY_STATUS=$(systemctl is-active hermes-gateway.service 2>/dev/null || echo "unknown")

if [ "$GATEWAY_STATUS" = "active" ] && [ -n "$GATEWAY_PID" ] && [ "$GATEWAY_PID" != "0" ]; then
    # Verify PID is actually running (PID can be stale in systemd)
    if kill -0 "$GATEWAY_PID" 2>/dev/null; then
        log "OK: gateway PID=$GATEWAY_PID alive, no action needed"
        exit 0  # Clean — no restart needed
    fi
fi

# ─── STEP 2: Gateway is dead — Escalation chain ───
log "DEAD: gateway status=$GATEWAY_STATUS PID=$GATEWAY_PID — starting escalation"

# Level 1: Try systemd restart
log "LEVEL-1: systemctl start hermes-gateway.service"
systemctl start hermes-gateway.service 2>/dev/null || true
sleep 8  # Give it time to start

GATEWAY_PID=$(systemctl show --property MainPID --value hermes-gateway.service 2>/dev/null || echo "0")
if [ "$GATEWAY_PID" != "0" ] && kill -0 "$GATEWAY_PID" 2>/dev/null; then
    log "LEVEL-1 SUCCESS: gateway PID=$GATEWAY_PID restored via systemd"
    exit 1  # Restarted — alert
fi

# Level 2: Try hermes CLI restart
log "LEVEL-2: hermes gateway run (CLI fallback)"
sudo -u root /root/.local/bin/hermes gateway run >> "$GATEWAY_LOG" 2>&1 &
sleep 10

GATEWAY_PID=$(systemctl show --property MainPID --value hermes-gateway.service 2>/dev/null || echo "0")
if [ "$GATEWAY_PID" != "0" ] && kill -0 "$GATEWAY_PID" 2>/dev/null; then
    log "LEVEL-2 SUCCESS: gateway PID=$GATEWAY_PID restored via hermes CLI"
    exit 1  # Restarted — alert
fi

# Level 3: Trigger Claude Code agent to diagnose
log "LEVEL-3: Triggering Claude Code to diagnose and fix gateway"
/root/.local/bin/claude-code --dangerously-skip-model-selection \
    --system-prompt "Gateway is dead. Diagnose why hermes-gateway.service won't start. 
    Check: journalctl -u hermes-gateway -n50, systemctl status hermes-gateway, 
    "$HERMES_HOME/logs/gateway.log". Fix it and restart. Report what was wrong." \
    --prompt "hermes gateway is not starting. check what's wrong and fix it. 
    run: journalctl -u hermes-gateway -n50 && systemctl status hermes-gateway && 
    cat "$HERMES_HOME/logs/gateway.log" | tail -50. fix the issue and restart." \
    2>> "$LOG" &
CLAUDE_PID=$!
log "LEVEL-3: Claude Code agent spawned PID=$CLAUDE_PID"

exit 2  # Critical — AI agent deployed