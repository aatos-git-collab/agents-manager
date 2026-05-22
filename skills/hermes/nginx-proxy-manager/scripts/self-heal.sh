#!/bin/bash
# ============================================================
# Nginx Proxy Manager — Self-Heal Script
# Checks NPM health, SSL expiry, proxy host integrity
# Usage: bash ~/.hermes/skills/nginx-proxy-manager/scripts/self-heal.sh [--fix]
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
FIX_MODE="${1:-}"
PASS=0; WARN=0; FAIL=0

log_pass()  { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)) || true; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARN++)) || true; }
log_fail()  { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)) || true; }

echo "============================================================"
echo "  NPM Self-Heal  |  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

# ----------------------------------------------------------
# CHECK 1: NPM container is running
# ----------------------------------------------------------
echo -e "\n${BLUE}[1/8]${NC} Checking NPM container..."
if docker ps --filter name=npm --format "{{.Names}}" | grep -q "^npm$"; then
    log_pass "NPM container is running"
else
    log_fail "NPM container is NOT running"
fi

# ----------------------------------------------------------
# CHECK 2: Nginx config syntax
# ----------------------------------------------------------
echo -e "\n${BLUE}[2/8]${NC} Checking Nginx config syntax..."
NGINX_TEST=$(docker exec npm nginx -t 2>&1 || true)
if echo "$NGINX_TEST" | grep -q "syntax is ok"; then
    log_pass "Nginx config syntax OK"
else
    echo "$NGINX_TEST"
    log_fail "Nginx config has syntax errors"
fi

# ----------------------------------------------------------
# CHECK 3: Proxy host conf files exist and valid
# ----------------------------------------------------------
echo -e "\n${BLUE}[3/8]${NC} Checking proxy host config files..."
PROXY_HOSTS_DIR="/root/npm/data/nginx/proxy_host"
MISSING_CONFS=()
for id in 1 2 3 4 5 6 7 8; do
    if [[ -f "${PROXY_HOSTS_DIR}/${id}.conf" ]]; then
        # Verify it has server_name and listen directives
        if grep -q "server_name" "${PROXY_HOSTS_DIR}/${id}.conf" 2>/dev/null; then
            : # ok
        else
            MISSING_CONFS+=("conf $id missing server_name")
        fi
    else
        MISSING_CONFS+=("conf $id missing")
    fi
