#!/bin/bash
# lock-safety — makes safety config immutable (agent cannot modify)
# Usage: bash lock-safety.sh
# Run after editing allowlist or patterns.
set -euo pipefail

AGENTS_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAFETY_DIR="$AGENTS_HOME/safety"

echo "Locking safety config in $SAFETY_DIR..."
echo ""

for f in "$SAFETY_DIR"/*.txt; do
    [ -f "$f" ] || continue
    # chmod FIRST, then chattr (immutable prevents chmod)
    chmod 444 "$f" 2>/dev/null || true
    chattr +i "$f" 2>/dev/null || echo "  [WARN] chattr +i not supported on this FS"
    echo "  Locked: $(basename "$f")"
done

echo ""
echo "Safety config is locked. Agents can read but not modify."
echo "To edit: bash $SAFETY_DIR/unlock-safety.sh"