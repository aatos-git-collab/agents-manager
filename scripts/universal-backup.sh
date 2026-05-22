#!/bin/bash
# =====================================================================
# Universal Backup & Sync — Agent Install Manager
# =====================================================================
# Usage: bash universal-backup.sh [--agent=hermes] [--skip-install]
#
# Pre-install flow:
#   1. Snapshot current ~/.hermes → backups/{agent}/{timestamp}/
#   2. Pull remote customizations into source (skills, configs not in source)
#   3. Run install/update script
#   4. Print restore command + diff summary
#
# This makes /root/.agents-manager a universal backup-restore-install manager.
# Run it before ANY install/update across 10 agents — always safe.
# =====================================================================
set -euo pipefail

export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_INSTALLS_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_ROOT="$AGENT_INSTALLS_DIR/backups"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
LOG_FILE=""

# ── Defaults ─────────────────────────────────────────────────────────
AGENT="hermes"
SKIP_INSTALL=false
SKIP_SYNC=false
SKIP_BACKUP=false
TARGET_USER=""
AGENT_HOME="$HOME/.$AGENT"

# ── Argument parsing ─────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent=*)  AGENT="${1#*=}"; shift ;;
    --user=*)   TARGET_USER="${1#*=}"; shift ;;
    --skip-install) SKIP_INSTALL=true; shift ;;
    --skip-sync)    SKIP_SYNC=true; shift ;;
    --skip-backup)  SKIP_BACKUP=true; shift ;;
    --help)
      echo "Usage: $0 [--agent=hermes] [--user=<user>] [--skip-install] [--skip-sync] [--skip-backup]"
      echo ""
      echo "  --agent=hermes    Which agent (hermes|claude). Default: hermes"
      echo "  --user=<user>     Operate on this user's hermes install. Default: auto-detect"
      echo "  --skip-install    Backup + sync only, skip install script"
      echo "  --skip-sync       Skip pulling remote customizations into source"
      echo "  --skip-backup     Skip backup step (dangerous — use only if backup exists)"
      echo ""
      echo "Examples:"
      echo "  $0                          # Full backup + sync + install (hermes, current user)"
      echo "  $0 --agent=hermes           # Same, explicit"
      echo "  $0 --agent=claude           # Full flow for claude agent"
      echo "  $0 --skip-install           # Backup + sync only, no install"
      echo "  $0 --user=user              # Backup user's hermes instead of root's"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# ── Detect agent home ──────────────────────────────────────────────
detect_agent_home() {
  local agent="$1"
  if [ -n "$TARGET_USER" ]; then
    AGENT_HOME="/home/$TARGET_USER/.$agent"
  elif [ "$(id -u)" = "0" ] && [ -z "$TARGET_USER" ]; then
    # Running as root, no explicit user → /root/.claude or /root/.hermes
    AGENT_HOME="/root/.$agent"
  else
    AGENT_HOME="$HOME/.$agent"
  fi
}
detect_agent_home "$AGENT"

# ── Paths ───────────────────────────────────────────────────────────
AGENT_SOURCE_DIR="$AGENT_INSTALLS_DIR/skills/$AGENT"
AGENT_PRESETS_DIR="$AGENT_INSTALLS_DIR/presets/$AGENT"
BACKUP_DIR="$BACKUP_ROOT/$AGENT/$TIMESTAMP"
INSTALL_SCRIPT="$SCRIPT_DIR/${AGENT}-install.sh"

# ── Logging ─────────────────────────────────────────────────────────
log() { echo "[$(date +%H:%M:%S)] $*"; }
log_section() { echo ""; echo "=== $* ==="; }
log_item() { printf "  %-10s %s\n" "[$1]" "$2"; }

# ── Pre-flight checks ───────────────────────────────────────────────
check_prereqs() {
  if ! command -v rsync &>/dev/null; then
    log "Installing rsync..."
    apt-get install -y -qq rsync
  fi
  if [ ! -d "$AGENT_INSTALLS_DIR" ]; then
    echo "ERROR: Agent installs dir not found: $AGENT_INSTALLS_DIR"
    exit 1
  fi
  if [ ! -d "$AGENT_SOURCE_DIR" ]; then
    echo "ERROR: Source skills dir not found: $AGENT_SOURCE_DIR"
    exit 1
  fi
}

