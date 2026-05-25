#!/bin/bash
# config-backup-restore: Self-heal script
# Pulls backup repo, diffs, auto-restores drifted/missing files

set -euo pipefail

SKILL_DIR="$HOME/.hermes/skills/config-backup-restore"
BACKUP_CLONE="/tmp/agents-backup-restore"
MANIFEST="$SKILL_DIR/manifests/backup-manifest.json"
LOG_DIR="$SKILL_DIR/logs"
LOG="$LOG_DIR/self-heal-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR" "$SKILL_DIR/manifests"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

# ── Step 1: Pull latest backup repo ────────────────────────────────────────
log "=== SELF-HEAL START ==="
log "Pulling latest from backup repo..."

if [ -d "$BACKUP_CLONE/.git" ]; then
    git -C "$BACKUP_CLONE" fetch origin chro 2>>"$LOG" || true
    git -C "$BACKUP_CLONE" reset --hard "origin/chro" >>"$LOG" 2>&1
else
    log "Clone missing, cloning fresh..."
    rm -rf "$BACKUP_CLONE"
    git clone --branch chro --single-branch \
        "https://github.com/aatos-git-collab/agents-backup.git" \
        "$BACKUP_CLONE" >>"$LOG" 2>&1
fi

BACKUP_COMMIT=$(git -C "$BACKUP_CLONE" rev-parse HEAD 2>/dev/null | cut -c1-12)
log "Backup repo at commit: $BACKUP_COMMIT"

# ── Step 2: Diff config.yaml ────────────────────────────────────────────────
log "=== CONFIG DIFF ==="
DIFF_OUTPUT=$(diff "$HOME/.hermes/config.yaml" "$BACKUP_CLONE/config.yaml" 2>/dev/null || true)
if [ -n "$DIFF_OUTPUT" ]; then
    BACKUP_VER=$(grep '_config_version:' "$BACKUP_CLONE/config.yaml" | awk '{print $2}' || echo "unknown")
    CURRENT_VER=$(grep '_config_version:' "$HOME/.hermes/config.yaml" | awk '{print $2}' || echo "unknown")
    log "Config drift detected! Backup v${BACKUP_VER} vs Current v${CURRENT_VER}"

    if [ "$CURRENT_VER" -gt "$BACKUP_VER" ] 2>/dev/null; then
        log "Current config is NEWER (v${CURRENT_VER} > v${BACKUP_VER}) — keeping current, NOT overwriting"
        CONFIG_RESTORED=0
    else
        log "Backup config is NEWER or equal — restoring..."
        cp "$BACKUP_CLONE/config.yaml" "$HOME/.hermes/config.yaml"
        CONFIG_RESTORED=1
        log "RESTORED: config.yaml"
    fi
else
    log "Config: OK (no drift)"
    CONFIG_RESTORED=0
fi

# ── Step 3: Restore SOUL.md ─────────────────────────────────────────────────
log "=== SOUL.md CHECK ==="
if [ -f "$BACKUP_CLONE/SOUL.md" ]; then
    if [ ! -f "$HOME/.hermes/SOUL.md" ]; then
        cp "$BACKUP_CLONE/SOUL.md" "$HOME/.hermes/SOUL.md"
        log "RESTORED: SOUL.md (was missing)"
    else
        log "SOUL.md: OK (exists)"
    fi
fi

# ── Step 4: Restore USER files ───────────────────────────────────────────────
log "=== USER FILES ==="
for file in USER.md USER-HABITS.md; do
    if [ -f "$BACKUP_CLONE/$file" ]; then
        if [ ! -f "$HOME/.hermes/$file" ]; then
            cp "$BACKUP_CLONE/$file" "$HOME/.hermes/$file"
            log "RESTORED: $file (was missing)"
        else
            log "$file: OK (exists)"
        fi
    fi
done

# ── Step 5: Restore missing skills ──────────────────────────────────────────
log "=== SKILLS CHECK ==="
CURRENT_SKILLS=$(ls -1 "$HOME/.hermes/skills/" 2>/dev/null | wc -l)
BACKUP_SKILLS=$(ls -1 "$BACKUP_CLONE/skills/" 2>/dev/null | wc -l)
log "Current skills: $CURRENT_SKILLS | Backup skills: $BACKUP_SKILLS"

