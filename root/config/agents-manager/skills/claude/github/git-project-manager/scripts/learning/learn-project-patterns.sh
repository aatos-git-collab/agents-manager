#!/bin/bash
# Learn from project management session

PROJECT_DIR="${1:-.}"
PATTERN_DIR="/memory/patterns/projects"
mkdir -p "$PATTERN_DIR"

echo "📚 Learning from project management session..."
echo ""

# Analyze project
cd "$PROJECT_DIR"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Detect project type
if [ -f "package.json" ]; then
    TYPE="node"
elif [ -f "requirements.txt" ]; then
    TYPE="python"
elif [ -f "go.mod" ]; then
    TYPE="go"
else
    TYPE="unknown"
fi

echo "Project: $PROJECT_NAME"
echo "Type: $TYPE"

# Extract patterns
PATTERN_FILE="$PATTERN_DIR/$PROJECT_NAME-$(date +%Y%m%d).txt"

cat > "$PATTERN_FILE" << PATTERN_EOF
# Project Learning: $PROJECT_NAME
# Date: $(date)
# Type: $TYPE

## What Worked
- 
- 

## What Didn't Work
- 
- 

## Git Patterns
- Commit frequency: 
- Branch strategy: 
- Review process: 

## Project Structure Insights
- Key directories: 
- Important files: 
- Configuration: 

## Team Patterns
- Workflow: 
- Communication: 
- Handoffs: 

## Technical Notes
- Dependencies: 
- Build process: 
- Deployment: 

PATTERN_EOF

echo ""
echo "✅ Pattern saved: $PATTERN_FILE"
echo ""
echo "💡 Edit to add your learnings:"
echo "   nano $PATTERN_FILE"
