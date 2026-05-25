#!/bin/bash
# Learn from this session - extract patterns for Excel→Dashboard conversions

SESSION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/memory/sessions"
PATTERN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/memory/patterns/excel-dashboard"

mkdir -p "$PATTERN_DIR"

echo "📊 Learning from Excel→Dashboard session..."
echo ""

# Extract patterns from recent session logs
RECENT_SESSION=$(ls -t "$SESSION_DIR"/*.md 2>/dev/null | head -1)

if [ -z "$RECENT_SESSION" ]; then
    echo "No session logs found."
    echo ""
    echo "To use this script:"
    echo "1. Complete your Excel→Dashboard task"
    echo "2. Run this script to learn from what worked"
    exit 0
fi

echo "📄 Analyzing: $RECENT_SESSION"

# Extract patterns
PATTERNS_FILE="$PATTERN_DIR/session-$(date +%Y%m%d).txt"

cat > "$PATTERNS_FILE" << PATTERN_EOF
# Excel→Dashboard Learning Session
# Date: $(date)

## What Worked
- 
- 

## What Didn't Work
- 
- 

## Excel Patterns Observed
- Column naming: 
- Data types: 
- Transformations: 

## Dashboard Output Patterns
- Visualizations used: 
- Aggregations: 
- JSON structure: 

## User Preferences
- Export format: 
- Visualization style: 
- Summary depth: 

## Technical Notes
- pandas operations: 
- SQLite queries: 
- Performance tips: 

PATTERN_EOF

echo "✅ Pattern saved to: $PATTERNS_FILE"
echo ""
echo "📝 Edit this file to add your learnings:"
echo "   nano $PATTERNS_FILE"
echo ""
echo "💡 Tip: The more sessions you log, the smarter this skill becomes!"
