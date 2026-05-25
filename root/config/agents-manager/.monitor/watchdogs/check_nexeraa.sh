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

# Nexeraa container watchdog
set -euo pipefail

CONTAINER="nexeraa"
LOG="$AGENTS_HOME/.monitor/logs/nexeraa_watchdog.log"
ALERT_SENT="$AGENTS_HOME/.monitor/logs/.nexeraa_alert_sent"
NOW=$(date '+%Y-%m-%d %H:%M:%S')

docker inspect "$CONTAINER" > /dev/null 2>&1 || {
    echo "[$NOW] ERROR: Container $CONTAINER not found" >> "$LOG"
    exit 2
}

STATUS=$(docker inspect "$CONTAINER" --format '{{.State.Status}}')
RUNNING=$(docker inspect "$CONTAINER" --format '{{.State.Running}}')

if [ "$RUNNING" = "false" ] || [ "$STATUS" != "running" ]; then
    echo "[$NOW] DEAD: $CONTAINER status=$STATUS running=$RUNNING — restarting" >> "$LOG"
    docker start "$CONTAINER" >> "$LOG" 2>&1
    sleep 10
    NEW_STATUS=$(docker inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null)
    if [ "$NEW_STATUS" = "running" ]; then
        echo "[$NOW] RESTORED: $CONTAINER restarted" >> "$LOG"
        rm -f "$ALERT_SENT"
        exit 1
    else
        echo "[$NOW] FAIL: $CONTAINER not restored" >> "$LOG"
        exit 2
    fi
fi

curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    https://mm.agent.nexeraa.io/api/v4/system/ping 2>/dev/null | grep -q "200" && \
    echo "[$NOW] OK: $CONTAINER + Mattermost API healthy" >> "$LOG" || \
    echo "[$NOW] WARN: $CONTAINER running but Mattermost API unreachable" >> "$LOG"
exit 0
