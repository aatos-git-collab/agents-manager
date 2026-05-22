#!/bin/bash
#
# cron-safety.sh — Mission Control Agent Cron Safety System
#
# This script runs hourly via cron to ensure no agent-created cron entries
# can cause cascade failures by duplicating uncontrollably.
#
# It is the architecture-level safety net for agent-created cron jobs.
#
# Install: Add to crontab: 0 * * * * bash /path/to/mission-control/scripts/cron-safety.sh
#

set -euo pipefail

# Configuration
TARGET_USER="${CRON_SAFETY_USER:-root}"
LOG_FILE="${CRON_SAFETY_LOG:-/var/log/cron-safety.log}"
BACKUP_DIR="${CRON_SAFETY_BACKUP_DIR:-/var/backups/cron}"
LOCK_FILE="/tmp/.cron-safety.lock"
MAX_CRON_ENTRIES_PER_SCRIPT="${MAX_CRON_ENTRIES_PER_SCRIPT:-1}"

# Safety thresholds
WATCHDOG_MAX_ENTRIES=5           # Max watchdog entries before alert
AGENT_SCRIPT_MAX_ENTRIES=3       # Max entries per agent script
TOTAL_MAX_ENTRIES=100            # Max total cron lines (excluding comments)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRON-SAFETY] $*" | tee -a "$LOG_FILE" 2>/dev/null || echo "[CRON-SAFETY] $*"
}

mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE" 2>/dev/null || true)"

# === SAFETY: Prevent concurrent runs ===
if [[ -f "$LOCK_FILE" ]]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        log "Already running (PID $pid), exiting"
        exit 0
    fi
    log "Stale lock found (PID $pid), removing"
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# === Get crontab ===
log "Checking crontab for user $TARGET_USER"

crontab_content=$(crontab -l 2>/dev/null || true)

if [[ -z "$crontab_content" ]]; then
    log "Crontab is empty, nothing to check"
    exit 0
fi

# === Backup current crontab ===
backup_file="$BACKUP_DIR/crontab_$(date '+%Y%m%d_%H%M%S').txt"
echo "$crontab_content" > "$backup_file"
log "Backed up crontab to $backup_file"

# === Count and categorize entries ===
total_lines=$(echo "$crontab_content" | grep -v "^#" | grep -v "^$" | wc -l)
unique_lines=$(echo "$crontab_content" | grep -v "^#" | grep -v "^$" | sort -u | wc -l)
watchdog_count=$(echo "$crontab_content" | grep -c "watchdog" || echo 0)

# Find duplicate lines
duplicate_count=0
if [[ "$total_lines" -gt "$unique_lines" ]]; then
    duplicate_count=$((total_lines - unique_lines))
fi

# === Detect issues ===
ISSUES=()

# Check 1: Total entries too high
if [[ "$total_lines" -gt "$TOTAL_MAX_ENTRIES" ]]; then
    ISSUES+=("CRITICAL: Total cron entries ($total_lines) exceeds max ($TOTAL_MAX_ENTRIES)")
fi

# Check 2: Too many watchdog entries
if [[ "$watchdog_count" -gt "$WATCHDOG_MAX_ENTRIES" ]]; then
    ISSUES+=("WARNING: Watchdog entries ($watchdog_count) exceeds threshold ($WATCHDOG_MAX_ENTRIES)")
fi

# Check 3: Duplicate entries
if [[ "$duplicate_count" -gt 0 ]]; then
    ISSUES+=("WARNING: $duplicate_count duplicate cron entries found")
fi

# === Check per-script duplicate detection ===
# Group lines by script path and count
script_counts=$(echo "$crontab_content" | grep -v "^#" | grep -v "^$" | sed 's/.*bash //' | sed 's/ .*//' | sort | uniq -c | sort -rn)
while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    script=$(echo "$line" | awk '{print $2}')
    if [[ "$count" -gt "$AGENT_SCRIPT_MAX_ENTRIES" ]]; then
        ISSUES+=("WARNING: Script '$script' has $count entries (max: $AGENT_SCRIPT_MAX_ENTRIES)")
    fi
done <<< "$script_counts"

# === Auto-fix if issues found ===
if [[ ${#ISSUES[@]} -gt 0 ]]; then
    log "ISSUES DETECTED:"
    for issue in "${ISSUES[@]}"; do
        log "  - $issue"
    done

    # Deduplicate: Keep only the first occurrence of each unique line
    log "Auto-deduplicating crontab..."

    # Keep header and comments
    header=$(echo "$crontab_content" | grep -E "^#|^$" || true)

    # Keep unique entries (first occurrence wins)
    deduplicated=$(echo "$crontab_content" | grep -v "^#" | grep -v "^$" | sort -u)

    # Reconstruct
    {
        echo "$header"
        echo ""
        echo "# === Auto-deduped by cron-safety.sh on $(date '+%Y-%m-%d %H:%M') ==="
        echo "# Original: $total_lines lines, $duplicate_count duplicates"
        echo "# Kept unique entries only"
        echo ""
        echo "$deduplicated"
    } | crontab -

    new_count=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l)
    log "Crontab fixed: $total_lines -> $new_count entries"

    # Log security event
    log "SECURITY_EVENT: crontab_auto_fixed entries=$total_lines new_entries=$new_count"

else
    log "Crontab healthy: $total_lines entries, no duplicates"
fi

# === Periodic cleanup of old backups (keep last 50) ===
backup_count=$(ls -1 "$BACKUP_DIR"/crontab_*.txt 2>/dev/null | wc -l)
if [[ "$backup_count" -gt 50 ]]; then
    ls -1t "$BACKUP_DIR"/crontab_*.txt 2>/dev/null | tail -$((backup_count - 50)) | xargs rm -f 2>/dev/null
    log "Cleaned up old backups (kept 50)"
fi

log "Safety check complete"
