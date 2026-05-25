#!/bin/bash
# heal.sh — Self-heal Hermes Memory System
# Run: bash heal.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[heal]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}  $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*" >&2; }

log "Self-healing Hermes Memory System..."

# Step 1: Full install
log "Step 1: Running full install..."
bash "$SCRIPT_DIR/run.sh" install || true

# Step 2: Apply config + hooks
log "Step 2: Applying config..."
bash "$SCRIPT_DIR/run.sh" start || true

# Step 3: Run verify
log "Step 3: Verifying..."
bash "$SCRIPT_DIR/run.sh" verify

# Step 4: Report status
log "Step 4: Status report..."
bash "$SCRIPT_DIR/run.sh" status

ok "Self-heal complete"
