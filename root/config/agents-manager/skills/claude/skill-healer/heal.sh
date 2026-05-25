#!/bin/bash
#
# skill-healer - Self-healing autofixer for Hermes skills ecosystem
# Detects and fixes: missing Quick Commands, empty descriptions, missing frontmatter
#

set -uo pipefail

SKILLS_DIR="${SKILLS_DIR:-/root/.hermes/skills}"
DRY_RUN=false
SINGLE_SKILL=""
VERBOSE=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $0 [skill-name|--dry-run|--verbose]"
    echo ""
    echo "  (no args)         - Heal ALL skills recursively"
    echo "  skill-name         - Heal a specific skill (supports nested paths)"
    echo "  --dry-run          - Show what would change without changing"
    echo "  --dry-run skill    - Dry-run for specific skill"
    echo "  --verbose          - Show every skill checked"
    exit 0
}

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --help|-h) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) SINGLE_SKILL="$1"; shift ;;
    esac
done

# ─── Helpers ───────────────────────────────────────────────────────────────

has_frontmatter() {
    local f="$1"
    [ -f "$f" ] && head -1 "$f" | grep -q '^---$'
}

get_fm() {
    local f="$1"
    if [ ! -f "$f" ]; then echo ""; return; fi
    if head -1 "$f" | grep -q '^---$'; then
        awk '/^---$/ && !first {first=1; next} /^---$/ && first {exit} first' "$f"
    else
        echo ""
    fi
}

fm_val() {
    local fm="$1" key="$2"
    echo "$fm" | grep "^${key}:" | head -1 | sed 's/^[^:]*: *//' | tr -d '"' | tr -d "'" | xargs
}

has_qc() {
    local f="$1"
    [ -f "$f" ] && grep -qE "^## Quick Commands|^## Usage|^## Commands" "$f"
}

is_empty_desc() {
    local d="$1"
    [ -z "$d" ] || [ "$d" = "empty" ] || [ ${#d} -lt 3 ]
}

# ─── Fix functions ─────────────────────────────────────────────────────────

fix_frontmatter() {
    local sf="$1" name="$2" desc="$3"
    if has_frontmatter "$sf"; then return 0; fi

    if [ -z "$desc" ]; then desc="$name skill"; fi

    local tmp
    tmp=$(mktemp)
    cat > "$tmp" <<EOF
---
name: $name
description: $desc
---
EOF
    cat "$sf" >> "$tmp"
    mv "$tmp" "$sf"
    echo -e "${GREEN}+ frontmatter${NC}"
}

fix_empty_desc() {
    local sf="$1" name="$2"
    local fm new_desc
    fm=$(get_fm "$sf")
    local d
    d=$(fm_val "$fm" "description")
    if ! is_empty_desc "$d"; then return 0; fi

    new_desc="$name skill"
    sed -i "s/^description:.*/description: $new_desc/" "$sf"
    echo -e "${GREEN}+ description fixed${NC}"
}

fix_qc() {
    local sf="$1" name="$2"
    if has_qc "$sf"; then return 0; fi

    # Append before any last-divider line or at end
    local tmp
    tmp=$(mktemp)
    if grep -qE "^---$" "$sf"; then
        # Insert QC before the last --- divider at EOF
        local line_num
        line_num=$(grep -n "^---$" "$sf" | tail -1 | cut -d: -f1)
        head -n "$line_num" "$sf" > "$tmp"
        printf "\n## Quick Commands\n- \`skill-load %s\` — Load this skill\n" "$name" >> "$tmp"
        tail -n +$((line_num + 1)) "$sf" >> "$tmp"
    else
        cat "$sf" > "$tmp"
        printf "\n## Quick Commands\n- \`skill-load %s\` — Load this skill\n" "$name" >> "$tmp"
    fi
    mv "$tmp" "$sf"
    echo -e "${GREEN}+ Quick Commands${NC}"
}

# ─── Heal a single skill ──────────────────────────────────────────────────

heal_skill() {
    local skill_path="$1"   # e.g. /root/.hermes/skills/mlops/pytorch-patterns
    local skill_name
    skill_name=$(basename "$skill_path")

    local sf="$skill_path/SKILL.md"
    [ ! -f "$sf" ] && return

    # Detect issues
    local issues=()
    [ ! has_frontmatter "$sf" ] && issues+=("no-frontmatter")
    local fm desc
    fm=$(get_fm "$sf"); desc=$(fm_val "$fm" "description")
    is_empty_desc "$desc" && issues+=("empty-desc")
    [ ! has_qc "$sf" ] && issues+=("no-qc")

    if [ ${#issues[@]} -eq 0 ]; then
        [ "$VERBOSE" = true ] && echo -e "${CYAN}  ok  ${NC} $skill_name"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY] $skill_name — would fix: ${issues[*]}${NC}"
        return
    fi

    echo -e "${GREEN}healing${NC} $skill_name (${issues[*]})"
    fix_frontmatter "$sf" "$skill_name" "$desc"
    fm=$(get_fm "$sf"); desc=$(fm_val "$fm" "description")
    fix_empty_desc "$sf" "$skill_name"
    fix_qc "$sf" "$skill_name"
}

# ─── Main ─────────────────────────────────────────────────────────────────

main() {
    local fixed=0 skipped=0 failed=0

    echo "========================================"
    echo "  Skill Healer - Self-Healing Autofixer"
    echo "========================================"
    echo "  Recursive: YES (finds all nested SKILL.md)"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY-RUN — no changes will be made${NC}"
        echo ""
    fi

    if [ -n "$SINGLE_SKILL" ]; then
        # Resolve skill path (supports both top-level and nested)
        local skill_path=""
        if [ -d "$SKILLS_DIR/$SINGLE_SKILL" ]; then
            skill_path="$SKILLS_DIR/$SINGLE_SKILL"
        else
            # Try finding it recursively
            skill_path=$(find "$SKILLS_DIR" -type d -name "$SINGLE_SKILL" 2>/dev/null | head -1)
        fi

        if [ -z "$skill_path" ] || [ ! -d "$skill_path" ]; then
            echo -e "${RED}Error: Skill '$SINGLE_SKILL' not found${NC}"
            exit 1
        fi

        heal_skill "$skill_path"
        echo ""
        echo "Done."
    else
        # Recursively find ALL SKILL.md files
        local skill_paths
        skill_paths=$(find "$SKILLS_DIR" -name SKKILL.md -o -name SKILL.md 2>/dev/null | sort)
        # Actually the find pattern above has a typo issue — use proper glob
        skill_paths=$(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null | sort)

        local total
        total=$(echo "$skill_paths" | grep -c "^" || echo 0)

        echo "Found $total SKILL.md files — healing..."
        echo ""

        while IFS= read -r sf; do
            [ -z "$sf" ] && continue
            heal_skill "$(dirname "$sf")"
        done <<< "$skill_paths"
    fi

    echo ""
    echo "========================================"
    echo -e "  ${GREEN}Done.${NC}"
    echo "========================================"
}

main