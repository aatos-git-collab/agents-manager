#!/bin/bash
# restore.sh — Git restore for Hermes Memory System
# Usage: bash restore.sh [graphify|honcho|daily|all]
# Honcho restore: config.json restored → re-run `hermes honcho setup` if needed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HOME/.hermes/hermes-agent/venv"

MEMORY_DIR="$HOME/.hermes/memory"
GRAPHIFY_DIR="$MEMORY_DIR/graphify"
HONCHO_DIR="$MEMORY_DIR/honcho"
HONCHO_CONFIG="$HOME/.honcho/config.json"
HONCHO_CONFIG_DIR="$(dirname "$HONCHO_CONFIG")"
DAILY_DIR="$MEMORY_DIR/daily"
WEEKLY_DIR="$MEMORY_DIR/weekly"

BACKUP_GIT="${BACKUP_GIT:-$HOME/.hermes/memory-backup.git}"
WORK_DIR="/tmp/memory-backup-restore"
TARGET="${1:-all}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[restore]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# ─── Sync backup repo → work dir ─────────────────────────────────────────────
sync_backup() {
    log "Syncing backup from $BACKUP_GIT..."

    if [ ! -d "$BACKUP_GIT" ]; then
        fail "Backup repo not found: $BACKUP_GIT"
        fail "Run 'bash backup.sh' first to create a backup"
        exit 1
    fi

    # Fresh clone to temp dir
    rm -rf "$WORK_DIR"
    mkdir -p "$(dirname "$WORK_DIR")"

    local branch_pushed=0
    for branch in main master; do
        if git clone --branch "$branch" "$BACKUP_GIT" "$WORK_DIR" 2>/dev/null; then
            ok "Cloned branch: $branch"
            branch_pushed=1
            break
        fi
    done

    if [ "$branch_pushed" -eq 0 ]; then
        # No branches exist yet — try shallow clone of any ref
        if git clone "$BACKUP_GIT" "$WORK_DIR" 2>/dev/null; then
            ok "Cloned (no branch — using current HEAD)"
        else
            fail "Could not clone $BACKUP_GIT — repo may be empty or corrupted"
            ls "$BACKUP_GIT/" 2>/dev/null | head -10
            exit 1
        fi
    fi

    # Ensure work dir has content
    if [ ! -d "$WORK_DIR" ] || [ -z "$(ls -A "$WORK_DIR" 2>/dev/null)" ]; then
        fail "Backup repo is empty — nothing to restore"
        exit 1
    fi

    ok "Backup synced to $WORK_DIR"
    ls "$WORK_DIR/" 2>/dev/null
}

# ─── Restore Honcho config (CRITICAL) ───────────────────────────────────────
# Honcho is self-hosted. Three restore targets:
# 1. ~/.honcho/config.json — workspace API key (client config)
# 2. /root/honcho/ — self-hosted server files (jwt_secret, docker-compose)
# 3. honcho database — via psql restore from honcho-db.sql.gz
restore_honcho() {
    log "Restoring Honcho..."

    # 1. Restore workspace API key (~/.honcho/config.json)
    if [ -d "$WORK_DIR/honcho" ]; then
        local config_src="$WORK_DIR/honcho/config.json"
        if [ -f "$config_src" ]; then
            if [ -f "$HONCHO_CONFIG" ]; then
                cp "$HONCHO_CONFIG" "${HONCHO_CONFIG}.backup-$(date +%s)" 2>/dev/null || true
            fi
            mkdir -p "$HONCHO_CONFIG_DIR"
            cp "$config_src" "$HONCHO_CONFIG"
            chmod 600 "$HONCHO_CONFIG"
            ok "Restored ~/.honcho/config.json"
        fi
    fi

    # 2. Restore self-hosted server files
    if [ -d "$WORK_DIR/honcho-server" ]; then
        mkdir -p /root/honcho
        for file in "$WORK_DIR/honcho-server/"*; do
            [ -f "$file" ] || continue
            local fname=$(basename "$file")
            cp "$file" "/root/honcho/$fname"
            ok "Restored /root/honcho/$fname"
        done
    fi

    # 3. Restore PostgreSQL database
    restore_honcho_db() {
        local db_dump="$WORK_DIR/honcho-db.sql.gz"
        local container="honcho-database-1"
        local db_user="postgres"
        local db_name="postgres"

        if [ ! -f "$db_dump" ] && [ ! -d "$WORK_DIR/honcho-pgdata" ]; then
            warn "No Honcho DB backup found — DB restore skipped"
            return 0
        fi

        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            warn "Honcho database container not running — cannot restore DB"
            warn "Start Honcho first: cd /root/honcho && docker compose up -d"
            return 0
        fi

        # Stop API to avoid writes during restore
        docker stop honcho-api-1 2>/dev/null || true
        sleep 1

        if [ -f "$db_dump" ]; then
            gunzip < "$db_dump" | docker exec -i "$container" psql -U "$db_user" -d "$db_name" 2>/dev/null
            ok "DB restored from SQL dump"
        else
            # Raw pgdata restore
            local pgdata_vol=$(docker inspect "$container" --format '{{range .Mounts}}{{if eq .Name "honcho_pgdata"}}{{.Name}}{{end}}{{end}}' 2>/dev/null)
            if [ -n "$pgdata_vol" ] && [ -d "$WORK_DIR/honcho-pgdata/pgdata" ]; then
                docker run --rm \
                    -v "$pgdata_vol:/dest" \
                    -v "$WORK_DIR/honcho-pgdata:/src:ro" \
                    alpine:latest \
                    sh -c "cp -r /src/pgdata/. /dest/pgdata/ && echo 'pgdata restored'" || \
                warn "pgdata restore failed"
                ok "DB restored from pgdata volume"
            fi
        fi

        # Restart API
        docker start honcho-api-1 2>/dev/null || true
    }
    restore_honcho_db

    if [ -f "$HONCHO_CONFIG" ]; then
        ok "Honcho restored — server should be at http://localhost:8000"
        log "Verify: curl -s http://localhost:8000/health"
    else
        warn "Honcho config NOT in backup — will need full re-setup"
    fi
}

