#!/bin/bash
#===============================================
# install-claude-global.sh
# Install Claude Code globally to /opt/claude
# Idempotent - safe to run multiple times
#===============================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

CLAUDE_SRC=""
CLAUDE_DST="/opt/claude/bin/claude"

#===============================================
# FIND CLAUDE SOURCE
#===============================================
find_claude_source() {
    # Priority: /opt/claude > /root/.local/share/claude > anywhere
    if [[ -f /opt/claude/bin/claude ]] && /opt/claude/bin/claude --version &>/dev/null; then
        CLAUDE_SRC="/opt/claude/bin/claude"
        return 0
    fi

    if [[ -f /root/.local/share/claude/versions/2.1.87 ]]; then
        CLAUDE_SRC="/root/.local/share/claude/versions/2.1.87"
        return 0
    fi

    if [[ -f /root/.local/bin/claude ]]; then
        local real_path=$(readlink -f /root/.local/bin/claude 2>/dev/null || echo "")
        if [[ -n "$real_path" && -f "$real_path" ]]; then
            CLAUDE_SRC="$real_path"
            return 0
        fi
    fi

    # Search for claude binary anywhere
    local found=$(find /root/.local -name "claude" -type f -executable 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
        CLAUDE_SRC="$found"
        return 0
    fi

    return 1
}

#===============================================
# MAIN
#===============================================
echo ""
info "Installing Claude Code globally to /opt/claude..."
echo ""

if find_claude_source; then
    info "Found Claude source: $CLAUDE_SRC"
else
    error "Claude Code not found. Install Claude Code first: curl -sS https://claude.ai/install.sh | sh"
fi

# Check if already installed correctly
if [[ -f "$CLAUDE_DST" ]] && cmp -s "$CLAUDE_SRC" "$CLAUDE_DST"; then
    info "Claude already installed at $CLAUDE_DST"
    /opt/claude/bin/claude --version
    echo ""
    exit 0
fi

# Install to /opt
mkdir -p /opt/claude/bin
cp "$CLAUDE_SRC" "$CLAUDE_DST"
chmod 755 "$CLAUDE_DST"

# Verify it works
if ! /opt/claude/bin/claude --version &>/dev/null; then
    error "Claude installed but fails to run. Check: mount | grep noexec"
fi

info "Claude installed successfully to $CLAUDE_DST"
/opt/claude/bin/claude --version

# Also symlink to /usr/local/bin so it's in everyone's PATH
if [ ! -f /usr/local/bin/claude ]; then
    ln -sf /opt/claude/bin/claude /usr/local/bin/claude
    info "Symlinked to /usr/local/bin/claude (everyone's PATH)"
fi

echo ""
info "Now run setup-workspace.sh to create agent workspaces"
echo ""