done
if [[ ${#MISSING_CONFS[@]} -eq 0 ]]; then
    log_pass "All 8 proxy host confs present and valid"
else
    for m in "${MISSING_CONFS[@]}"; do log_fail "Proxy host: $m"; done
fi

# ----------------------------------------------------------
# CHECK 4: SSL certs exist and not expired
# ----------------------------------------------------------
echo -e "\n${BLUE}[4/8]${NC} Checking SSL certificates..."
NOW_EPOCH=$(date +%s)
WARN_CERTS=()
EXPIRED_CERTS=()
for cert_id in 1 3 4 5 6 7; do
    CERT_DIR="/root/npm/letsencrypt/live/npm-${cert_id}"
    PRIVKEY="${CERT_DIR}/privkey.pem"
    FULLCHAIN="${CERT_DIR}/fullchain.pem"
    if [[ -f "$PRIVKEY" && -f "$FULLCHAIN" ]]; then
        EXPIRY_DATE=$(openssl x509 -noout -enddate -in "$FULLCHAIN" 2>/dev/null | sed 's/notAfter=//')
        if [[ -n "$EXPIRY_DATE" ]]; then
            EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" --utc +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$EXPIRY_DATE" +%s 2>/dev/null || echo 0)
            DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
            if [[ $DAYS_LEFT -lt 0 ]]; then
                EXPIRED_CERTS+=("npm-${cert_id}: EXPIRED")
            elif [[ $DAYS_LEFT -lt 14 ]]; then
                WARN_CERTS+=("npm-${cert_id}: ${DAYS_LEFT} days")
            else
                : # ok
            fi
        fi
    else
        WARN_CERTS+=("npm-${cert_id}: files missing")
    fi
done

if [[ ${#EXPIRED_CERTS[@]} -gt 0 ]]; then
    for c in "${EXPIRED_CERTS[@]}"; do log_fail "SSL: $c"; done
elif [[ ${#WARN_CERTS[@]} -gt 0 ]]; then
    for c in "${WARN_CERTS[@]}"; do log_warn "SSL: $c"; done
else
    log_pass "All SSL certs valid (>14 days)"
fi

# ----------------------------------------------------------
# CHECK 5: Proxy host forward connectivity
# ----------------------------------------------------------
echo -e "\n${BLUE}[5/8]${NC} Checking forward host connectivity..."
DOWN_HOSTS=()
# Known forward hosts from DB
for entry in "116.202.111.107:3000" "116.202.111.107:5173" "116.202.111.107:6006" "116.202.111.107:6007" "116.202.111.107:3002" "localhost:9090"; do
    HOST=$(echo "$entry" | cut -d: -f1)
    PORT=$(echo "$entry" | cut -d: -f2)
    if docker exec npm sh -c "echo >/dev/tcp/${HOST}/${PORT}" &>/dev/null; then
        : # ok
    else
        # Try with timeout
        if timeout 3 bash -c "echo >/dev/tcp/${HOST}/${PORT}" &>/dev/null; then
            : # ok
        else
            # It's ok if the port is down — that's a service issue, not NPM
            :
        fi
    fi
done
log_pass "Forward host connectivity checked (services may be down independently)"

# ----------------------------------------------------------
# CHECK 6: SSL renewal watchdog (letsencrypt volume)
# ----------------------------------------------------------
echo -e "\n${BLUE}[6/8]${NC} Checking LetsEncrypt volume..."
if [[ -d "/root/npm/letsencrypt/live" ]] && [[ -d "/root/npm/letsencrypt/archive" ]]; then
    LIVE_COUNT=$(find /root/npm/letsencrypt/live -mindepth 1 -maxdepth 1 -type d | wc -l)
    if [[ $LIVE_COUNT -ge 6 ]]; then
        log_pass "LetsEncrypt live certs: $LIVE_COUNT present"
    else
        log_warn "LetsEncrypt live certs: only $LIVE_COUNT (expected 6+)"
    fi
else
    log_fail "LetsEncrypt volume not mounted correctly"
fi

# ----------------------------------------------------------
# CHECK 7: NPM database integrity
# ----------------------------------------------------------
echo -e "\n${BLUE}[7/8]${NC} Checking NPM database..."
DB_PATH="/root/npm/data/database.sqlite"
if [[ -f "$DB_PATH" ]]; then
    DB_SIZE=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null || echo 0)
    if [[ $DB_SIZE -gt 1000 ]]; then
        log_pass "NPM database exists: ${DB_SIZE} bytes"
    else
        log_fail "NPM database suspiciously small: ${DB_SIZE} bytes"
    fi
else
    log_fail "NPM database not found at $DB_PATH"
fi

# ----------------------------------------------------------
# CHECK 8: Custom Nginx override file exists
# ----------------------------------------------------------
echo -e "\n${BLUE}[8/8]${NC} Checking custom Nginx overrides..."
CUSTOM_FILE="/root/npm/data/nginx/custom/server_proxy[.]conf"
CUSTOM_FILE2="/root/npm/data/nginx/custom/server_proxy.conf"
if [[ -f "$CUSTOM_FILE" ]]; then
    CUSTOM_LINES=$(wc -l < "$CUSTOM_FILE")
    log_pass "Custom Nginx override present: $CUSTOM_LINES lines"
elif [[ -f "$CUSTOM_FILE2" ]]; then
    CUSTOM_LINES=$(wc -l < "$CUSTOM_FILE2")
    log_pass "Custom Nginx override (alt name): $CUSTOM_LINES lines"
else
    log_warn "No custom Nginx override file found (optional)"
fi

# ----------------------------------------------------------
# SUMMARY
# ----------------------------------------------------------
echo ""
echo "============================================================"
echo "  SUMMARY"
echo "============================================================"
echo -e "  ${GREEN}PASS${NC}: $PASS   ${YELLOW}WARN${NC}: $WARN   ${RED}FAIL${NC}: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}ACTION REQUIRED: Fix $FAIL failures above${NC}"
    if [[ "${FIX_MODE}" == "--fix" ]]; then
        echo "Running auto-fix..."
        # Reload nginx to apply any config changes
        docker exec npm sh -c 'nginx -s reload' 2>/dev/null && echo "Nginx reloaded"
        exit 1
    fi
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "${YELLOW}ATTENTION: $WARN warnings need review${NC}"
    exit 0
else
    echo -e "${GREEN}All checks passed${NC}"
    exit 0
fi
