#!/bin/bash
# ============================================================
# NPM Config Diff Script
# Compares current NPM state vs last backup
# ============================================================
set -euo pipefail

BACKUP_DIR="/tmp/npm-backup"

echo "============================================================"
echo "  NPM Config Diff  |  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

# Show current state
echo ""
echo "=== CURRENT PROXY HOSTS ==="
docker exec npm /usr/bin/node -e "
const Database = require('/app/node_modules/better-sqlite3')('/data/database.sqlite');
const hosts = Database.prepare('SELECT id,domain_names,forward_scheme,forward_host,forward_port,certificate_id,ssl_forced,http2_support,enabled FROM proxy_host WHERE is_deleted=0').all();
hosts.forEach(h => {
  const cert = h.certificate_id > 0 ? ' SSL['+h.certificate_id+']' : ' no-SSL';
  const en = h.enabled ? '' : ' DISABLED';
  console.log('  ['+h.id+'] '+JSON.parse(h.domain_names)[0]+' -> '+h.forward_host+':'+h.forward_port+cert+en);
});
Database.close();
" 2>/dev/null

echo ""
echo "=== BACKED UP STATE ==="
if [[ -f "${BACKUP_DIR}/npm_state.json" ]]; then
    python3 -c "
import json, sys
try:
    with open('${BACKUP_DIR}/npm_state.json') as f:
        data = json.load(f)
    for h in data.get('proxy_host', []):
        cert = ' SSL['+str(h['certificate_id'])+']' if h['certificate_id'] > 0 else ' no-SSL'
        en = '' if h['enabled'] else ' DISABLED'
        print('  ['+str(h['id'])+'] '+json.loads(h['domain_names'])[0]+' -> '+h['forward_host']+':'+str(h['forward_port'])+cert+en)
except: print('  (could not parse)')
" 2>/dev/null
else
    echo "  No backup found at ${BACKUP_DIR}/npm_state.json"
fi

echo ""
echo "=== SSL CERT STATUS ==="
NOW_EPOCH=$(date +%s)
for cert_id in 1 3 4 5 6 7; do
    CERT_DIR="/root/npm/letsencrypt/live/npm-${cert_id}"
    FULLCHAIN="${CERT_DIR}/fullchain.pem"
    if [[ -f "$FULLCHAIN" ]]; then
        EXPIRY_DATE=$(openssl x509 -noout -enddate -in "$FULLCHAIN" 2>/dev/null | cut -d= -f2)
        EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo 0)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
        printf "  npm-%d: %-20s  %s\n" "$cert_id" "$([ -d "$CERT_DIR" ] && ls "$CERT_DIR"/*.pem 2>/dev/null | head -1 | xargs -I{} openssl x509 -noout -subject -in {} 2>/dev/null | cut -d= -f2 || echo '?')" "($DAYS_LEFT days)"
    else
        echo "  npm-${cert_id}: MISSING"
    fi
done 2>/dev/null

echo ""
echo "=== MANIFEST ==="
cat "${BACKUP_DIR}/manifest.json" 2>/dev/null || echo "No manifest"

echo ""
echo "=== DB SIZE COMPARISON ==="
if [[ -f "${BACKUP_DIR}/database.sqlite.latest" ]]; then
    echo "  Backup DB size: $(stat -c%s "${BACKUP_DIR}/database.sqlite.latest" 2>/dev/null || echo '?') bytes"
fi
echo "  Current DB size: $(stat -c%s "/root/npm/data/database.sqlite" 2>/dev/null || echo '?') bytes"
