#!/bin/bash
# =====================================================================
# extensions/install/_common.sh — Shared Install Utilities
# =====================================================================
# Common functions used by all install extension commands.

# =====================================================================
# Color output (from actions.sh)
# =====================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $1"; }

# =====================================================================
# Write install marker
# =====================================================================
write_install_marker() {
    local home="$1"
    echo "v0.14.0-$(date +%Y%m%d-%H%M%S)" > "$home/.install_state"
}
ensure_rsync() {
    if command -v rsync >/dev/null 2>&1; then
        return 0
    fi
    log_info "Installing rsync..."
    apt-get update -qq && apt-get install -y -qq rsync
}

# =====================================================================
# Load env from various sources (preference order)
# =====================================================================
load_env() {
    # Priority: /config/.hermes/.env > global .env > env vars
    if [ -f "/config/.hermes/.env" ]; then
        set -a
        source "/config/.hermes/.env"
        set +a
    elif [ -f "$GLOBAL_BASE/.env" ]; then
        set -a
        source "$GLOBAL_BASE/.env"
        set +a
    fi
}

# =====================================================================
# Export key environment variables for subshells
# =====================================================================
export_env_for_agents() {
    load_env

    export MINIMAX_ANTHROPIC_BASE_URL
    export MINIMAX_API_KEY
    export LLM_MODEL
    export HERMES_TUI_THEME
    export HERMES_TUI_LIGHT
}

# =====================================================================
# Sync to global base (excluding secrets)
# =====================================================================
sync_to_global() {
    local src_dir="$1"
    local dest_dir="$GLOBAL_BASE"

    ensure_rsync

    mkdir -p "$(dirname "$dest_dir")"

    if [ -d "$dest_dir" ]; then
        # Exclude .env and other secrets
        rsync -a --delete \
            --exclude='.env' \
            --exclude='.env.*' \
            --exclude='*.key' \
            --exclude='*.token' \
            --exclude='*.secrets' \
            "$src_dir/" "$dest_dir/"
    else
        cp -r "$src_dir" "$dest_dir"
    fi

    # Ensure scripts are executable
    find "$dest_dir" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    chmod -R a+rwX "$dest_dir"
}

# =====================================================================
# Create global launchers
# =====================================================================
create_launchers() {
    local launcher_dir="/usr/local/bin"

    # agents-manager launcher
    cat > "$launcher_dir/agents-manager" << 'EOF'
#!/bin/bash
# agents-manager launcher — auto-detects root vs user mode
set -e
GLOBAL_DIR="/usr/local/share/agents-manager"
if [ "$(id -u)" = "0" ]; then
    exec bash "$GLOBAL_DIR/actions.sh" install global "$@"
else
    exec bash "$GLOBAL_DIR/actions.sh" install user "$@"
fi
EOF
    chmod +x "$launcher_dir/agents-manager"

    # hermes-install launcher
    cat > "$launcher_dir/hermes-install" << 'EOF'
#!/bin/bash
set -e
GLOBAL_DIR="/usr/local/share/agents-manager"
exec bash "$GLOBAL_DIR/actions.sh" install hermes --user "$@"
EOF
    chmod +x "$launcher_dir/hermes-install"

    # claude-install launcher
    cat > "$launcher_dir/claude-install" << 'EOF'
#!/bin/bash
set -e
GLOBAL_DIR="/usr/local/share/agents-manager"
exec bash "$GLOBAL_DIR/actions.sh" install claude "$@"
EOF
    chmod +x "$launcher_dir/claude-install"

    # actions launcher
    cat > "$launcher_dir/actions" << 'EOF'
#!/bin/bash
exec bash /usr/local/share/agents-manager/actions.sh "$@"
EOF
    chmod +x "$launcher_dir/actions"

    log_ok "Launchers created in $launcher_dir"
}

# =====================================================================
# Get workspace .env source (prefers /config/.hermes/.env)
# =====================================================================
get_env_source() {
    if [ -f "/config/.hermes/.env" ]; then
        echo "/config/.hermes/.env"
    elif [ -f "$GLOBAL_BASE/.env" ]; then
        echo "$GLOBAL_BASE/.env"
    fi
}

# =====================================================================
# Detect container environment
# =====================================================================
is_container() {
    [ -f /.dockerenv ] || [ ! -d /proc/1 ] || ! mountpoint -q /proc 2>/dev/null
}

