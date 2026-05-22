#!/bin/bash
# =====================================================================
# Hermes Install Script
# =====================================================================
# Usage: bash hermes-install.sh [--user] [--force-fresh]
#
#   --user         : user mode — uses global skills/presets from
#                    /usr/local/share/agents-manager, only creates
#                    own ~/.hermes/.env for private Mattermost keys.
#                    Skills are SHARED read+write across all users.
#   --force-fresh  : skip install detection, treat as fresh install
#
# Modes (auto-detected by user):
#   global (root)  : full install, sync skills to /root/.hermes/skills
#   user (non-root): use global skills directly, only ~/.hermes/.env is private
# =====================================================================
set -e

export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_BASE="/usr/local/share/agents-manager"
# When run from global install: use global base. When run from source: use script dir parent.
if [ -d "$GLOBAL_BASE/scripts" ]; then
    AGENT_INSTALLS_DIR="$GLOBAL_BASE"
else
    AGENT_INSTALLS_DIR="$(dirname "$SCRIPT_DIR")"
fi
PRESETS_DIR="$AGENT_INSTALLS_DIR/presets/hermes"
ENV_FILE="$AGENT_INSTALLS_DIR/.env"

# =====================================================================
# Arguments
# =====================================================================
FORCE_FRESH=false
IS_USER_MODE=false
for arg in "$@"; do
    case "$arg" in
        --force-fresh) FORCE_FRESH=true ;;
        --user) IS_USER_MODE=true ;;
    esac
done

# =====================================================================
# Detect container environment
# =====================================================================
IS_CONTAINER=false
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null || [ ! -d /proc/1 ]; then
    IS_CONTAINER=true
fi

# =====================================================================
# Load env
# =====================================================================
# --user mode: global template first, then per-user ~/.hermes/.env (override)
if [ "$IS_USER_MODE" = true ]; then
    GLOBAL_ENV="$GLOBAL_BASE/presets/hermes/.env.global"
    USER_ENV="$HOME/.hermes/.env"

    if [ -f "$GLOBAL_ENV" ]; then
        set -a
        source "$GLOBAL_ENV"
        set +a
        echo "Loaded global env from $GLOBAL_ENV"
    fi

    if [ -f "$USER_ENV" ]; then
        set -a
        source "$USER_ENV"
        set +a
        echo "Loaded user env from $USER_ENV"
    fi
elif [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
    echo "Loaded env from $ENV_FILE"
else
    echo "WARNING: $ENV_FILE not found, using existing environment variables"
fi

# =====================================================================
# Install state detection
# =====================================================================
HERMES_HOME="$HOME/.hermes"
INSTALL_MARKER="$HERMES_HOME/.install_state"
INSTALLED_VERSION=""
INSTALL_MODE="DETECTED_NEW"

if [ -f "$INSTALL_MARKER" ]; then
    INSTALLED_VERSION=$(cat "$INSTALL_MARKER" 2>/dev/null || echo "")
fi

if [ "$FORCE_FRESH" = true ]; then
    INSTALL_MODE="FORCE_FRESH"
    echo "Mode: FORCE_FRESH (--force-fresh set)"
elif [ -d "$HERMES_HOME" ] && [ -n "$INSTALLED_VERSION" ]; then
    INSTALL_MODE="DETECTED_EXISTING"
    echo "Mode: DETECTED_EXISTING (v$INSTALLED_VERSION installed)"
else
    echo "Mode: DETECTED_NEW (first install)"
fi

# =====================================================================
# Helpers
# =====================================================================
copy_if_different() {
    local src="$1"
    local dst="$2"
    local label="${3:-file}"

    if [ ! -f "$src" ]; then
        echo "  $label: SOURCE NOT FOUND ($src)"
        return 1
    fi

    if [ -f "$dst" ]; then
        if cmp -s "$src" "$dst" 2>/dev/null; then
            echo "  $label: unchanged — skipping"
            return 0
        fi
        echo "  $label: updating"
        cp -p "$dst" "${dst}.bak.$(date +%s)" 2>/dev/null || true
    else
        echo "  $label: new — copying"
    fi

    cp -p "$src" "$dst"
    echo "  $label: OK"
    return 0
}

env_sync() {
    local hermes_home="$1"
    local env_path="$hermes_home/.env"

    mkdir -p "$hermes_home"
    touch "$env_path"

    # In user mode, use global env; in root mode, use AGENTS_HOME/.env
    local keys="MINIMAX_API_KEY ANTHROPIC_API_KEY HERMES_TUI_THEME HERMES_TUI_LIGHT"
    local tmp_env="/tmp/hermes-env-$$.tmp"

    for key in $keys; do
        local value
        # Try global env first (works in user mode), then original env
        if [ "$IS_USER_MODE" = true ]; then
            value=$(grep "^${key}=" "$GLOBAL_BASE/presets/hermes/.env.global" 2>/dev/null | head -1 | cut -d'=' -f2-)
        fi
        [ -z "$value" ] && value=$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-)
        [ -z "$value" ] && value=$(eval echo \$$key 2>/dev/null || echo "")

        if [ -n "$value" ]; then
            grep -v "^${key}=" "$env_path" > "$tmp_env" 2>/dev/null || true
            echo "${key}=${value}" >> "$tmp_env"
            mv "$tmp_env" "$env_path"
            echo "  $key: synced"
        fi
    done
}