# ─── Restore Hermes Honcho cache ─────────────────────────────────────────────
restore_hermes_cache() {
    log "Restoring Hermes Honcho plugin cache..."
    if [ ! -d "$WORK_DIR/hermes-honcho-cache" ]; then
        warn "No Hermes cache in backup"
        return 0
    fi

    mkdir -p "$HONCHO_DIR"
    rsync -a "$WORK_DIR/hermes-honcho-cache/" "$HONCHO_DIR/" 2>/dev/null || \
    cp -r "$WORK_DIR/hermes-honcho-cache/." "$HONCHO_DIR/" 2>/dev/null || true

    local count=$(find "$HONCHO_DIR" -type f 2>/dev/null | wc -l)
    ok "Hermes cache restored: $count files"
}

# ─── Restore Graphify ────────────────────────────────────────────────────────
restore_graphify() {
    log "Restoring Graphify memory..."

    if [ ! -d "$WORK_DIR/graphify" ]; then
        warn "No Graphify backup found"
        return 0
    fi

    mkdir -p "$GRAPHIFY_DIR"
    # Use rsync to merge (don't delete what's there)
    rsync -a --delete "$WORK_DIR/graphify/" "$GRAPHIFY_DIR/" 2>/dev/null || \
    cp -r "$WORK_DIR/graphify/." "$GRAPHIFY_DIR/" 2>/dev/null || true

    local total=$(find "$GRAPHIFY_DIR" -type f 2>/dev/null | wc -l)
    local qa=$(find "$GRAPHIFY_DIR/memory/qa" -type f 2>/dev/null | wc -l)
    ok "Graphify restored: $total files ($qa Q&A results)"

    if [ "$total" -eq 0 ]; then
        warn "Graphify memory is empty — rebuild with:"
        warn "  graphify update /path/to/your/codebase"
    fi
}

# ─── Restore daily + weekly memory ───────────────────────────────────────────
restore_daily() {
    log "Restoring daily memory..."
    mkdir -p "$DAILY_DIR"

    if [ -d "$WORK_DIR/daily" ]; then
        # Merge (don't overwrite newer local files)
        rsync -a --update "$WORK_DIR/daily/" "$DAILY_DIR/" 2>/dev/null || true
        local count=$(find "$DAILY_DIR" -type f 2>/dev/null | wc -l)
        ok "Daily memory restored: $count files"
    else
        warn "No daily memory in backup"
    fi

    log "Restoring weekly memory..."
    mkdir -p "$WEEKLY_DIR"
    if [ -d "$WORK_DIR/weekly" ]; then
        rsync -a --update "$WORK_DIR/weekly/" "$WEEKLY_DIR/" 2>/dev/null || true
        local count=$(find "$WEEKLY_DIR" -type f 2>/dev/null | wc -l)
        ok "Weekly memory restored: $count files"
    else
        warn "No weekly memory in backup"
    fi
}

# ─── Re-apply memory system config ───────────────────────────────────────────
reapply_config() {
    log "Reapplying memory system configuration..."

    # Ensure memory dirs exist
    mkdir -p "$GRAPHIFY_DIR" "$HONCHO_DIR" "$DAILY_DIR" "$WEEKLY_DIR"

    # Re-install hooks if missing
    bash "$SCRIPT_DIR/run.sh" start 2>/dev/null || true

    ok "Config reapplied"
}

# ─── Post-restore verification ────────────────────────────────────────────────
post_restore_verify() {
    log "Post-restore verification..."

    # Honcho
    if [ -f "$HONCHO_CONFIG" ]; then
        ok "Honcho config: $HONCHO_CONFIG"
    else
        warn "Honcho config NOT restored — run 'hermes honcho setup'"
    fi

    # Graphify
    local gf_count=$(find "$GRAPHIFY_DIR" -type f 2>/dev/null | wc -l)
    if [ "$gf_count" -gt 0 ]; then
        ok "Graphify: $gf_count files restored"
    else
        warn "Graphify: empty (rebuild with graphify update)"
    fi

    # Daily
    local dm_count=$(find "$DAILY_DIR" -type f 2>/dev/null | wc -l)
    ok "Daily memory: $dm_count files"

    ok "Restore verification complete"
}

# ─── Main ───────────────────────────────────────────────────────────────────
main() {
    log "=== Hermes Memory Restore ==="
    log "Target: $TARGET"
    log "Source: $BACKUP_GIT"
    echo ""

    sync_backup

    case "$TARGET" in
        graphify)
            restore_graphify
            ;;
        honcho)
            restore_honcho
            restore_hermes_cache
            ;;
        daily)
            restore_daily
            ;;
        all)
            restore_honcho
            restore_hermes_cache
            restore_graphify
            restore_daily
            ;;
        *)
            echo "Usage: bash restore.sh [graphify|honcho|daily|all]"
            exit 1
            ;;
    esac

    reapply_config
    post_restore_verify

    echo ""
    ok "Restore complete: $TARGET"
    log ""
    if [ "$TARGET" = "honcho" ] || [ "$TARGET" = "all" ]; then
        log "Next: hermes honcho status"
    fi
    log "To backup: bash ~/.hermes/skills/hermes-memory-aatos/scripts/backup.sh"
}

main
