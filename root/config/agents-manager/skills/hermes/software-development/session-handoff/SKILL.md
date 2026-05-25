---
name: session-handoff
description: session-handoff skill
  Creates comprehensive handoff documents for seamless AI agent session transfers. Activated when:
  (1) user requests handoff/memory save, (2) context approaches capacity, (3) major milestone completed,
  (4) work session ending. Also activates on "load handoff", "resume from", "continue where we left off".
---

# Session Handoff

Creates comprehensive handoff documents enabling fresh AI agents to seamlessly continue work with zero ambiguity.

## When to Use

**Creating handoff:** User wants to save state, pause work, or context is full.
**Resuming:** User wants to continue previous work.

**Proactive suggestion** after substantial work (5+ file edits, complex debugging, architecture decisions):
> "We've made significant progress. Consider creating a handoff document. Say 'create handoff' when ready."

## CREATE Workflow

### Step 1: Generate Scaffold

```bash
python scripts/create_handoff.py [task-slug]
```

**For continuation handoffs** (linking to previous):
```bash
python scripts/create_handoff.py "auth-part-2" --continues-from 2024-01-15-auth.md
```

### Step 2: Complete Sections

Prioritize these:
1. **Current State Summary** - What's happening right now
2. **Important Context** - Critical info next agent MUST know
3. **Immediate Next Steps** - Clear, actionable first steps
4. **Decisions Made** - Choices with rationale

### Step 3: Validate

```bash
python scripts/validate_handoff.py <handoff-file>
```

Validator checks:
- No `[TODO: ...]` placeholders remaining
- Required sections populated
- No secrets detected
- Quality score (0-100)

**Do not finalize with score below 70.**

### Step 4: Confirm

Report: file location, validation score, summary.

## RESUME Workflow

1. Find handoff file in `.claude/handoffs/`
2. Run: `python scripts/check_staleness.py <handoff-file>`
3. Read file content
4. Verify referenced files still exist
5. Start work from "Immediate Next Steps"

## Handoff Template

```markdown
# Handoff: [TASK_TITLE]

## Session Metadata
- Created: [TIMESTAMP]
- Project: [PROJECT_PATH]
- Branch: [GIT_BRANCH]

## Current State Summary
[One paragraph: What was being worked on, current status]

## Important Context
[Critical info the next agent MUST know]

## Immediate Next Steps
1. [Clear actionable first step]
2. [Next step]

## Decisions Made
- [Choice] → [Rationale]

## Potential Gotchas
- [Things to watch out for]
```

## Staleness Levels

- **FRESH**: <1 day, <3 commits - Safe to use directly
- **SLIGHTLY_STALE**: 1-3 days, 3-10 commits - Verify environment
- **STALE**: 3-7 days, 10-30 commits - Review changes
- **VERY_STALE**: >7 days, >30 commits - Full review required

## Storage Location

Handoffs stored in `.claude/handoffs/` with timestamp naming:
`YYYY-MM-DD-HHMMSS-[task-slug].md`
## Quick Commands
- `skill-load session-handoff` — Load this skill