apply_mattermost_config() {
    local HERMES_HOME="$1"
    export HERMES_HOME

    local mm_url="${MATTERMOST_URL:-}"
    local mm_token="${MATTERMOST_TOKEN:-}"
    local mm_allowed="${MATTERMOST_ALLOWED_USERS:-}"
    local mm_reply="${MATTERMOST_REPLY_MODE:-off}"
    local mm_mention="${MATTERMOST_REQUIRE_MENTION:-true}"

    if [ -z "$mm_url" ] || [ -z "$mm_token" ]; then
        echo "  Mattermost: not configured — skip"
        return 0
    fi

    echo "  Applying Mattermost config..."
    hermes config set mattermost.url "$mm_url" 2>/dev/null || true
    hermes config set mattermost.token "$mm_token" 2>/dev/null || true
    hermes config set mattermost.allowed_users "$mm_allowed" 2>/dev/null || true
    hermes config set mattermost.reply_mode "$mm_reply" 2>/dev/null || true
    hermes config set mattermost.require_mention "$mm_mention" 2>/dev/null || true
    echo "  Mattermost: OK ($mm_url)"
}

sync_persona() {
    local src_file="$1"
    local dst_file="$2"
    local label="${3:-persona}"

    if [ ! -f "$src_file" ]; then
        echo "  $label: source not found — skip"
        return 0
    fi

    if [ -f "$dst_file" ] && cmp -s "$src_file" "$dst_file" 2>/dev/null; then
        echo "  $label: unchanged — skip"
        return 0
    fi

    [ -f "$dst_file" ] && cp -p "$dst_file" "${dst_file}.bak.$(date +%s)" 2>/dev/null || true
    cp -p "$src_file" "$dst_file"
    echo "  $label: synced"
}

install_gateway_systemd() {
    local service_file="/etc/systemd/system/hermes-gateway.service"
    if [ ! -f "$service_file" ] || ! grep -q "hermes gateway run" "$service_file" 2>/dev/null; then
        cat > "$service_file" << 'SVCEOF'
[Unit]
Description=Hermes Gateway - Messaging bridge (Mattermost/Slack/etc)
After=network.target
PartOf=hermes-agent.service

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="HOME=/root"
Environment="HERMES_HOME=/root/.hermes"
Environment="PATH=/usr/local/bin:/usr/bin:/bin:/root/.local/bin"
ExecStart=/root/.local/bin/hermes gateway run
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
TimeoutStopSec=210
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hermes-gateway
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/root/.hermes

[Install]
WantedBy=hermes-agent.service
SVCEOF
        echo "  hermes-gateway.service: installed"
    else
        echo "  hermes-gateway.service: already present — skip"
    fi
}

