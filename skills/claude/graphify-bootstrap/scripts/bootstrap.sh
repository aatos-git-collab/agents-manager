#!/bin/bash
# graphify-bootstrap — One-command graphify setup for any project
# Usage: bootstrap.sh /path/to/project
# Exit codes: 0=success, 1=usage, 2=graphify-install-failed, 3=graph-build-failed, 4=hooks-failed

set -e

PROJECT_ROOT="${1:-.}"

# Resolve absolute path
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
GRAPHIFY_OUT="$PROJECT_ROOT/graphify-out"

echo "[graphify-bootstrap] Setting up $PROJECT_NAME at $PROJECT_ROOT"

# 1. Verify graphify CLI
if ! command -v graphify &>/dev/null; then
    echo "[graphify-bootstrap] Installing graphify..."
    pip install -e /root/graphify 2>/dev/null || {
        echo "[ERROR] graphify install failed"
        exit 2
    }
fi

# 2. Create output dir
mkdir -p "$GRAPHIFY_OUT"

# 3. Build graph
echo "[graphify-bootstrap] Building graph (this may take a few minutes for large repos)..."
graphify update "$PROJECT_ROOT" --output graphify-out || {
    echo "[ERROR] graphify build failed"
    exit 3
}

# 4. Install git hooks
echo "[graphify-bootstrap] Installing git hooks..."
GIT_HOOK_DIR="$PROJECT_ROOT/.git/hooks"
mkdir -p "$GIT_HOOK_DIR"

cat > "$GIT_HOOK_DIR/post-commit" << 'HOOK'
#!/bin/bash
graphify update "$(git rev-parse --show-toplevel)" --output graphify-out
HOOK

cat > "$GIT_HOOK_DIR/post-checkout" << 'HOOK'
#!/bin/bash
if [ "$2" = "1" ]; then
  graphify update "$(git rev-parse --show-toplevel)" --output graphify-out
fi
HOOK

chmod +x "$GIT_HOOK_DIR/post-commit" "$GIT_HOOK_DIR/post-checkout"

# 5. Create/update CLAUDE.md
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
GRAPHIFY_SECTION="
## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run \`graphify update .\` to keep the graph current (AST-only, no API cost)
"

if [ -f "$CLAUDE_MD" ]; then
    if ! grep -q "graphify" "$CLAUDE_MD"; then
        echo "$GRAPHIFY_SECTION" >> "$CLAUDE_MD"
        echo "[graphify-bootstrap] Added graphify section to CLAUDE.md"
    else
        echo "[graphify-bootstrap] CLAUDE.md already has graphify section, skipping"
    fi
else
    echo "# $PROJECT_NAME" > "$CLAUDE_MD"
    echo "$GRAPHIFY_SECTION" >> "$CLAUDE_MD"
    echo "[graphify-bootstrap] Created CLAUDE.md with graphify section"
fi

# 6. Symlink to shared memory
SHARED_GRAPHIFY="$HOME/.hermes/memory/graphify/$PROJECT_NAME"
mkdir -p "$(dirname "$SHARED_GRAPHIFY")"
ln -sfn "$GRAPHIFY_OUT" "$SHARED_GRAPHIFY"
echo "[graphify-bootstrap] Symlinked to shared memory: $SHARED_GRAPHIFY"

# 7. Verify
if [ -f "$GRAPHIFY_OUT/graph.json" ]; then
    NODE_COUNT=$(python3 -c "import json; g=json.load(open('$GRAPHIFY_OUT/graph.json')); print(len(g.get('nodes',[])))" 2>/dev/null || echo "unknown")
    echo "[graphify-bootstrap] ✅ Done! Graph: $NODE_COUNT nodes at $GRAPHIFY_OUT"
else
    echo "[graphify-bootstrap] ⚠️  Graph built but graph.json not found — verify manually"
fi
