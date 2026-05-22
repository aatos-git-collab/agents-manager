#!/bin/bash
# ============================================================
# NPM Config Restore Script
# Restores NPM state from /tmp/npm-backup/
# Usage: bash ~/.hermes/skills/nginx-proxy-manager/scripts/restore-npm.sh [--force]
# ============================================================
set -euo pipefail

BACKUP_DIR="/tmp/npm-backup"
FORCE="${1:-}"

if [[ "${FORCE}" != "--force" ]]; then
    echo "WARNING: This will overwrite current NPM configuration."
    echo "         Run with --force to proceed."
    echo ""
    echo "To preview changes first, run:"
    echo "  bash ~/.hermes/skills/nginx-proxy-manager/scripts/diff-npm.sh"
    exit 1
fi

echo "============================================================"
echo "  NPM Config Restore  |  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

# 1. Stop NPM container to prevent active writes
echo "[1/4] Stopping NPM container..."
docker stop npm 2>/dev/null && echo "  NPM stopped" || echo "  NPM already stopped"

# 2. Restore database
echo "[2/4] Restoring NPM database..."
if [[ -f "${BACKUP_DIR}/database.sqlite.latest" ]]; then
    cp "${BACKUP_DIR}/database.sqlite.latest" "/root/npm/data/database.sqlite"
    echo "  DB restored from latest backup"
else
    echo "  ERROR: No backup DB found at ${BACKUP_DIR}/database.sqlite.latest"
    exit 1
fi

# 3. Restore Nginx configs (optional — only if backed up)
echo "[3/4] Restoring Nginx configs..."
if [[ -d "${BACKUP_DIR}/nginx/proxy_host" ]]; then
    cp "${BACKUP_DIR}/nginx/proxy_host/"*.conf "/root/npm/data/nginx/proxy_host/" 2>/dev/null && echo "  Nginx proxy configs restored" || echo "  No Nginx configs to restore"
else
    echo "  No Nginx configs in backup"
fi

# 4. Restart NPM
echo "[4/4] Restarting NPM container..."
docker start npm 2>/dev/null && echo "  NPM started" || echo "  ERROR: Failed to start NPM"

# Verify
sleep 2
if docker exec npm nginx -t 2>&1 | grep -q "syntax is ok"; then
    echo ""
    echo -e "${GREEN}NPM restored successfully${NC}"
else
    echo ""
    echo -e "${RED}NPM config has errors after restore — manual intervention needed${NC}"
    docker start npm 2>/dev/null
    exit 1
fi
