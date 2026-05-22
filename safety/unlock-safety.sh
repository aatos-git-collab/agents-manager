#!/bin/bash
# unlock-safety — removes immutable flag so human can edit safety config
# Usage: bash unlock-safety.sh
# After editing, run lock-safety.sh to re-lock.
set -euo pipefail

AGENTS_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAFETY_DIR="$AGENTS_HOME/safety"

echo "Unlocking safety config in $SAFETY_DIR..."
echo ""

for f in "$SAFETY_DIR"/*.txt; do
    [ -f "$f" ] || continue
    chattr -i "$f" 2>/dev/null || true
    chmod 644 "$f" 2>/dev/null || true
    echo "  Unlocked: $(basename "$f")"
done

echo ""
echo "You can now edit the files. When done, run:"
echo "  bash $SAFETY_DIR/lock-safety.sh"