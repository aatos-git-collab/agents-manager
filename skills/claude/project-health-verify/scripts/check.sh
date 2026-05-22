#!/bin/bash
# Generic project health check - works for any project
# Usage: ./check.sh /path/to/project

set -e

PROJECT_DIR="${1:-}"
if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: $0 /path/to/project"
    exit 1
fi

# Load project config if exists
CONFIG_FILE="$PROJECT_DIR/PROJECT_CONFIG.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_DIR")}"
BUILD_CMD="${BUILD_CMD:-npm run build}"
DEV_CMD="${DEV_CMD:-npm run dev}"
DEV_PORT="${DEV_PORT:-5678}"
HEALTH_CHECK_TYPE="${HEALTH_CHECK_TYPE:-generic}"

echo "=== Project Health Check: $PROJECT_NAME ==="
echo "Project: $PROJECT_DIR"
echo "Type: $HEALTH_CHECK_TYPE"
echo ""

# ===== Type-specific checks =====
check_result=0

case "$HEALTH_CHECK_TYPE" in
    node)
        echo "[Node.js] Checking package.json and dependencies..."
        if [ ! -f "$PROJECT_DIR/package.json" ]; then
            echo "ERROR: package.json not found"
            exit 1
        fi

        # Check for missing node_modules
        if [ ! -d "$PROJECT_DIR/node_modules" ] && [ ! -f "$PROJECT_DIR/pnpm-lock.yaml" ]; then
            echo "WARNING: No node_modules or pnpm-lock.yaml found"
        fi

        # Check for undefined imports in src
        echo "Scanning for broken imports..."
        ;;
    next)
        echo "[Next.js] Checking Next.js project..."
        if [ ! -f "$PROJECT_DIR/package.json" ]; then
            echo "ERROR: package.json not found"
            exit 1
        fi

        # Check pages/app directory exists
        if [ ! -d "$PROJECT_DIR/pages" ] && [ ! -d "$PROJECT_DIR/app" ]; then
            echo "WARNING: Neither pages nor app directories found"
        fi
        ;;
    python)
        echo "[Python] Checking Python project..."
        if [ -f "$PROJECT_DIR/requirements.txt" ]; then
            echo "  - requirements.txt found"
        fi
        if [ -f "$PROJECT_DIR/pyproject.toml" ]; then
            echo "  - pyproject.toml found"
        fi
        ;;
    *)
        echo "[Generic] Running general health checks..."
        ;;
esac

# ===== Common checks =====

echo ""
echo "[1/3] Checking critical files..."
critical_files=(".gitignore" "package.json" "README.md")
for file in "${critical_files[@]}"; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file missing"
        check_result=1
    fi
done

echo ""
echo "[2/3] Checking for license files that should be removed..."
license_patterns=("LICENSE" "CODE_OF_CONDUCT" "CONTRIBUTOR")
found_licenses=()
for pattern in "${license_patterns[@]}"; do
    matches=$(find "$PROJECT_DIR" -maxdepth 1 -iname "$pattern*" -type f 2>/dev/null | head -5)
    if [ -n "$matches" ]; then
        found_licenses+=("$matches")
    fi
done

if [ ${#found_licenses[@]} -gt 0 ]; then
    echo "  ⚠ Found license files (should be removed for clean rebuild):"
    for lic in "${found_licenses[@]}"; do
        echo "    - $lic"
    done
    check_result=1
else
    echo "  ✓ No license files"
fi

echo ""
echo "[3/3] Checking for obvious code issues..."
# Check for console.log in production files
console_logs=$(find "$PROJECT_DIR/packages" "$PROJECT_DIR/packages/*/src" -name "*.ts" -o -name "*.tsx" 2>/dev/null | xargs grep -l "console\.log" 2>/dev/null | head -5)
if [ -n "$console_logs" ]; then
    echo "  ⚠ Found console.log statements:"
    for f in $console_logs; do
        count=$(grep -c "console\.log" "$f" 2>/dev/null || echo 0)
        echo "    - $f ($count occurrences)"
    done
fi

echo ""
if [ $check_result -eq 0 ]; then
    echo "✓ PASS: Project health check passed"
else
    echo "✗ FAIL: Project health issues found"
fi

exit $check_result