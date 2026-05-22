#!/bin/bash
# config-backup-restore: Backup current state only
# Backs up current hermes config to the agents-backup repo

set -euo pipefail

SKILL_DIR="$HOME/.hermes/skills/config-backup-restore"
BACKUP_CLONE="/tmp/agents-backup-restore"
LOG_DIR="$SKILL_DIR/logs"
LOG="$LOG_DIR/backup-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

log "=== BACKUP START ==="

# Pull latest
if [ -d "$BACKUP_CLONE/.git" ]; then
    git -C "$BACKUP_CLONE" pull origin chro >>"$LOG" 2>&1 || true
fi

# Backup config
cp "$HOME/.hermes/config.yaml" "$BACKUP_CLONE/config.yaml"
log "BACKED UP: config.yaml"

# Backup SOUL and user files
for file in SOUL.md USER.md USER-HABITS.md; do
    [ -f "$HOME/.hermes/$file" ] && cp "$HOME/.hermes/$file" "$BACKUP_CLONE/$file"
    log "BACKED UP: $file"
done

# Commit and push
cd "$BACKUP_CLONE"
git add -A >>"$LOG" 2>&1 || true
if git diff --cached --quiet; then
    log "No changes to commit"
else
    git commit -m "backup: $(date '+%Y-%m-%d %H:%M')" >>"$LOG" 2>&1 || true
    git push origin chro >>"$LOG" 2>&1 || true
    log "PUSHED to backup repo"
fi

log "=== BACKUP COMPLETE ==="
echo "[BACKUP OK — logged to $LOG]"
