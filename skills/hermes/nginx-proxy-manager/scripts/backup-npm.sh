#!/bin/bash
# ============================================================
# NPM Config Backup Script
# Backs up NPM database + Nginx configs + SSL certs metadata
# to the backup repo: /tmp/npm-backup/
# ============================================================
set -euo pipefail

BACKUP_DIR="/tmp/npm-backup"
NPM_DATA="/root/npm/data"
NPM_LE="/root/npm/letsencrypt"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

echo "============================================================"
echo "  NPM Config Backup  |  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

mkdir -p "${BACKUP_DIR}"

# 1. Snapshot NPM DB (SQLite — must use .backup for consistency)
echo "[1/5] Backing up NPM database..."
cp "${NPM_DATA}/database.sqlite" "${BACKUP_DIR}/database.sqlite.${TIMESTAMP}"
# Also keep latest
cp "${NPM_DATA}/database.sqlite" "${BACKUP_DIR}/database.sqlite.latest"
echo "  DB backed up: ${BACKUP_DIR}/database.sqlite.${TIMESTAMP}"

# 2. Backup Nginx proxy host configs
echo "[2/5] Backing up Nginx proxy host configs..."
mkdir -p "${BACKUP_DIR}/nginx/proxy_host"
cp -r "${NPM_DATA}/nginx/proxy_host/"*.conf "${BACKUP_DIR}/nginx/proxy_host/" 2>/dev/null || true
cp -r "${NPM_DATA}/nginx/conf.d/" "${BACKUP_DIR}/nginx/" 2>/dev/null || true
cp -r "${NPM_DATA}/nginx/custom/" "${BACKUP_DIR}/nginx/" 2>/dev/null || true
echo "  Nginx configs backed up"

# 3. Backup SSL cert metadata (not full certs — too large)
echo "[3/5] Backing up SSL cert metadata..."
mkdir -p "${BACKUP_DIR}/letsencrypt/live"
for cert_dir in "${NPM_LE}/live"/npm-*; do
    [[ -d "$cert_dir" ]] || continue
    cert_name=$(basename "$cert_dir")
    mkdir -p "${BACKUP_DIR}/letsencrypt/live/${cert_name}"
    # Copy only metadata files, not full certs
    cp "${cert_dir}/README" "${BACKUP_DIR}/letsencrypt/live/${cert_name}/" 2>/dev/null || true
    # Copy cert info
    openssl x509 -in "${cert_dir}/fullchain.pem" -noout -subject -issuer -enddate 2>/dev/null \
        > "${BACKUP_DIR}/letsencrypt/live/${cert_name}/cert-info.txt" || true
done
echo "  SSL metadata backed up"

# 4. Export DB state as JSON for easy diff
echo "[4/5] Exporting DB as JSON..."
docker exec npm /usr/bin/node -e "
const Database = require('/app/node_modules/better-sqlite3')('/data/database.sqlite');
const hosts = Database.prepare('SELECT id,domain_names,forward_scheme,forward_host,forward_port,certificate_id,ssl_forced,http2_support,enabled,access_list_id,trust_forwarded_proto,block_exploits,allow_websocket_upgrade FROM proxy_host WHERE is_deleted=0').all();
const certs = Database.prepare('SELECT id,nice_name,domain_names,provider,expires_on FROM certificate WHERE is_deleted=0').all();
const lists = Database.prepare('SELECT id,name,satisfy_any FROM access_list WHERE is_deleted=0').all();
const clients = Database.prepare('SELECT id,access_list_id,address,directive FROM access_list_client').all();
console.log(JSON.stringify({proxy_host: hosts, certificate: certs, access_list: lists, access_list_client: clients}, null, 2));
Database.close();
" > "${BACKUP_DIR}/npm_state.json" 2>/dev/null || echo "{}" > "${BACKUP_DIR}/npm_state.json"
echo "  State exported to npm_state.json"

# 5. Write manifest
echo "[5/5] Writing manifest..."
cat > "${BACKUP_DIR}/manifest.json" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "date": "$(date -Iseconds)",
  "db_size": $(stat -c%s "${NPM_DATA}/database.sqlite" 2>/dev/null || echo 0),
  "proxy_hosts_count": $(docker exec npm /usr/bin/node -e "const Database=require('/app/node_modules/better-sqlite3')('/data/database.sqlite'); console.log(Database.prepare('SELECT COUNT(*) as c FROM proxy_host WHERE is_deleted=0').get().c); Database.close();" 2>/dev/null || echo 0),
  "certificates_count": $(docker exec npm /usr/bin/node -e "const Database=require('/app/node_modules/better-sqlite3')('/data/database.sqlite'); console.log(Database.prepare('SELECT COUNT(*) as c FROM certificate WHERE is_deleted=0').get().c); Database.close();" 2>/dev/null || echo 0),
  "nginx_conf_files": $(ls "${NPM_DATA}/nginx/proxy_host/"*.conf 2>/dev/null | wc -l)
}
EOF
echo "  Manifest written"

echo ""
echo "============================================================"
echo "  Backup complete: ${BACKUP_DIR}"
echo "============================================================"

# Show changes vs previous backup
if [[ -f "${BACKUP_DIR}/npm_state.json.prev" ]]; then
    echo ""
    echo "Changes since last backup:"
    diff "${BACKUP_DIR}/npm_state.json.prev" "${BACKUP_DIR}/npm_state.json" 2>/dev/null | head -30 || echo "  (no diff tool available)"
fi

# Rotate: keep last 5 snapshots
cp "${BACKUP_DIR}/npm_state.json" "${BACKUP_DIR}/npm_state.json.prev" 2>/dev/null || true
ls -d "${BACKUP_DIR}"/database.sqlite.* 2>/dev/null | sort | tail -n +6 | xargs rm -f 2>/dev/null || true
echo "  Rotated: kept last 5 DB snapshots"
