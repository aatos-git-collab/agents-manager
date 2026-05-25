#!/bin/bash
# =====================================================================
# extensions/workspace/test.sh — Test a Workspace
# =====================================================================
# Usage: bash actions.sh workspace test <username>

set -euo pipefail

# Use SCRIPT_DIR from parent if passed (via actions.sh dispatch), otherwise calculate
if [ -n "${SCRIPT_DIR:-}" ]; then
    PROJECT_DIR="$SCRIPT_DIR"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
WORKSPACE_BASE="/workspaces"

source "${PROJECT_DIR}/extensions/workspace/_common.sh"

USERNAME="${1:-}"
[ -z "$USERNAME" ] && { echo "Usage: bash actions.sh workspace test <username>"; exit 1; }

ws_dir="$WORKSPACE_BASE/$USERNAME"

# Validate workspace exists
if [ ! -d "$ws_dir" ]; then
    log_error "Workspace does not exist: $ws_dir"
    exit 1
fi

log_info "Testing workspace: $ws_dir"
echo ""

errors=0

# Check ownership
owner=$(get_workspace_owner "$ws_dir")
expected="$USERNAME:$USERNAME"
if [ "$owner" = "$expected" ]; then
    log_ok "Ownership: $owner"
else
    log_error "Ownership: $owner (expected $expected)"
    ((errors++))
fi

# Check directories
for dir in projects skills memories sessions tasks logs; do
    if [ -d "$ws_dir/$dir" ]; then
        log_ok "Directory: $dir/"
    else
        log_error "Directory missing: $dir/"
        ((errors++))
    fi
done

# Check bind mount
if is_home_mounted "$USERNAME"; then
    log_ok "Bind mount: /home/$USERNAME → $ws_dir"
else
    log_warn "Bind mount: /home/$USERNAME (not mounted, may be symlink)"
fi

# Check hermes
hermes_home="$ws_dir/.hermes"
if [ -f "$hermes_home/.install_state" ]; then
    log_ok "Hermes: installed ($(cat $hermes_home/.install_state))"
else
    log_warn "Hermes: not installed"
fi

# Check claude
claude_home="$ws_dir/.claude"
if [ -f "$claude_home/.install_state" ]; then
    log_ok "Claude: installed ($(cat $claude_home/.install_state))"
else
    log_warn "Claude: not installed"
fi

# Test write as root
test_file="$ws_dir/.write_test"
if touch "$test_file" 2>/dev/null; then
    rm "$test_file"
    log_ok "Write test: root can write in workspace"
else
    log_error "Write test: root cannot write in workspace"
    ((errors++))
fi

# Test user write
if su - "$USERNAME" -c "touch $ws_dir/.user_write_test" 2>/dev/null; then
    rm "$ws_dir/.user_write_test" 2>/dev/null
    log_ok "Write test: $USERNAME can write in workspace"
else
    log_error "Write test: $USERNAME cannot write in workspace"
    ((errors++))
fi

echo ""
if [ $errors -eq 0 ]; then
    log_ok "All tests passed!"
    exit 0
else
    log_error "$errors test(s) failed"
    exit 1
fi