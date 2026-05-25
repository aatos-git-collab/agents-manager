#!/bin/bash
# CSS Health Check for risheng-pawnshop
# Scans globals.css for undefined CSS custom properties

PROJECT_DIR="/root/risheng-pawnshop"
GLOBALS_CSS="$PROJECT_DIR/css/globals.css"
COLORS_JS="$PROJECT_DIR/data/config/colors.js"

echo "=== Pawnshop CSS Health Check ==="
echo ""

# Check if files exist
if [ ! -f "$GLOBALS_CSS" ]; then
    echo "ERROR: $GLOBALS_CSS not found"
    exit 1
fi

if [ ! -f "$COLORS_JS" ]; then
    echo "ERROR: $COLORS_JS not found"
    exit 1
fi

# Use awk to do the full check in one pass
RESULT=$(awk '
BEGIN {
    # Local variables that are defined within specific rules (not global)
    # These are set inline in their respective CSS rules
    # Keys MUST include the -- prefix since var_refs uses full var name
    local_vars["--maximum-opacity"] = 1
    local_vars["--glass-color"] = 1
    local_vars["--fancy-x"] = 1
    local_vars["--fancy-y"] = 1
    local_vars["--hard-shadow"] = 1
    local_vars["--hard-shadow-left"] = 1
}

# Extract var() references
match($0, /var\(--[a-zA-Z0-9-]+\)/) {
    var = substr($0, RSTART+4, RLENGTH-5)
    var_refs[var] = 1
}

# Extract CSS variable definitions from :root block
/^  :root *\{/ {
    in_root = 1
}
in_root && match($0, /--[a-zA-Z0-9-]+:/) {
    var = substr($0, RSTART, RLENGTH-1)
    root_vars[var] = 1
}
/^  \}$/ && in_root {
    in_root = 0
}

# Extract CSS variable definitions from .dark block
/^  \.dark *\{/ {
    in_dark = 1
}
in_dark && match($0, /--[a-zA-Z0-9-]+:/) {
    var = substr($0, RSTART, RLENGTH-1)
    dark_vars[var] = 1
}
/^  \}$/ && in_dark {
    in_dark = 0
}

END {
    undefined_count = 0
    for (var in var_refs) {
        if (var in local_vars) continue
        if (var in root_vars) continue
        if (var in dark_vars) continue
        undefined[undefined_count++] = var
    }

    if (undefined_count == 0) {
        print "PASS"
        exit 0
    } else {
        print "FAIL"
        for (i = 0; i < undefined_count; i++) {
            print "UNDEF:" undefined[i]
        }
        exit 1
    }
}
' "$GLOBALS_CSS")

# Parse result
if echo "$RESULT" | head -1 | grep -q "^PASS"; then
    echo "✓ PASS: All CSS custom properties are properly defined"
    echo ""
    exit 0
else
    echo "✗ FAIL: Found undefined CSS custom property(ies)"
    echo ""
    echo "Undefined variables:"
    echo "$RESULT" | grep "^UNDEF:" | sed 's/^UNDEF://'
    echo ""
    echo "Run './scripts/fix.sh' to auto-fix, or add these to :root and .dark blocks"
    exit 1
fi
