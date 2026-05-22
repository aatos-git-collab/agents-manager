#!/bin/bash
# Learn from feedback - improve based on user corrections

PATTERN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/memory/patterns/excel-dashboard"

mkdir -p "$PATTERN_DIR"

FEEDBACK_TYPE="${1:-}"
FEEDBACK_FIX="${2:-}"

if [ -z "$FEEDBACK_TYPE" ] || [ -z "$FEEDBACK_FIX" ]; then
    echo "Learn from Feedback"
    echo "=================="
    echo ""
    echo "Usage: ./learn-from-feedback.sh '<what-wrong>' '<how-to-fix>'"
    echo ""
    echo "Examples:"
    echo "  ./learn-from-feedback.sh 'too many columns' 'use only key columns'"
    echo "  ./learn-from-feedback.sh 'slow import' 'chunk the data'"
    exit 1
fi

FEEDBACK_FILE="$PATTERN_DIR/feedback-$(date +%Y%m%d-%H%M%S).txt"

cat > "$FEEDBACK_FILE" << EOF
# Feedback Learning
# Date: $(date)

Feedback Type: $FEEDBACK_TYPE
Correction: $FEEDBACK_FIX

How to Apply:
1. Remember this correction
2. Apply to future tasks
EOF

echo "Feedback recorded!"
echo "File: $FEEDBACK_FILE"
