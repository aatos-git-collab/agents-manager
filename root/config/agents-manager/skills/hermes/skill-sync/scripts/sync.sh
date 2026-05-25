#!/bin/bash
# skill-sync — Bidirectional sync between Hermes (AatosTeam) and Claude Code
# Usage: sync.sh [forward|reverse|status|install-cron|verify|cron]
#   forward  = Hermes → Claude Code (symlink new Hermes skills into Claude Code)
#   reverse  = Claude Code → Hermes (promote ck patterns to new Hermes skills)
#   status   = show all symlinks and sync status
#   install-cron = add 15-min cron job
#   verify   = run forward + reverse + report
#   cron     = both directions (used by cron)
#   (no args) = status

set -e

HERMES_SKILLS="/root/.hermes/skills"
HERMES_AGENTS="/root/.hermes/agents"
CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_AGENTS="$HOME/.claude/agents"
CLAUDE_CK_BANK="$HOME/.claude/agents/memory-bank"
SKILL_SYNC_LOG="$HOME/.hermes/memory/skill-sync.log"
SKILL_SYNC_CRON="*/15 * * * *"

log() { echo "[skill-sync $(date +%H:%M:%S)] $1"; }

# ─── Forward sync: Hermes → Claude Code ───────────────────────────────────────

do_forward() {
    log "=== Forward sync: Hermes → Claude Code ==="
    local synced=0 skipped=0 broken=0 created=0

    # Ensure Claude Code dirs exist
    mkdir -p "$CLAUDE_SKILLS" "$CLAUDE_AGENTS"

    # Sync skills
    for skill_path in "$HERMES_SKILLS"/*/; do
        [ -d "$skill_path" ] || continue
        skill_name="$(basename "$skill_path")"
        target="$CLAUDE_SKILLS/$skill_name"

        if [ -L "$target" ]; then
            # Already a symlink
            if [ -e "$target" ]; then
                # Valid symlink — check if pointing to correct source
                local current_src
                current_src="$(readlink -f "$target" 2>/dev/null || true)"
                local expected_src
                expected_src="$(readlink -f "$skill_path" 2>/dev/null || true)"
                if [ "$current_src" = "$expected_src" ]; then
                    : # Already pointing to correct source, skip
                else
                    # Wrong target — recreate
                    ln -sfn "$skill_path" "$target"
                    log "  🔄 updated: $skill_name (wrong target)"
                    ((synced++)) || true
                fi
            else
                # Broken symlink — recreate
                ln -sfn "$skill_path" "$target"
                log "  🔧 fixed: $skill_name (broken symlink)"
                ((broken++)) || true || true
                ((created++)) || true
            fi
        elif [ -e "$target" ]; then
            # Real file/dir exists — skip (don't overwrite)
            log "  ⏭️  skipped: $skill_name (exists as real dir/file)"
            ((skipped++)) || true
        else
            # New symlink
            ln -sfn "$skill_path" "$target"
            log "  ✅ synced: $skill_name"
            ((synced++)) || true
            ((created++)) || true
        fi
    done

    # Sync agents
    if [ -d "$HERMES_AGENTS" ]; then
        for agent_path in "$HERMES_AGENTS"/*/; do
            [ -d "$agent_path" ] || continue
            agent_name="$(basename "$agent_path")"
            target="$CLAUDE_AGENTS/$agent_name"

            if [ -L "$target" ]; then
                if [ -e "$target" ]; then
                    : # Valid symlink, skip
                else
                    ln -sfn "$agent_path" "$target"
                    log "  🔧 fixed: agent/$agent_name (broken symlink)"
                    ((broken++)) || true || true
                fi
            elif [ -e "$target" ]; then
                ((skipped++)) || true
            else
                ln -sfn "$agent_path" "$target"
                log "  ✅ synced: agent/$agent_name"
                ((synced++)) || true
            fi
        done
    fi

    # Sync tools with agent components
    for tool_path in /root/.hermes/tools/*/; do
        [ -d "$tool_path" ] || continue
        tool_name="$(basename "$tool_path")"

        # If tool has skills dir, sync as skill
        if [ -d "$tool_path/skills" ]; then
            target="$CLAUDE_SKILLS/$tool_name"
            if [ ! -e "$target" ]; then
                ln -sfn "$tool_path/skills" "$target"
                log "  ✅ synced: tool/$tool_name (as skill)"
            fi
        fi

        # If tool has SKILL.md at top level, sync as skill
        if [ -f "$tool_path/SKILL.md" ]; then
            target="$CLAUDE_SKILLS/$tool_name"
            if [ ! -e "$target" ]; then
                ln -sfn "$tool_path" "$target"
                log "  ✅ synced: tool/$tool_name (as skill)"
            fi
        fi
    done

    log "Forward sync done: $synced synced, $broken fixed, $skipped skipped"
}

# ─── Reverse sync: Claude Code → Hermes (promotion) ────────────────────────────

do_reverse() {
    log "=== Reverse sync: Claude Code → Hermes (promotion scan) ==="
    local candidates=0 promoted=0

    if [ ! -d "$CLAUDE_CK_BANK" ]; then
        log "No ck memory-bank found at $CLAUDE_CK_BANK — nothing to promote"
        return
    fi

    # Find promotion candidates
    shopt -s globstar nullglob 2>/dev/null || true
    for md_file in "$CLAUDE_CK_BANK"/**/*.md "$CLAUDE_CK_BANK"/*.md; do
        [ -f "$md_file" ] || continue

        # Skip if already promoted
        if grep -q "^promoted:" "$md_file" 2>/dev/null; then
            continue
        fi

        # Check if it's a promotion candidate
        local is_candidate=false
        if grep -q "skill-candidate:\s*true" "$md_file" 2>/dev/null; then
            is_candidate=true
        elif grep -q "^promote_to:" "$md_file" 2>/dev/null; then
            is_candidate=true
        elif grep -q "^## skill-promo" "$md_file" 2>/dev/null; then
            is_candidate=true
        fi

        if $is_candidate; then
            ((candidates++)) || true
            log "  🎯 candidate: $(basename "$md_file")"

            # Extract suggested skill name (if provided)
            local suggested_name
            suggested_name="$(grep "^promote_to:" "$md_file" 2>/dev/null | head -1 | sed 's/promote_to:\s*//' | tr -d ' ')"
            [ -z "$suggested_name" ] && suggested_name="ck-$(date +%s)"

            # Mark as promoted (add frontmatter if not present)
            if ! grep -q "^promoted:" "$md_file" 2>/dev/null; then
                sed -i '1s/^/promoted: true\n/' "$md_file"
            fi

            log "  📝 flagged for promotion: $suggested_name (manual review needed — use skill-creator)"
            ((promoted++)) || true
        fi
    done

    if [ "$candidates" -eq 0 ]; then
        log "No promotion candidates found in ck memory-bank"
    else
        log "Reverse sync done: $candidates candidates found, $promoted tagged for promotion"
        log "  → Run 'skill-creator' manually to create skills from promoted patterns"
    fi
}