# =====================================================================
# STEP 1 — Detect existing installation
# =====================================================================
log_section "STEP 1/4  Detecting existing installation"
if [ -d "$AGENT_HOME" ] && [ -n "$(ls -A "$AGENT_HOME" 2>/dev/null)" ]; then
  log_item "INFO" "Found existing installation at $AGENT_HOME"
  EXISTING_AGENT=true
else
  log_item "INFO" "No existing installation at $AGENT_HOME — fresh install mode"
  EXISTING_AGENT=false
fi

# =====================================================================
# STEP 2 — Backup
# =====================================================================
log_section "STEP 2/4  Creating backup snapshot"

if [ "$SKIP_BACKUP" = true ]; then
  log_item "SKIP" "--skip-backup set — skipping"
elif [ "$EXISTING_AGENT" = false ]; then
  log_item "SKIP" "No existing installation — nothing to back up"
else
  log_item "INFO" "Backup location: $BACKUP_DIR"
  log_item "INFO" "Running rsync mirror..."

  mkdir -p "$BACKUP_DIR"

  # rsync with:
  # -a  : archive (preserve perms, times, etc.)
  # -   : delete in dest what's not in src (full mirror)
  # --exclude : skip volatile/unnecessary dirs
  # Trailing / on src = contents of src, not src itself
  if rsync -a --delete \
    --exclude='.cache/' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.git/' \
    --exclude='node_modules/' \
    --exclude='venv/' \
    --exclude='.venv/' \
    "$AGENT_HOME/" "$BACKUP_DIR/"; then

    LOG_FILE="$BACKUP_DIR/backup.log"
    {
      echo "Agent Home: $AGENT_HOME"
      echo "Agent: $AGENT"
      echo "Timestamp: $TIMESTAMP"
      echo "Existing Version: $(cat "$AGENT_HOME/.install_state" 2>/dev/null || echo 'unknown')"
      echo ""
      echo "--- Backup contents ---"
      find "$BACKUP_DIR" -type f | sed "s|$BACKUP_DIR/||" | sort
    } > "$LOG_FILE"

    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    FILE_COUNT=$(find "$BACKUP_DIR" -type f | wc -l)
    log_item "DONE" "Backup complete — $FILE_COUNT files — $BACKUP_SIZE"
  else
    log_item "ERROR" "rsync failed — backup may be incomplete"
    exit 1
  fi
fi

# =====================================================================
# STEP 3 — Sync remote customizations into source
# =====================================================================
log_section "STEP 3/4  Pulling remote customizations into source"

if [ "$SKIP_SYNC" = true ]; then
  log_item "SKIP" "--skip-sync set — skipping remote sync"
elif [ "$EXISTING_AGENT" = false ]; then
  log_item "SKIP" "No existing installation — nothing to sync"
