#!/bin/bash
#===============================================================================
# dynamic-rebrand.sh — CTO-grade automated rebranding scanner & reporter
# Usage: ./dynamic-rebrand.sh [OLD_BRAND] [NEW_BRAND] [PROJECT_DIR]
#===============================================================================

set -e

OLD_BRAND="${1:-}"
NEW_BRAND="${2:-}"
PROJECT_DIR="${3:-.}"

if [[ -z "$OLD_BRAND" || -z "$NEW_BRAND" ]]; then
  echo "Usage: $0 <OLD_BRAND> <NEW_BRAND> [PROJECT_DIR]"
  echo "Example: $0 OldBrand new-brand ./my-project"
  exit 1
fi

cd "$PROJECT_DIR"

echo "╔══════════════════════════════════════════════════════╗"
echo "║       DYNAMIC REBRAND SCAN — AatosCTO Edition       ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║ Old: $OLD_BRAND"
echo "║ New: $NEW_BRAND"
echo "║ Dir: $(pwd)"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

OLD_SNAKE=$(echo "$OLD_BRAND" | sed 's/-/_/g' | tr '[:upper:]' '[:lower:]')
NEW_SNAKE=$(echo "$NEW_BRAND" | sed 's/-/_/g' | tr '[:upper:]' '[:lower:]')
OLD_CAMEL=$(echo "$OLD_BRAND" | sed 's/-//g' | sed 's/\b\(.\)/\U\1/g')
NEW_CAMEL=$(echo "$NEW_BRAND" | sed 's/-//g' | sed 's/\b\(.\)/\U\1/g')
OLD_DISPLAY=$(echo "$OLD_BRAND" | sed 's/-/ /g')
NEW_DISPLAY=$(echo "$NEW_BRAND" | sed 's/-/ /g')

TOTAL_FILES=$(find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.html" -o -name "*.css" -o -name "*.scss" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" -o -name "*.md" -o -name "*.sh" -o -name "*.env*" -o -name "Dockerfile" -o -name "docker-compose*" \) | wc -l)
echo "[INFO] Scanning $TOTAL_FILES target files..."
echo ""

# Arrays to store results
declare -a PY_FILES=()
declare -a JS_FILES=()
declare -a CONFIG_FILES=()
declare -a DOCKER_FILES=()
declare -a DOC_FILES=()
declare -a ENV_FILES=()

echo "═══════════════════════════════════════"
echo "  PHASE 1: SCAN RESULTS"
echo "═══════════════════════════════════════"
echo ""