# ─── Status ───────────────────────────────────────────────────────────────────

do_status() {
    echo "=== skill-sync status ==="
    echo ""
    echo "Forward (Hermes → Claude Code):"
    local total_hermes=0 total_claude=0 symlinked=0 broken=0 real=0

    for skill_path in "$HERMES_SKILLS"/*/; do
        [ -d "$skill_path" ] || continue
        ((total_hermes++)) || true
        skill_name="$(basename "$skill_path")"
        target="$CLAUDE_SKILLS/$skill_name"

        if [ -L "$target" ]; then
            if [ -e "$target" ]; then
                echo "  ✅ $skill_name"
                ((symlinked++)) || true
            else
                echo "  🔧 $skill_name (broken symlink)"
                ((broken++)) || true || true
            fi
        elif [ -e "$target" ]; then
            echo "  ⏭️  $skill_name (real dir — skipped)"
            ((real++)) || true
        else
            echo "  ❌ $skill_name (not linked)"
        fi
    done

    echo ""
    echo "  Hermes skills: $total_hermes | Symlinked: $symlinked | Broken: $broken | Real (skipped): $real"
    echo ""

    echo "Reverse (Claude Code → Hermes promotion):"
    if [ -d "$CLAUDE_CK_BANK" ]; then
        local candidates
        candidates=$(grep -rl "skill-candidate:\s*true\|promote_to:\|## skill-promo" "$CLAUDE_CK_BANK" 2>/dev/null | wc -l)
        echo "  Promotion candidates in ck: $candidates"
    else
        echo "  ⏭️  No ck memory-bank found"
    fi

    echo ""
    echo "Cron:"
    if crontab -l 2>/dev/null | grep -q "skill-sync"; then
        echo "  ✅ Installed"
        crontab -l 2>/dev/null | grep "skill-sync"
    else
        echo "  ❌ Not installed — run: bash ~/.hermes/skills/skill-sync/scripts/sync.sh install-cron"
    fi
}

# ─── Install cron ──────────────────────────────────────────────────────────────

do_install_cron() {
    log "Installing skill-sync cron..."
    local cron_line="$SKILL_SYNC_CRON bash $HOME/.hermes/skills/skill-sync/scripts/sync.sh cron >> $SKILL_SYNC_LOG 2>&1"

    # Remove only this specific line (not any line containing "skill-sync")
    local current
    current=$(crontab -l 2>/dev/null || true)
    current=$(echo "$current" | grep -vF "$cron_line" || true)
    echo "$current" | crontab - 2>/dev/null || true
    echo "$cron_line" | crontab - 2>/dev/null || {
        echo "$current" > /tmp/crontab_backup
        echo "$cron_line" >> /tmp/crontab_backup
        crontab /tmp/crontab_backup 2>/dev/null || {
            log "⚠️  Could not install cron — manual install:"
            log "  $cron_line"
        }
    }

    log "✅ skill-sync cron installed: $SKILL_SYNC_CRON"
}

# ─── Verify ────────────────────────────────────────────────────────────────────

do_verify() {
    log "=== Verify ==="
    do_forward
    do_reverse
    echo ""
    log "Verify complete. Run 'sync.sh status' for full report."
}

# ─── Main dispatch ─────────────────────────────────────────────────────────────

ACTION="${1:-status}"

case "$ACTION" in
    forward)  do_forward ;;
    reverse)  do_reverse ;;
    status)   do_status ;;
    install-cron) do_install_cron ;;
    verify)   do_verify ;;
    cron)     do_forward && do_reverse ;;
    *)
        echo "Usage: sync.sh [forward|reverse|status|install-cron|verify|cron]"
        exit 1
        ;;
esac
