#!/bin/bash
# config-backup-restore: Diff check — shows what differs between current and backup

set -euo pipefail

BACKUP_CLONE="/tmp/agents-backup-restore"

echo "=== CONFIG DIFF (current vs backup) ==="
diff "$HOME/.hermes/config.yaml" "$BACKUP_CLONE/config.yaml" 2>/dev/null \
    && echo "(no diff)" || true

echo ""
echo "=== SKILLS DIFF ==="
for skill in "$BACKUP_CLONE/skills"/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    [ "$name" = "config-backup-restore" ] && continue
    if [ ! -d "$HOME/.hermes/skills/$name" ]; then
        echo "MISSING: skills/$name"
    fi
done
for skill in "$HOME/.hermes/skills"/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    if [ ! -d "$BACKUP_CLONE/skills/$name" ]; then
        echo "EXTRA (not in backup): skills/$name"
    fi
done

echo ""
echo "=== FILE PRESENCE ==="
for f in SOUL.md USER.md USER-HABITS.md; do
    if [ -f "$HOME/.hermes/$f" ]; then
        echo "OK: $f"
    else
        echo "MISSING: $f"
    fi
done

echo ""
echo "=== CEO AGENT ==="
if [ -d "$HOME/.hermes/hermes-agent/agent/ceo" ]; then
    echo "OK: CEO agent exists"
else
    echo "MISSING: CEO agent"
fi

echo ""
echo "=== GIT HOOK ==="
if [ -f "$HOME/.git-hooks/pre-push" ]; then
    echo "OK: git push safety installed"
else
    echo "MISSING: git push safety hook"
fi