RESTORED_COUNT=0
for skill in "$BACKUP_CLONE/skills"/*/; do
    [ -d "$skill" ] || continue
    skill_name=$(basename "$skill")
    # Don't restore the config-backup-restore skill itself
    [ "$skill_name" = "config-backup-restore" ] && continue

    if [ ! -d "$HOME/.hermes/skills/$skill_name" ]; then
        cp -r "$skill" "$HOME/.hermes/skills/$skill_name/"
        log "RESTORED: skill/$skill_name"
        ((RESTORED_COUNT++)) || true
    fi
done

if [ "$RESTORED_COUNT" -gt 0 ]; then
    log "Total skills restored: $RESTORED_COUNT"
else
    log "Skills: OK (no missing skills)"
fi

# ── Step 6: Restore CEO agent ────────────────────────────────────────────────
log "=== CEO AGENT ==="
CEO_BACKUP="$BACKUP_CLONE/agents/ceo"
CEO_DEST="$HOME/.hermes/hermes-agent/agent/ceo"
if [ -d "$CEO_BACKUP" ] && [ ! -d "$CEO_DEST" ]; then
    mkdir -p "$CEO_DEST"
    cp -r "$CEO_BACKUP"/* "$CEO_DEST/" 2>/dev/null || true
    log "RESTORED: CEO agent"
else
    log "CEO agent: OK (exists or no backup)"
fi

# ── Step 7: Memory files ────────────────────────────────────────────────────
log "=== MEMORY FILES ==="
MEMORY_BACKUP="$BACKUP_CLONE/memory"
if [ -d "$MEMORY_BACKUP" ]; then
    for item in "$MEMORY_BACKUP"/*; do
        [ -e "$item" ] || continue
        item_name=$(basename "$item")
        if [ ! -e "$HOME/.hermes/memories/$item_name" ]; then
            mkdir -p "$HOME/.hermes/memories"
            cp -r "$item" "$HOME/.hermes/memories/$item_name"
            log "RESTORED: memories/$item_name"
        fi
    done
fi

# ── Step 8: Git push safety hook ────────────────────────────────────────────
log "=== GIT PUSH SAFETY ==="
if [ -f "$BACKUP_CLONE/scripts/git-push-safety.sh" ]; then
    if [ ! -f "$HOME/.git-hooks/pre-push" ]; then
        bash "$BACKUP_CLONE/scripts/git-push-safety.sh" >>"$LOG" 2>&1
        log "INSTALLED: git push safety hook"
    else
        log "Git push safety: OK (already installed)"
    fi
fi

# ── Step 9: Hermes browser health check ─────────────────────────────────────
log "=== BROWSER HEALTH ==="
HEALTH=$(curl -s --max-time 5 http://localhost:9377/health 2>/dev/null || echo '{"ok":false}')
if echo "$HEALTH" | grep -q '"ok":true'; then
    log "camoufox: HEALTHY (port 9377)"
else
    log "camoufox: UNHEALTHY — attempting self-heal..."
    bash "$HOME/.hermes/skills/hermes-browser/run.sh heal" >>"$LOG" 2>&1 || true
fi

# ── Step 10: Update manifest ────────────────────────────────────────────────
log "=== UPDATING MANIFEST ==="
cat > "$MANIFEST" <<EOF
{
  "last_backup": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_self_heal": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "backup_commit": "$BACKUP_COMMIT",
  "config_restored": $CONFIG_RESTORED,
  "skills_restored_count": $RESTORED_COUNT,
  "log": "$(basename "$LOG")"
}
EOF

# ── Summary ─────────────────────────────────────────────────────────────────
RESTORED_TOTAL=$((CONFIG_RESTORED + RESTORED_COUNT))
if [ "$RESTORED_TOTAL" -eq 0 ]; then
    log "=== SELF-HEAL COMPLETE: [BACKUP OK — nothing to restore] ==="
    echo "[BACKUP OK]"
else
    log "=== SELF-HEAL COMPLETE: [RESTORED $RESTORED_TOTAL items] ==="
    echo "[RESTORED $RESTORED_TOTAL items — see $LOG]"
fi
