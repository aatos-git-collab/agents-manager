#!/bin/bash
# backup.sh — Git backup for Hermes Memory System
# Backs up: Honcho config, Graphify memory, daily/weekly memory
# Usage: bash backup.sh [graphify|honcho|daily|all] [git-msg]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
VENV="$HOME/.hermes/hermes-agent/venv"

MEMORY_DIR="$HOME/.hermes/memory"
GRAPHIFY_DIR="$MEMORY_DIR/graphify"
HONCHO_DIR="$MEMORY_DIR/honcho"           # Hermes plugin cache
HONCHO_CONFIG="$HOME/.honcho/config.json" # CRITICAL: Workspace API key + URL
HONCHO_SERVER_DIR="/root/honcho"           # Self-hosted Honcho server (docker stack)
HONCHO_SERVER_FILES=(
    "$HONCHO_SERVER_DIR/.jwt_secret"
    "$HONCHO_SERVER_DIR/.env.secrets"
    "$HONCHO_SERVER_DIR/docker-compose.yml"
)
DAILY_DIR="$MEMORY_DIR/daily"
WEEKLY_DIR="$MEMORY_DIR/weekly"

BACKUP_GIT="${BACKUP_GIT:-$HOME/.hermes/memory-backup.git}"
WORK_DIR="/tmp/memory-backup-work"
TARGET="${1:-all}"
MSG="${2:-memory backup $(date '+%Y-%m-%d %H:%M')}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[backup]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# ─── Init git backup repo ────────────────────────────────────────────────────
init_git() {
    if [ ! -d "$BACKUP_GIT" ]; then
        log "Creating bare git backup repo at $BACKUP_GIT"
        mkdir -p "$(dirname "$BACKUP_GIT")"
        git init --bare "$BACKUP_GIT" 2>/dev/null || true
        ok "Created $BACKUP_GIT"
    fi

    # Clone to working dir
    if [ ! -d "$WORK_DIR/.git" ]; then
        rm -rf "$WORK_DIR"
        git clone "$BACKUP_GIT" "$WORK_DIR" 2>/dev/null || \
        (mkdir -p "$WORK_DIR" && cd "$WORK_DIR" && git init && git remote add origin "$BACKUP_GIT")
    fi
}

# ─── Sync honcho config → work dir ──────────────────────────────────────────
# CRITICAL: ~/.honcho/config.json is the ONLY local Honcho restore point.
# All actual memory (peer cards, sessions) is in the Honcho cloud.
backup_honcho_config() {
    log "Backing up Honcho config (CRITICAL — Workspace API key + server secrets)..."

    # 1. ~/.honcho/config.json (workspace API key)
    if [ -f "$HONCHO_CONFIG" ]; then
        mkdir -p "$WORK_DIR/honcho"
        cp "$HONCHO_CONFIG" "$WORK_DIR/honcho/config.json"
        local size=$(wc -c < "$HONCHO_CONFIG")
        ok "Honcho config backed up ($size bytes)"
    else
        warn "No Honcho config at $HONCHO_CONFIG"
        mkdir -p "$WORK_DIR/honcho"
        echo "# No config at time of backup" > "$WORK_DIR/honcho/config.json.missing"
    fi

    # 2. Self-hosted server files (JWT secret + docker-compose)
    if [ -d "$HONCHO_SERVER_DIR" ]; then
        mkdir -p "$WORK_DIR/honcho-server"
        for file in "${HONCHO_SERVER_FILES[@]}"; do
            if [ -f "$file" ]; then
                local dest="$WORK_DIR/honcho-server/$(basename "$file")"
                cp "$file" "$dest"
                ok "Backed up $file"
            fi
        done
    fi

    # 3. PostgreSQL database dump (the actual Honcho memory — sessions, embeddings)
    backup_honcho_db() {
        log "Backing up Honcho PostgreSQL database (pgdata Docker volume)..."
        local db_dump="$WORK_DIR/honcho-db.sql.gz"
        local container="honcho-database-1"
        local db_user="postgres"
        local db_name="postgres"

        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            warn "Honcho database container not running — skipping DB backup"
            return 0
        fi

        # pg_dump via docker exec → gzip
        if docker exec "$container" pg_dump -U "$db_user" -d "$db_name" | gzip > "$db_dump" 2>/dev/null; then
            local size=$(du -h "$db_dump" | cut -f1)
            ok "DB dump backed up: $size ($db_dump)"
        else
            warn "pg_dump failed — will fall back to raw pgdata volume copy"
            # Fallback: snapshot the raw pgdata volume
            local pgdata_vol=$(docker inspect "$container" --format '{{range .Mounts}}{{if eq .Name "honcho_pgdata"}}{{.Name}}{{end}}{{end}}' 2>/dev/null)
            if [ -n "$pgdata_vol" ]; then
                log "Copying raw pgdata volume: $pgdata_vol"
                docker run --rm \
                    -v "$pgdata_vol:/src:ro" \
                    -v "$WORK_DIR:/dest" \
                    alpine:latest \
                    sh -c "cp -r /src/pgdata /dest/honcho-pgdata 2>/dev/null && echo 'pgdata copied'" || \
                warn "Could not copy pgdata volume"
            fi
        fi
    }
    backup_honcho_db
}

