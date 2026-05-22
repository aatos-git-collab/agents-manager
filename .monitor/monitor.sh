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

# Monitor runner — lightweight cron watchdog
# Runs every minute, checks if gateway is alive
# If dead: escalation chain → systemd → hermes CLI → Claude Code agent
set -euo pipefail

LOG_DIR="$AGENTS_HOME/.monitor/logs"
LOG="$LOG_DIR/cron.log"
NOW=$(date '+%Y-%m-%d %H:%M:%S')
WATCHDOG="$AGENTS_HOME/.monitor/watchdogs/check_hermes.sh"
SESSION_GUARDIAN="$AGENTS_HOME/.monitor/watchdogs/session-guardian.sh"

mkdir -p "$LOG_DIR"

echo "[$NOW] === Monitor Run ===" >> "$LOG"

if [ ! -x "$WATCHDOG" ]; then
    echo "[$NOW] ERROR: watchdog not found at $WATCHDOG" >> "$LOG"
    exit 1
fi

# Run gateway watchdog — exit codes:
#   0 = gateway alive, no action
#   1 = gateway was dead but restored, alert
#   2 = gateway dead, escalation deployed, critical alert
result=$("$WATCHDOG" 2>&1) && exitcode=0 || exitcode=$?
echo "[$NOW] gateway: exit=$exitcode: $result" >> "$LOG"

# Run session guardian (session auto-new trigger)
if [ -x "$SESSION_GUARDIAN" ]; then
    result2=$("$SESSION_GUARDIAN" 2>&1) || true
    echo "[$NOW] session: $result2" >> "$LOG"
fi

echo "[$NOW] === Done ===" >> "$LOG"

# Exit code: propagate for cron notification
exit $exitcode