install_agent_manager() {
    if [ -z "${AGENTS_HOME:-}" ]; then
        AGENTS_HOME="$GLOBAL_BASE"
        export AGENTS_HOME
    fi

    local am_dir="$AGENTS_HOME/.monitor"
    local am_log="$am_dir/logs"
    local am_wd="$am_dir/watchdogs"

    mkdir -p "$am_log" "$am_wd"

    cat > "$am_wd/check_hermes.sh" << 'HERMESEOF'
#!/bin/bash
set -euo pipefail
LOG="/root/.agents-manager/.monitor/logs/hermes_watchdog.log"
NOW=$(date '+%Y-%m-%d %H:%M:%S')
SERVICE_STATUS=$(systemctl is-active hermes-gateway.service 2>/dev/null || echo "unknown")
GATEWAY_PID=$(systemctl show --property MainPID --value hermes-gateway.service 2>/dev/null || echo "0")

if [ "$SERVICE_STATUS" != "active" ] || [ -z "$GATEWAY_PID" ] || [ "$GATEWAY_PID" = "0" ]; then
    echo "[$NOW] CRITICAL: hermes-gateway.service status=$SERVICE_STATUS PID=$GATEWAY_PID" >> "$LOG"
    systemctl start hermes-gateway.service 2>/dev/null
    sleep 5
    NEW_STATUS=$(systemctl is-active hermes-gateway.service 2>/dev/null || echo "unknown")
    if [ "$NEW_STATUS" = "active" ]; then
        echo "[$NOW] RESTORED: hermes-gateway.service restarted by monitor" >> "$LOG"
        exit 1
    else
        echo "[$NOW] FAIL: Could not restore hermes-gateway.service" >> "$LOG"
        exit 2
    fi
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    https://mm.agent.nexeraa.io/api/v4/system/ping 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
    echo "[$NOW] WARN: Mattermost API returned HTTP $HTTP_CODE" >> "$LOG"
fi

echo "[$NOW] OK: hermes-gateway(PID=$GATEWAY_PID) + Mattermost(API=$HTTP_CODE)" >> "$LOG"
exit 0
HERMESEOF
    chmod +x "$am_wd/check_hermes.sh"

    cat > "$am_wd/check_nexeraa.sh" << 'NEXERAAEOF'
#!/bin/bash
set -euo pipefail
CONTAINER="nexeraa"
LOG="/root/.agents-manager/.monitor/logs/nexeraa_watchdog.log"
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
NEXERAAEOF
    chmod +x "$am_wd/check_nexeraa.sh"

    cat > "$am_dir/monitor.sh" << 'MONITOREOF'
#!/bin/bash
set -euo pipefail
LOG_DIR="/root/.agents-manager/.monitor/logs"
LOG="$LOG_DIR/cron.log"
NOW=$(date '+%Y-%m-%d %H:%M:%S')
WATCHDOG_DIR="/root/.agents-manager/.monitor/watchdogs"

echo "[$NOW] === Monitor Run ===" >> "$LOG"

run_watchdog() {
    local name="$1"
    local script="$WATCHDOG_DIR/check_$name.sh"
    if [ -x "$script" ]; then
        local result exitcode
        result=$("$script" 2>&1) && exitcode=0 || exitcode=$?
        echo "[$name] exit=$exitcode: $(echo "$result" | tail -1)" >> "$LOG"
        return $exitcode
    else
        echo "[$name] SKIP: not found or not executable" >> "$LOG"
        return 0
    fi
}

run_watchdog "nexeraa"
run_watchdog "hermes"
echo "[$NOW] === Done ===" >> "$LOG"
MONITOREOF
    chmod +x "$am_dir/monitor.sh"

    (
        crontab -l 2>/dev/null | grep -v "\.monitor\|agent-manager" || true
        echo "* * * * * /root/.agents-manager/.monitor/monitor.sh >> /root/.agents-manager/.monitor/logs/cron.log 2>&1"
    ) | crontab -
    echo "  .monitor: installed (cron @ */1 min)"

    local cs_src="/root/mission-control/scripts/cron-safety.sh"
    local cs_dst="$AGENTS_HOME/scripts/cron-safety.sh"
    if [ -f "$cs_src" ] && [ ! -f "$cs_dst" ]; then
        cp "$cs_src" "$cs_dst"
        chmod +x "$cs_dst"
        echo "  cron-safety: copied"
    fi

    local cs_cron="/etc/cron.d/agents-manager-cron-safety"
    if [ -f "$cs_dst" ] && [ ! -f "$cs_cron" ]; then
        echo "0 * * * * root bash $cs_dst >> /var/log/cron-safety.log 2>&1" > "$cs_cron"
        chmod 644 "$cs_cron"
        echo "  cron-safety: installed to $cs_cron"
    fi
}

