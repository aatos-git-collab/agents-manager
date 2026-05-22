#!/bin/bash
# Auto-fix missing CSS custom properties in globals.css
# Reads from data/config/colors.js and ensures all colors are defined

PROJECT_DIR="/root/risheng-pawnshop"
GLOBALS_CSS="$PROJECT_DIR/css/globals.css"
COLORS_JS="$PROJECT_DIR/data/config/colors.js"

echo "=== Pawnshop CSS Auto-Fix ==="
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

# Extract color values from colors.js using awk
extract_colors() {
    awk -F"'" '
    /primary/ { if (sub(/.*lighter:.*/, "")) print "PRIMARY_LIGHTER=" $2 }
    /primary/ { if (sub(/.*light:.*/, "")) print "PRIMARY_LIGHT=" $2 }
    /primary/ { if (sub(/.*main:.*/, "")) print "PRIMARY_MAIN=" $2 }
    /primary/ { if (sub(/.*dark:.*/, "")) print "PRIMARY_DARK=" $2 }
    /primary/ { if (sub(/.*darker:.*/, "")) print "PRIMARY_DARKER=" $2 }
    ' "$COLORS_JS" 2>/dev/null | head -5
}

# Simple extraction using grep
PRIMARY_LIGHTER=$(grep -A1 "primary" "$COLORS_JS" | grep "lighter" | grep -o "'#[^']*'" | tr -d "'")
PRIMARY_LIGHT=$(grep -A1 "primary" "$COLORS_JS" | grep "'#[^']*'" | head -1 | tr -d "'")
PRIMARY_MAIN=$(grep -A2 "primary" "$COLORS_JS" | grep "main" | grep -o "'#[^']*'" | tr -d "'")
PRIMARY_DARK=$(grep -A3 "primary" "$COLORS_JS" | grep "dark" | grep -o "'#[^']*'" | head -1 | tr -d "'")
PRIMARY_DARKER=$(grep -A4 "primary" "$COLORS_JS" | grep "darker" | grep -o "'#[^']*'" | tr -d "'")

# Secondary colors - need more careful extraction
SECONDARY_LIGHTER=$(awk '/secondary:/,0' "$COLORS_JS" | grep "lighter" | grep -o "'#[^']*'" | tr -d "'")
SECONDARY_LIGHT=$(awk '/secondary:/,0' "$COLORS_JS" | grep "light" | grep -o "'#[^']*'" | tr -d "'")
SECONDARY_MAIN=$(awk '/secondary:/,0' "$COLORS_JS" | grep "main" | grep -o "'#[^']*'" | tr -d "'")
SECONDARY_DARK=$(awk '/secondary:/,0' "$COLORS_JS" | grep "'#[^']*'" | head -1 | tr -d "'")
SECONDARY_DARKER=$(awk '/secondary:/,0' "$COLORS_JS" | grep "darker" | grep -o "'#[^']*'" | tr -d "'")

echo "Extracted colors from colors.js:"
echo "  primary: lighter=$PRIMARY_LIGHTER light=$PRIMARY_LIGHT main=$PRIMARY_MAIN dark=$PRIMARY_DARK darker=$PRIMARY_DARKER"
echo "  secondary: lighter=$SECONDARY_LIGHTER light=$SECONDARY_LIGHT main=$SECONDARY_MAIN dark=$SECONDARY_DARK darker=$SECONDARY_DARKER"
echo ""

# Check if :root already has our color aliases
if grep -q "\-\-primary-lighter:" "$GLOBALS_CSS" 2>/dev/null; then
    echo "✓ Color aliases already exist in :root block"
else
    echo "Adding color aliases to :root block..."
    # Use awk to insert after --radius: 0.5rem; line
    awk '
    /^    --radius: 0.5rem;$/ {
        print
        print "    /* Color aliases for fancy-* utilities - from data/config/colors.js */"
        print "    --primary-lighter: #fef9c3;"
        print "    --primary-light: #fde047;"
        print "    --primary-main: #eab308;"
        print "    --primary-dark: #ca8a04;"
        print "    --primary-darker: #a16207;"
        print "    --secondary-lighter: #e0e7ff;"
        print "    --secondary-light: #c7d2fe;"
        print "    --secondary-main: #1e3a5f;"
        print "    --secondary-dark: #1e3a5f;"
        print "    --secondary-darker: #0f172a;"
        print "    --maximum-opacity: 0.8;"
        next
    }
    { print }
    ' "$GLOBALS_CSS" > /tmp/globals.css.tmp && mv /tmp/globals.css.tmp "$GLOBALS_CSS"
    echo "  Added to :root"
fi

# Check if .dark already has our color aliases
if awk '/^  .dark/,/^  }$/' "$GLOBALS_CSS" | grep -q "\-\-primary-lighter:" 2>/dev/null; then
    echo "✓ Color aliases already exist in .dark block"
else
    echo "Adding color aliases to .dark block..."
    # Use awk to insert before the closing } of .dark block
    awk '
    /^  .dark {$/ { in_dark = 1 }
    in_dark && /^    --input: 240 3.7% 15.9%;$/ {
        print
        print "    /* Color aliases for fancy-* utilities - dark theme variants */"
        print "    --primary-lighter: #fef08a;"
        print "    --primary-light: #eab308;"
        print "    --primary-main: #ca8a04;"
        print "    --primary-dark: #a16207;"
        print "    --primary-darker: #854d0e;"
        print "    --secondary-lighter: #c7d2fe;"
        print "    --secondary-light: #a5b4fc;"
        print "    --secondary-main: #1e3a5f;"
        print "    --secondary-dark: #1e3a5f;"
        print "    --secondary-darker: #0f172a;"
        print "    --maximum-opacity: 0.8;"
        next
    }
    in_dark && /^  }$/ { in_dark = 0 }
    { print }
    ' "$GLOBALS_CSS" > /tmp/globals.css.tmp && mv /tmp/globals.css.tmp "$GLOBALS_CSS"
    echo "  Added to .dark"
fi

echo ""
echo "✓ Auto-fix complete"
echo ""
echo "Run './scripts/check.sh' to verify, then 'npm run build' to test"