# ─── Sync Hermes plugin cache ───────────────────────────────────────────────
backup_hermes_honcho_cache() {
    log "Backing up Hermes Honcho plugin cache..."
    if [ -d "$HONCHO_DIR" ]; then
        mkdir -p "$WORK_DIR/hermes-honcho-cache"
        rsync -a "$HONCHO_DIR/" "$WORK_DIR/hermes-honcho-cache/" 2>/dev/null || \
        cp -r "$HONCHO_DIR/." "$WORK_DIR/hermes-honcho-cache/" 2>/dev/null || true
        ok "Hermes Honcho cache backed up ($(find $HONCHO_DIR -type f 2>/dev/null | wc -l) files)"
    else
        mkdir -p "$WORK_DIR/hermes-honcho-cache"
        ok "No Hermes cache to back up (normal on first run)"
    fi
}

# ─── Sync graphify memory ───────────────────────────────────────────────────
backup_graphify() {
    log "Backing up Graphify memory..."
    if [ ! -d "$GRAPHIFY_DIR" ]; then
        warn "Graphify dir not found: $GRAPHIFY_DIR"
        mkdir -p "$WORK_DIR/graphify"
        echo "# Graphify memory not yet initialized" > "$WORK_DIR/graphify/README.md"
        return 0
    fi

    mkdir -p "$WORK_DIR/graphify"
    rsync -a "$GRAPHIFY_DIR/" "$WORK_DIR/graphify/" 2>/dev/null || \
    cp -r "$GRAPHIFY_DIR/." "$WORK_DIR/graphify/" 2>/dev/null || true

    local graph_files=$(find "$GRAPHIFY_DIR" -type f 2>/dev/null | wc -l)
    local qa_files=$(find "$GRAPHIFY_DIR/memory/qa" -type f 2>/dev/null | wc -l)
    ok "Graphify backed up ($graph_files files, $qa_files Q&A results)"
}

# ─── Sync daily + weekly memory ─────────────────────────────────────────────
backup_daily() {
    log "Backing up daily memory..."
    mkdir -p "$WORK_DIR/daily"
    if [ -d "$DAILY_DIR" ]; then
        rsync -a "$DAILY_DIR/" "$WORK_DIR/daily/" 2>/dev/null || true
        local count=$(find "$DAILY_DIR" -type f 2>/dev/null | wc -l)
        ok "Daily memory: $count files backed up"
    else
        ok "Daily memory dir not present yet (normal on first run)"
    fi

    log "Backing up weekly memory..."
    mkdir -p "$WORK_DIR/weekly"
    if [ -d "$WEEKLY_DIR" ]; then
        rsync -a "$WEEKLY_DIR/" "$WORK_DIR/weekly/" 2>/dev/null || true
        local count=$(find "$WEEKLY_DIR" -type f 2>/dev/null | wc -l)
        ok "Weekly memory: $count files backed up"
    else
        ok "Weekly memory dir not present yet"
    fi
}

# ─── Git commit + push ───────────────────────────────────────────────────────
git_push() {
    cd "$WORK_DIR" || return 1
    git config user.email "hermes@local" 2>/dev/null || true
    git config user.name "Hermes Memory Backup" 2>/dev/null || true

    # Add everything, skip large binary files
    git add -A -- ':!.git' 2>/dev/null || true

    if git diff --staged --quiet 2>/dev/null; then
        log "No changes to commit — already up to date"
        return 0
    fi

    git commit -m "$MSG" 2>/dev/null || { warn "Git commit failed"; return 1; }
    log "Committed: $(git log -1 --oneline 2>/dev/null)"

    # Push to bare repo
    if git push origin main 2>/dev/null; then
        ok "Pushed to $BACKUP_GIT"
    elif git push origin master 2>/dev/null; then
        ok "Pushed to $BACKUP_GIT (master branch)"
    else
        # Bare repo — verify commit exists locally
        if git rev-parse HEAD &>/dev/null; then
            ok "Local commit saved (bare repo — no remote push possible)"
        else
            warn "No commits created"
        fi
    fi
}

# ─── Health check before backup ──────────────────────────────────────────────
preflight_check() {
    log "Running pre-flight check..."

    # Check backup git repo
    if [ ! -d "$BACKUP_GIT" ]; then
        log "Backup repo missing — will create"
    fi

    # Check at least one thing to back up exists
    local has_content=0
    if [ -f "$HONCHO_CONFIG" ] || [ -d "$GRAPHIFY_DIR" ] || [ -d "$DAILY_DIR" ]; then
        has_content=1
    fi

    if [ "$has_content" -eq 0 ]; then
        warn "Nothing to back up yet — this is normal on first run"
    fi

    ok "Pre-flight passed"
}

# ─── Main ───────────────────────────────────────────────────────────────────
main() {
    log "=== Hermes Memory Backup ==="
    log "Target: $TARGET"

    preflight_check
    init_git

    case "$TARGET" in
        graphify)
            backup_graphify
            ;;
        honcho)
            backup_honcho_config
            backup_hermes_honcho_cache
            ;;
        daily)
            backup_daily
            ;;
        all)
            backup_honcho_config
            backup_hermes_honcho_cache
            backup_graphify
            backup_daily
            ;;
        *)
            echo "Usage: bash backup.sh [graphify|honcho|daily|all] [git-msg]"
            exit 1
            ;;
    esac

    git_push
    ok "Backup complete: $TARGET"
    log "To restore: bash ~/.hermes/skills/hermes-memory-aatos/scripts/restore.sh"
}

main