else
  mkdir -p "$AGENT_SOURCE_DIR"
  mkdir -p "$AGENT_PRESETS_DIR"

  SYNCED_SKILLS=()
  SYNCED_CONFIGS=()

  # 3a. Pull skills NOT in source
  log_item "INFO" "Checking for custom skills in remote..."
  for remote_item in "$AGENT_HOME/skills"/*/; do
    [ -d "$remote_item" ] || continue
    skill_name=$(basename "$remote_item")
    [[ "$skill_name" == .* ]] && continue

    src_skill="$AGENT_SOURCE_DIR/$skill_name"
    if [ -d "$src_skill" ]; then
      # Skill exists in source — check if remote has extra files not in source
      remote_only=$(find "$remote_item" -type f ! -path "$remote_item" -printf "%f\n" 2>/dev/null || true)
      if [ -n "$remote_only" ]; then
        log_item "PATCH" "Skill $skill_name has remote-only files — syncing into source"
        rsync -a --delete "$remote_item/" "$src_skill/" 2>/dev/null || true
        SYNCED_SKILLS+=("$skill_name")
      fi
    else
      # Skill doesn't exist in source — pull entire thing
      log_item "PULL" "New skill from remote: $skill_name"
      mkdir -p "$src_skill"
      rsync -a "$remote_item/" "$src_skill/"
      SYNCED_SKILLS+=("$skill_name")
    fi
  done

  if [ ${#SYNCED_SKILLS[@]} -eq 0 ]; then
    log_item "OK" "No new custom skills found — source is current"
  else
    log_item "SYNCED" "${#SYNCED_SKILLS[@]} skill(s) pulled: ${SYNCED_SKILLS[*]}"
  fi

  # 3b. Pull custom config files NOT in presets
  log_item "INFO" "Checking for custom configs in remote..."
  for remote_file in "$AGENT_HOME"/*.yaml "$AGENT_HOME"/*.json "$AGENT_HOME"/.*; do
    [ -f "$remote_file" ] || continue
    fname=$(basename "$remote_file")
    # Skip standard files that install script manages
    [[ "$fname" =~ ^(config\.yaml|auth\.json|\.env|\.install_state|\.bashrc|\.profile)$ ]] && continue

    src_file="$AGENT_PRESETS_DIR/$fname"
    if [ ! -f "$src_file" ]; then
      log_item "PULL" "Custom config: $fname → presets/"
      cp -p "$remote_file" "$src_file"
      SYNCED_CONFIGS+=("$fname")
    fi
  done

  if [ ${#SYNCED_CONFIGS[@]} -eq 0 ]; then
    log_item "OK" "No new custom configs found"
  else
    log_item "SYNCED" "${#SYNCED_CONFIGS[@]} config(s) pulled: ${SYNCED_CONFIGS[*]}"
  fi
fi

# =====================================================================
# STEP 4 — Run install/update script
# =====================================================================
log_section "STEP 4/4  Running install/update"

if [ "$SKIP_INSTALL" = true ]; then
  log_item "SKIP" "--skip-install set — install script not run"
else
  if [ ! -f "$INSTALL_SCRIPT" ]; then
    log_item "ERROR" "Install script not found: $INSTALL_SCRIPT"
    exit 1
  fi
  log_item "INFO" "Running $INSTALL_SCRIPT..."

  # Pass through AGENT_HOME if non-default
  if [ "$AGENT_HOME" != "$HOME/.hermes" ]; then
    export AGENT_HOME
    log_item "INFO" "AGENT_HOME=$AGENT_HOME"
  fi

  if bash "$INSTALL_SCRIPT"; then
    log_item "DONE" "Install script exit 0"
  else
    exit_code=$?
    log_item "WARN" "Install script exited with code $exit_code — backup preserved"
  fi
fi

# =====================================================================
# Report
# =====================================================================
log_section "FINAL REPORT"
echo ""
echo "  Agent:       $AGENT"
echo "  Agent home: $AGENT_HOME"
echo "  Timestamp:   $TIMESTAMP"
echo ""

if [ "$SKIP_BACKUP" = false ] && [ "$EXISTING_AGENT" = true ]; then
  echo "  === Restore anytime with: ==="
  echo ""
  echo "  rsync -av --delete $BACKUP_DIR/ $AGENT_HOME/"
  echo ""
fi

if [ ${#SYNCED_SKILLS[@]} -gt 0 ]; then
  echo "  Custom skills pulled into source:"
  for s in "${SYNCED_SKILLS[@]}"; do echo "    + $s"; done
fi

if [ ${#SYNCED_CONFIGS[@]} -gt 0 ]; then
  echo "  Custom configs pulled into presets:"
  for c in "${SYNCED_CONFIGS[@]}"; do echo "    + $c"; done
fi

if [ "$SKIP_INSTALL" = false ]; then
  echo ""
  echo "  === After install, message Mattermost: ==="
  echo '  "Run a post-install health check on the agent config at '"$AGENT_HOME"'"'
fi

echo ""
echo "  Backup dir: $BACKUP_DIR"
echo ""
log "Complete."