for pattern in \
  "$OLD_BRAND" \
  "$OLD_SNAKE" \
  "$OLD_CAMEL" \
  "$OLD_DISPLAY"; do

  echo "--- Pattern: $pattern ---"

  # Python
  FOUND_PY=$(grep -rln "$pattern" --include="*.py" . 2>/dev/null || true)
  if [[ -n "$FOUND_PY" ]]; then
    while IFS= read -r f; do [[ -n "$f" ]] && PY_FILES+=("$f"); done <<< "$FOUND_PY"
    echo "  PY: $(echo "$FOUND_PY" | wc -l) files"
    echo "$FOUND_PY" | sed 's/^/    /'
  fi

  # JS/TS
  FOUND_JS=$(grep -rln "$pattern" --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" . 2>/dev/null || true)
  if [[ -n "$FOUND_JS" ]]; then
    while IFS= read -r f; do [[ -n "$f" ]] && JS_FILES+=("$f"); done <<< "$FOUND_JS"
    echo "  JS: $(echo "$FOUND_JS" | wc -l) files"
    echo "$FOUND_JS" | sed 's/^/    /'
  fi

  # Config (json, yaml, toml)
  FOUND_CFG=$(grep -rln "$pattern" --include="*.json" --include="*.yaml" --include="*.yml" --include="*.toml" . 2>/dev/null || true)
  if [[ -n "$FOUND_CFG" ]]; then
    while IFS= read -r f; do [[ -n "$f" ]] && CONFIG_FILES+=("$f"); done <<< "$FOUND_CFG"
    echo "  CFG: $(echo "$FOUND_CFG" | wc -l) files"
    echo "$FOUND_CFG" | sed 's/^/    /'
  fi

  # Docker
  FOUND_DOCKER=$(grep -rln "$pattern" --include="Dockerfile" --include="docker-compose*" . 2>/dev/null || true)
  if [[ -n "$FOUND_DOCKER" ]]; then
    while IFS= read -r f; do [[ -n "$f" ]] && DOCKER_FILES+=("$f"); done <<< "$FOUND_DOCKER"
    echo "  DOCKER: $(echo "$FOUND_DOCKER" | wc -l) files"
    echo "$FOUND_DOCKER" | sed 's/^/    /'
  fi

  # Docs
  FOUND_DOC=$(grep -rln "$pattern" --include="*.md" . 2>/dev/null || true)
  if [[ -n "$FOUND_DOC" ]]; then
    while IFS= read -r f; do [[ -n "$f" ]] && DOC_FILES+=("$f"); done <<< "$FOUND_DOC"
    echo "  DOC: $(echo "$FOUND_DOC" | wc -l) files"
    echo "$FOUND_DOC" | sed 's/^/    /'
  fi

  # ENV
  FOUND_ENV=$(grep -rln "$pattern" --include=".env*" . 2>/dev/null || true)
  if [[ -n "$FOUND_ENV" ]]; then
    while IFS= read -r f; do [[ -n "$f" ]] && ENV_FILES+=("$f"); done <<< "$FOUND_ENV"
    echo "  ENV: $(echo "$FOUND_ENV" | wc -l) files"
    echo "$FOUND_ENV" | sed 's/^/    /'
  fi

  echo ""
done

# Deduplicate arrays
PY_FILES=($(printf '%s\n' "${PY_FILES[@]}" | sort -u))
JS_FILES=($(printf '%s\n' "${JS_FILES[@]}" | sort -u))
CONFIG_FILES=($(printf '%s\n' "${CONFIG_FILES[@]}" | sort -u))
DOCKER_FILES=($(printf '%s\n' "${DOCKER_FILES[@]}" | sort -u))
DOC_FILES=($(printf '%s\n' "${DOC_FILES[@]}" | sort -u))
ENV_FILES=($(printf '%s\n' "${ENV_FILES[@]}" | sort -u))

echo "═══════════════════════════════════════"
echo "  PHASE 2: SUMMARY"
echo "═══════════════════════════════════════"
echo ""
echo "  Python files:   ${#PY_FILES[@]}"
echo "  JS/TS files:    ${#JS_FILES[@]}"
echo "  Config files:   ${#CONFIG_FILES[@]}"
echo "  Docker files:   ${#DOCKER_FILES[@]}"
echo "  Doc files:      ${#DOC_FILES[@]}"
echo "  ENV files:      ${#ENV_FILES[@]}"
echo ""

TOTAL_UNIQUE=0
for arr in PY_FILES JS_FILES CONFIG_FILES DOCKER_FILES DOC_FILES ENV_FILES; do
  [[ ${#arr[@]} -gt 0 ]] && ((TOTAL_UNIQUE += ${#arr[@]}))
done
echo "  Total unique files: $TOTAL_UNIQUE"
echo ""

echo "═══════════════════════════════════════"
echo "  PHASE 3: DRY RUN — Show Replacements"
echo "═══════════════════════════════════════"
echo ""

for file in "${PY_FILES[@]}"; do
  echo "  PY: $file"
  grep -n "$OLD_BRAND\|$OLD_SNAKE\|$OLD_CAMEL" "$file" 2>/dev/null | head -3 | sed 's/^/    /'
done

for file in "${JS_FILES[@]}"; do
  echo "  JS: $file"
  grep -n "$OLD_BRAND\|$OLD_SNAKE\|$OLD_CAMEL" "$file" 2>/dev/null | head -3 | sed 's/^/    /'
done

for file in "${CONFIG_FILES[@]}"; do
  echo "  CFG: $file"
  grep -n "$OLD_BRAND\|$OLD_SNAKE\|$OLD_CAMEL" "$file" 2>/dev/null | head -3 | sed 's/^/    /'
done

for file in "${DOCKER_FILES[@]}"; do
  echo "  DOCKER: $file"
  grep -n "$OLD_BRAND\|$OLD_SNAKE\|$OLD_CAMEL" "$file" 2>/dev/null | head -3 | sed 's/^/    /'
done

for file in "${DOC_FILES[@]}"; do
  echo "  DOC: $file"
  grep -n "$OLD_BRAND\|$OLD_SNAKE\|$OLD_CAMEL" "$file" 2>/dev/null | head -3 | sed 's/^/    /'
done

for file in "${ENV_FILES[@]}"; do
  echo "  ENV: $file"
  grep -n "$OLD_BRAND\|$OLD_SNAKE\|$OLD_CAMEL" "$file" 2>/dev/null | head -3 | sed 's/^/    /'
done

echo ""
echo "═══════════════════════════════════════"
echo "  PHASE 4: REPLACE COMMAND"
echo "═══════════════════════════════════════"
echo ""

SED_PY=$(printf " -e 's/%s/%s/g' -e 's/%s/%s/g' -e 's/%s/%s/g'" \
  "$OLD_BRAND" "$NEW_BRAND" \
  "$OLD_SNAKE" "$NEW_SNAKE" \
  "$OLD_CAMEL" "$NEW_CAMEL")

echo "Python/JS/TS files:"
echo "  find . \\( -name '*.py' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' \\) \\"
echo "    -exec sed -i $SED_PY {} +"
echo ""
echo "Config files:"
echo "  find . \\( -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.toml' \\) \\"
echo "    -exec sed -i $SED_PY {} +"
echo ""
echo "Docker files:"
echo "  find . \\( -name 'Dockerfile*' -o -name 'docker-compose*' \\) \\"
echo "    -exec sed -i $SED_PY {} +"
echo ""
echo "Docs:"
echo "  find . -name '*.md' -exec sed -i $SED_PY {} +"
echo ""
echo "ENV files:"
echo "  for f in .env*; do [ -f \"\$f\" ] && sed -i $SED_PY \"\$f\"; done"
echo ""

echo "═══════════════════════════════════════"
echo "  PHASE 5: POST-REPLACE VERIFY"
echo "═══════════════════════════════════════"
echo ""
echo "  Run after replacement:"
echo "  grep -rn '$OLD_BRAND\|$OLD_SNAKE\|$OLD_CAMEL' \\"
echo "    --include='*.py' --include='*.js' --include='*.ts' \\"
echo "    --include='*.json' --include='*.yaml' --include='*.yml' \\"
echo "    --include='Dockerfile' --include='docker-compose*' \\"
echo "    --include='.env*' --include='*.md' . 2>/dev/null \\"
echo "    | grep -v '$NEW_BRAND\|$NEW_SNAKE\|$NEW_CAMEL' \\"
echo "    | head -20 || echo 'ALL CLEAN'"
echo ""

echo "╔══════════════════════════════════════════════════════╗"
echo "║              SCAN COMPLETE — AatosCTO               ║"
echo "╚══════════════════════════════════════════════════════╝"