# =====================================================================
# Copy file if different (with backup)
# =====================================================================
copy_if_different() {
    local src="$1"
    local dst="$2"
    local label="${3:-file}"

    if [ ! -f "$src" ]; then
        log_error "  $label: SOURCE NOT FOUND ($src)"
        return 1
    fi

    if [ -f "$dst" ]; then
        if cmp -s "$src" "$dst" 2>/dev/null; then
            echo "  $label: unchanged"
            return 0
        fi
        cp -p "$dst" "${dst}.bak.$(date +%s)" 2>/dev/null || true
    fi

    cp -p "$src" "$dst"
    echo "  $label: copied"
    return 0
}

# =====================================================================
# Sub environment variables in a file
# =====================================================================
sub_env_vars() {
    local src="$1"
    local dst="$2"
    local label="${3:-sub}"

    if [ ! -f "$src" ]; then
        log_error "  $label: SOURCE NOT FOUND ($src)"
        return 1
    fi

    local tmp="/tmp/sub-$$.tmp"

    # Load env first
    load_env

    sed "s|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g;
        s|\${LLM_MODEL}|${LLM_MODEL:-MiniMax-M2.7}|g;
        s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY:-}|g" \
        "$src" > "$tmp"

    chmod 644 "$tmp"
    copy_if_different "$tmp" "$dst" "$label"
    rm -f "$tmp"
}

# =====================================================================
# Sync Hermes env from global .env.global to workspace .env
# =====================================================================
sync_hermes_env() {
    local hermes_home="$1"
    local env_path="$hermes_home/.env"

    mkdir -p "$hermes_home"
    touch "$env_path"

    local keys="MINIMAX_API_KEY ANTHROPIC_API_KEY HERMES_TUI_THEME HERMES_TUI_LIGHT MINIMAX_ANTHROPIC_BASE_URL"
    local tmp_env="/tmp/hermes-env-$$.tmp"

    for key in $keys; do
        local value=""
        # Try global env first
        if [ -f "$GLOBAL_BASE/presets/hermes/.env.global" ]; then
            value=$(grep -v '^#' "$GLOBAL_BASE/presets/hermes/.env.global" 2>/dev/null | grep "^${key}=" | head -1 | cut -d'=' -f2-)
        fi
        # Then from /config/.hermes/.env
        [ -z "$value" ] && value=$(grep -v '^#' "/config/.hermes/.env" 2>/dev/null | grep "^${key}=" | head -1 | cut -d'=' -f2-)
        # Fallback to current shell env
        [ -z "$value" ] && value=$(eval echo \$$key 2>/dev/null || echo "")

        if [ -n "$value" ]; then
            grep -v "^${key}=" "$env_path" > "$tmp_env" 2>/dev/null || true
            echo "${key}=${value}" >> "$tmp_env"
            mv "$tmp_env" "$env_path"
            log_info "  $key: synced"
        fi
    done
}

# =====================================================================
# Apply Mattermost configuration
# =====================================================================
apply_mattermost_config() {
    local hermes_home="$1"

    load_env

    local mm_url="${MATTERMOST_URL:-}"
    local mm_token="${MATTERMOST_TOKEN:-}"
    local mm_allowed="${MATTERMOST_ALLOWED_USERS:-}"
    local mm_reply="${MATTERMOST_REPLY_MODE:-off}"
    local mm_mention="${MATTERMOST_REQUIRE_MENTION:-true}"

    if [ -z "$mm_url" ] || [ -z "$mm_token" ]; then
        log_info "  Mattermost: not configured"
        return 0
    fi

    hermes config set mattermost.url "$mm_url" 2>/dev/null || true
    hermes config set mattermost.token "$mm_token" 2>/dev/null || true
    hermes config set mattermost.allowed_users "$mm_allowed" 2>/dev/null || true
    hermes config set mattermost.reply_mode "$mm_reply" 2>/dev/null || true
    hermes config set mattermost.require_mention "$mm_mention" 2>/dev/null || true
    log_info "  Mattermost: OK ($mm_url)"
}

# =====================================================================
# Install systemd gateway service
# =====================================================================
ensure_gateway_systemd() {
    local service_file="/etc/systemd/system/hermes-gateway.service"

    if [ ! -f "$service_file" ] || ! grep -q "hermes gateway run" "$service_file" 2>/dev/null; then
        cat > "$service_file" << 'EOF'
[Unit]
Description=Hermes Gateway
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="HOME=/root"
Environment="HERMES_HOME=/root/.hermes"
ExecStart=/root/.local/bin/hermes gateway run
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/root/.hermes

[Install]
WantedBy=multi-user.target
EOF
        log_ok "hermes-gateway.service installed"
    fi
}