install_safety_scripts() {
    local safety_src="$AGENTS_HOME/safety-scripts"
    local hooks_src="$AGENTS_HOME/git-hooks"
    local global_hooks="$HOME/.git-hooks-global"

    if [ ! -d "$safety_src" ] && [ ! -d "$hooks_src" ]; then
        echo "  safety-scripts: not present — skip"
        return 0
    fi

    if [ -d "$hooks_src" ]; then
        mkdir -p "$global_hooks"
        for hook in pre-push pre-commit post-init; do
            [ -f "$hooks_src/$hook" ] && {
                cp "$hooks_src/$hook" "$global_hooks/$hook"
                chmod +x "$global_hooks/$hook"
            }
        done
        git config --global core.hooksPath "$global_hooks" 2>/dev/null || true
        echo "  safety: git hooks installed"
    fi

    if [ -d "$safety_src" ]; then
        for f in "$safety_src"/*.sh; do
            [ -f "$f" ] && chmod +x "$f"
        done
    fi

    echo "  safety-scripts: installed"
}

ensure_gateway_running() {
    local HERMES_HOME="$1"
    local suffix="${2:-}"
    export HERMES_HOME

    if systemctl is-active hermes-gateway.service &>/dev/null; then
        echo "  Gateway$suffix: running via systemd — skip"
        return 0
    fi

    if [ "$IS_CONTAINER" = false ] && [ "$(id -u)" = "0" ]; then
        install_gateway_systemd
        install_agent_manager
        install_safety_scripts
        systemctl daemon-reload
        systemctl enable hermes-gateway.service 2>/dev/null || true
        systemctl start hermes-gateway.service
        sleep 3
        echo "  Gateway$suffix: started via systemd"
    else
        mkdir -p "$HERMES_HOME/logs"
        if ! pgrep -f "hermes.*gateway.*run" > /dev/null 2>&1; then
            nohup hermes gateway run > "$HERMES_HOME/logs/gateway.log" 2>&1 &
            sleep 2
            echo "  Gateway$suffix: started manually (container/non-root)"
        else
            echo "  Gateway$suffix: already running — skip"
        fi
    fi
}

write_install_marker() {
    local hermes_home="$1"
    echo "v0.14.0-$(date +%Y%m%d-%H%M%S)" > "$hermes_home/.install_state"
    echo "  Install marker written"
}

# =====================================================================
# System packages
# =====================================================================
echo ""
echo ">>> Installing system packages..."
apt-get update -qq && apt-get install -y -qq sqlite3 xz-utils curl git rsync

# =====================================================================
# User account setup (skip in container, skip in user mode)
# =====================================================================
if [ "$IS_CONTAINER" = false ] && [ "$IS_USER_MODE" = false ]; then
    echo ""
    echo ">>> Setting up user account..."
    if ! id "user" &>/dev/null; then
        useradd -m -s /bin/bash user
        echo "  user account created"
    else
        echo "  user account exists — skip"
    fi
    echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
    chmod 440 /etc/sudoers.d/user
fi

# In user mode, skip system packages (already installed globally)
if [ "$IS_USER_MODE" = true ]; then
    echo ""
    echo ">>> Skipping system packages (running in user mode)..."
else
    echo ""
    echo ">>> Installing system packages..."
    apt-get update -qq && apt-get install -y -qq sqlite3 xz-utils curl git rsync
fi

# =====================================================================
# Install Hermes CLI
# =====================================================================
echo ""
echo ">>> Hermes CLI..."
mkdir -p "$HERMES_HOME/memories" "$HERMES_HOME/sessions" "$HERMES_HOME/tasks" "$HERMES_HOME/skills" "$HERMES_HOME/logs"

if ! command -v hermes >/dev/null 2>&1; then
    echo "  Installing Hermes binary..."
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
else
    echo "  Hermes CLI already installed — skip binary install"
    if [ "$INSTALL_MODE" = "DETECTED_EXISTING" ]; then
        echo "  Checking for Hermes updates..."
        hermes version 2>/dev/null | grep -q "Up to date" && echo "  Hermes: up to date" || {
            echo "  Hermes update available — reinstalling..."
            curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
        }
    fi
fi

echo "  Configuring model..."
hermes config set model.provider anthropic 2>/dev/null || true
hermes config set model.default MiniMax-M2.7 2>/dev/null || true
hermes config set model.base_url "${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}" 2>/dev/null || true
hermes config set model.api_key "${MINIMAX_API_KEY:-}" 2>/dev/null || true
hermes config set gateway.host 127.0.0.1 2>/dev/null || true
hermes config set gateway.port 18789 2>/dev/null || true

env_sync "$HERMES_HOME"

if [ -f "$PRESETS_DIR/config.yaml" ]; then
    echo "  Syncing config.yaml..."
    local_tmp="/tmp/hermes-root-config-$$.yaml"
    sed "s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY:-}|g" "$PRESETS_DIR/config.yaml" > "$local_tmp"
    copy_if_different "$local_tmp" "$HERMES_HOME/config.yaml" "config.yaml"
    rm -f "$local_tmp"
fi

[ -f "$PRESETS_DIR/auth.json" ] && copy_if_different "$PRESETS_DIR/auth.json" "$HERMES_HOME/auth.json" "auth.json"

apply_mattermost_config "$HERMES_HOME"
ensure_gateway_running "$HERMES_HOME"
write_install_marker "$HERMES_HOME"

# =====================================================================
# User workspace install (skip in container, skip in user mode)
# =====================================================================
if [ "$IS_CONTAINER" = false ] && [ "$IS_USER_MODE" = false ]; then
    echo ""
    echo ">>> Hermes (user)..."

    su - user -c "mkdir -p ~/.hermes/memories ~/.hermes/sessions ~/.hermes/tasks ~/.hermes/skills ~/.hermes/logs"

    if ! su - user -c "command -v hermes" >/dev/null 2>&1; then
        echo "  Installing Hermes CLI for user..."
        su - user -c "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
    else
        echo "  Hermes CLI already installed for user — skip"
    fi

    su - user -c 'export HERMES_HOME=~/.hermes
    hermes config set model.provider anthropic 2>/dev/null || true
    hermes config set model.default MiniMax-M2.7 2>/dev/null || true
    hermes config set model.base_url "'"${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}"'" 2>/dev/null || true
    hermes config set model.api_key "'"${MINIMAX_API_KEY:-}"'" 2>/dev/null || true
    hermes config set gateway.host 127.0.0.1 2>/dev/null || true
    hermes config set gateway.port 18789 2>/dev/null || true'

    su - user -c "HERMES_HOME=~/.hermes; $(declare -f env_sync); env_sync \"\$HERMES_HOME\""

    if [ -f "$PRESETS_DIR/config.yaml" ]; then
        local_tmp="/tmp/hermes-user-config-$$.yaml"
        sed "s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY:-}|g" "$PRESETS_DIR/config.yaml" > "$local_tmp"
        chmod 644 "$local_tmp"
        su - user -c "HERMES_HOME=~/.hermes; \
            if [ -f '$local_tmp' ] && [ -f \"\$HERMES_HOME/config.yaml\" ] && \
               cmp -s '$local_tmp' \"\$HERMES_HOME/config.yaml\" 2>/dev/null; then \
                echo '  config.yaml: unchanged — skip'; \
            else cp -p '$local_tmp' \"\$HERMES_HOME/config.yaml\"; echo '  config.yaml: synced'; fi"
        rm -f "$local_tmp"
    fi

    if [ -f "$PRESETS_DIR/auth.json" ]; then
        tmp_auth="/tmp/hermes-auth-$$.json"
        cp -p "$PRESETS_DIR/auth.json" "$tmp_auth"
        chmod 644 "$tmp_auth"
        su - user -c "HERMES_HOME=~/.hermes; \
            if cmp -s '$tmp_auth' \"\$HERMES_HOME/auth.json\" 2>/dev/null; then \
                echo '  auth.json: unchanged — skip'; \
            else cp -p '$tmp_auth' \"\$HERMES_HOME/auth.json\"; echo '  auth.json: synced'; fi"
        rm -f "$tmp_auth"
    fi

    su - user -c "HERMES_HOME=~/.hermes; export HERMES_HOME; \
        $(declare -f apply_mattermost_config); apply_mattermost_config \"\$HERMES_HOME\""

    su - user -c "HERMES_HOME=~/.hermes; export HERMES_HOME; \
        $(declare -f ensure_gateway_running); ensure_gateway_running \"\$HERMES_HOME\" \"-user\""

    su - user -c "echo 'v0.14.0-$(date +%Y%m%d-%H%M%S)' > ~/.hermes/.install_state"
fi

# =====================================================================
# Skills — shared across all users
# In --user mode: skills live at GLOBAL_BASE/skills (read+write for all)
# No per-user copies (bind mounts replace this in production)
# =====================================================================
echo ""
echo ">>> Skills (shared at $GLOBAL_BASE/skills)..."

HERMES_SKILLS_SRC="$AGENT_INSTALLS_DIR/skills/hermes"
HERMES_SKILLS_DST_ROOT="$HOME/.hermes/skills"

mkdir -p "$HERMES_SKILLS_DST_ROOT"

if [ "$IS_USER_MODE" = true ]; then
    # User mode: skills are shared globally — just ensure perms allow write
    chmod -R a+rwX "$GLOBAL_BASE/skills" 2>/dev/null || true

    # Symlink user skills to global (optional — agents can also use HERMES_SKILLS_GLOBAL)
    for skill_dir in "$HERMES_SKILLS_SRC"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        [[ "$skill_name" == .* ]] && continue

        # In user mode, we link to global directly
        user_skill_dir="$HERMES_SKILLS_DST_ROOT/$skill_name"
        if [ ! -L "$user_skill_dir" ] && [ ! -d "$user_skill_dir" ]; then
            ln -sf "$GLOBAL_BASE/skills/hermes/$skill_name" "$user_skill_dir" 2>/dev/null || \
                cp -r "$skill_dir" "$user_skill_dir"
            echo "  skill: $skill_name — linked to global"
        fi
    done
else
    # Root/global mode: rsync to /root/.hermes/skills
    if [ -d "$HERMES_SKILLS_SRC" ]; then
        for skill_dir in "$HERMES_SKILLS_SRC"/*/; do
            [ -d "$skill_dir" ] || continue
            skill_name=$(basename "$skill_dir")
            [[ "$skill_name" == .* ]] && continue

            dst_item="$HERMES_SKILLS_DST_ROOT/$skill_name"
            if [ -d "$dst_item" ]; then
                rsync -a --delete "$skill_dir/" "$dst_item/" 2>/dev/null && \
                    echo "  skill: $skill_name — synced" || \
                    echo "  skill: $skill_name — update failed"
            else
                cp -r "$skill_dir" "$dst_item"
                echo "  skill: $skill_name — NEW"
            fi
        done
    fi
fi

# =====================================================================
# Sync persona files
# =====================================================================
echo ""
echo ">>> Syncing persona files..."

HERMES_ROOT_USER="/home/user/.hermes"
PERSONA_FILES="USER.md USER_HABITS.md SOUL.md"

for persona in $PERSONA_FILES; do
    [ -f "$PRESETS_DIR/$persona" ] || continue
    sync_persona "$PRESETS_DIR/$persona" "$HERMES_HOME/$persona" "$persona (root)"
    [ "$IS_CONTAINER" = false ] && \
        sync_persona "$PRESETS_DIR/$persona" "$HERMES_ROOT_USER/$persona" "$persona (user)"
done

# =====================================================================
# Final status
# =====================================================================
echo ""
echo "========================================"
echo "Hermes Install/Update Complete"
echo "========================================"
echo "Mode:       $INSTALL_MODE"
echo "Hermes:     $HERMES_HOME"
echo "Installed:  $(cat $HERMES_HOME/.install_state 2>/dev/null || echo 'unknown')"
echo ""
if systemctl is-active hermes-gateway.service &>/dev/null; then
    echo "Gateway:    RUNNING (systemd)"
elif pgrep -f "hermes gateway" > /dev/null 2>&1; then
    echo "Gateway:    RUNNING (manual)"
else
    echo "Gateway:    NOT RUNNING"
fi
echo "Mattermost: $(hermes config get mattermost.url 2>/dev/null || echo 'not configured')"
echo ""
echo "Quick commands:"
echo "  hermes status        — check full status"
echo "  hermes gateway run  — start gateway"
echo "  hermes config get    — view config"
echo "========================================"