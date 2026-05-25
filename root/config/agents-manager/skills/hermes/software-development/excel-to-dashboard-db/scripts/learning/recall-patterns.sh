#!/bin/bash
# Recall learned patterns for Excel→Dashboard tasks

PATTERN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/memory/patterns/excel-dashboard"

mkdir -p "$PATTERN_DIR"

QUERY="${1:-}"

if [ ! -d "$PATTERN_DIR" ]; then
    echo "📊 No patterns learned yet."
    echo ""
    echo "First, complete some tasks and run:"
    echo "   ./scripts/learning/learn-from-session.sh"
    echo ""
    echo "Usage:"
    echo "   ./recall-patterns.sh 'excel import'"
    echo "   ./recall-patterns.sh 'dashboard export'"
    exit 0
fi

echo "📚 Recalling Excel→Dashboard patterns..."
echo ""

if [ -z "$QUERY" ]; then
    echo "Available pattern files:"
    ls -la "$PATTERN_DIR"/*.txt 2>/dev/null | awk '{print $NF}' | while read f; do
        echo "  - $(basename "$f" .txt)"
    done
    echo ""
    echo "Usage: ./recall-patterns.sh '<query>'"
    echo "Example: ./recall-patterns.sh 'column naming'"
    exit 0
fi

echo "🔍 Searching for: $QUERY"
echo ""
echo "=================================="

# Search through pattern files
FOUND=0
for pattern_file in "$PATTERN_DIR"/*.txt; do
    if [ -f "$pattern_file" ]; then
        if grep -qi "$QUERY" "$pattern_file"; then
            FOUND=1
            echo ""
            echo "📄 $(basename "$pattern_file"):"
            echo "----------------------------------"
            grep -A2 -i "$QUERY" "$pattern_file" | head -20
            echo ""
        fi
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "No patterns found for: $QUERY"
    echo ""
    echo "💡 Tip: Try broader terms like:"
    echo "   - 'excel'"
    echo "   - 'dashboard'"
    echo "   - 'import'"
fi

echo ""
echo "=================================="
