#!/bin/bash
# config-backup-restore: Force restore from backup repo (no version check)
# Use when backup is definitely the correct state

set -euo pipefail

BACKUP_CLONE="/tmp/agents-backup-restore"
log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "=== FORCE RESTORE FROM BACKUP ==="

# Always restore these (safe — not versioned configs)
for file in SOUL.md USER.md USER-HABITS.md; do
    [ -f "$BACKUP_CLONE/$file" ] && cp "$BACKUP_CLONE/$file" "$HOME/.hermes/$file" && log "RESTORED: $file"
done

# Restore missing skills
for skill in "$BACKUP_CLONE/skills"/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    [ "$name" = "config-backup-restore" ] && continue
    if [ ! -d "$HOME/.hermes/skills/$name" ]; then
        cp -r "$skill" "$HOME/.hermes/skills/"
        log "RESTORED: skill/$name"
    fi
done

# Restore CEO agent
if [ -d "$BACKUP_CLONE/agents/ceo" ]; then
    mkdir -p "$HOME/.hermes/hermes-agent/agent/ceo"
    cp -r "$BACKUP_CLONE/agents/ceo"/* "$HOME/.hermes/hermes-agent/agent/ceo/" 2>/dev/null || true
    log "RESTORED: CEO agent"
fi

log "=== FORCE RESTORE DONE ==="
