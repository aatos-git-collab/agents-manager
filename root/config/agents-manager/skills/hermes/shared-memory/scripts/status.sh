#!/bin/bash
# shared-memory status — check all shared resources
set -euo pipefail

echo "=== Shared Memory Status ==="
echo ""

# Graphify CLI
echo "Graphify CLI:"
if command -v graphify &>/dev/null; then
    echo "  CLI: $(which graphify)"
else
    echo "  CLI: NOT FOUND"
fi
echo ""

# Graph data
echo "Graph data (/root/pawnshop/graphify-out/):"
if [ -f /root/pawnshop/graphify-out/graph.json ]; then
    nodes=$(python3 -c "import json; print(len(json.load(open('/root/pawnshop/graphify-out/graph.json')).get('nodes', [])))" 2>/dev/null || echo "?")
    edges=$(python3 -c "import json; print(len(json.load(open('/root/pawnshop/graphify-out/graph.json')).get('links', [])))" 2>/dev/null || echo "?")
    size=$(du -sh /root/pawnshop/graphify-out/ | cut -f1)
    echo "  graph.json: $nodes nodes, $edges edges ($size)"
else
    echo "  graph.json: NOT FOUND"
fi

# Symlinks
echo ""
echo "Graphify symlinks:"
for f in graph.json GRAPH_REPORT.md graph.html cache; do
    link=~/.hermes/memory/graphify/$f
    if [ -L "$link" ]; then
        target=$(readlink "$link")
        if [ -e "$link" ]; then
            echo "  $f → $target ✓"
        else
            echo "  $f → $target ⚠ BROKEN"
        fi
    else
        echo "  $f: not linked"
    fi
done

# Git hooks
echo ""
echo "Git hooks (auto-rebuild):"
for hook in post-commit post-checkout; do
    if [ -f /root/.git/hooks/$hook ] && grep -q "graphify" /root/.git/hooks/$hook 2>/dev/null; then
        echo "  $hook: installed ✓"
    else
        echo "  $hook: not installed"
    fi
done

# PreToolUse hook
echo ""
echo "Claude Code PreToolUse hook:"
if python3 -c "import json; d=json.load(open('/root/.claude/settings.json')); hooks=d.get('hooks',{}).get('PreToolUse',[]); print('yes' if any('graphify' in str(h) for h in hooks) else 'no')" 2>/dev/null | grep -q yes; then
    echo "  PreToolUse: registered ✓"
else
    echo "  PreToolUse: NOT registered"
fi

# Honcho server
echo ""
echo "Honcho server:"
if curl -sf http://localhost:8000/health &>/dev/null; then
    echo "  API: healthy ✓"
else
    echo "  API: DOWN"
fi
if docker ps --format '{{.Names}}' | grep -q "honcho-api-1"; then
    echo "  Container: running ✓"
else
    echo "  Container: not running"
fi
if [ -f ~/.honcho/config.json ]; then
    echo "  Config: present ✓"
else
    echo "  Config: missing"
fi

# Backup
echo ""
echo "Backup:"
if [ -d ~/.hermes/memory-backup.git ]; then
    last_commit=$(git -C ~/.hermes/memory-backup.git log -1 --oneline master 2>/dev/null || git -C ~/.hermes/memory-backup.git log -1 --oneline 2>/dev/null || echo "none")
    echo "  Repo: present ($last_commit)"
else
    echo "  Repo: missing"
fi

# Watchdog cron
echo ""
echo "Watchdog:"
if crontab -l 2>/dev/null | grep -q "hermes-memory"; then
    echo "  Cron: scheduled ✓"
else
    echo "  Cron: not scheduled"
fi
last_run=$(tail -5 ~/.hermes/memory/watchdog.log 2>/dev/null | grep "Watchdog run complete" | tail -1 | awk '{print $4, $5, $6, $7}' || echo "unknown")
echo "  Last run: $last_run"

echo ""
echo "Done."
