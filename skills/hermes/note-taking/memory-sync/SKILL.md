---
name: memory-sync
description: Sync knowledge across sessions - consolidate learnings, update memory, share insights
trigger: /memory-update or /memory-sync
---

# Memory Sync Skill

This skill syncs knowledge and learnings across sessions and projects. All memories are stored as individual dated files, not single large MD files.

## When to Use

- Running `/memory-update` or `/memory-sync` command
- End of each session
- Before handing off to another agent
- When resuming previous work

## File Naming Convention

All files follow format: `YYYYMMDD-HHMMSS-[type].md`

Examples:
- `20260321-143000-session.md` - Session memory
- `20260321-143000-lesson.md` - Learning
- `20260321-143000-decision.md` - ADR
- `20260321-143000-pattern.md` - Pattern

## Steps

### 1. Collect Learnings from Project .lessons/
- Read all `.claude/.lessons/*.md` files in current project
- Identify key insights, bugs found, patterns discovered

### 2. Sync to Global .lessons/
- Create new dated file in global `.claude/.lessons/`
- Format: `YYYYMMDD-HHMMSS-project.md`
- Only sync cross-project learnings, not project-specific

### 3. Create Session Summary
Create new dated file: `.claude/.lessons/YYYYMMDD-HHMMSS-session.md`
```
# Session Summary - YYYY-MM-DD

## Project: [PROJECT]
## Session: [SESSION_ID]

### Tasks Completed
- [Task 1]

### Bugs Found
- [Bug]: [Status]

### Learnings
1. [Learning 1]

### Next Steps
- [ ] [Pending]
```

### 4. Update Project Memories
Create dated files in project folders:
- `.claude/lessons/YYYYMMDD-HHMMSS.md` - Project learnings
- `.claude/decisions/YYYYMMDD-HHMMSS.md` - Project ADRs
- `.claude/patterns/YYYYMMDD-HHMMSS.md` - Project patterns
- `.claude/memory/YYYYMMDD-HHMMSS.md` - Session memory

### 5. Prepare for Next Session
- Document current work state
- Note pending tasks

## Folder Structure

```
Global (/root/.claude/):
  .lessons/          # Cross-project learnings (YYYYMMDD-HHMMSS.md)
  lessons/           # Cross-project lessons (YYYYMMDD-HHMMSS.md)
  decisions/         # Cross-project ADRs (YYYYMMDD-HHMMSS.md)
  patterns/          # Cross-project patterns (YYYYMMDD-HHMMSS.md)
  memory/            # Global sessions (YYYYMMDD-HHMMSS.md)

Project (/root/projectX/<project>/.claude/):
  .lessons/          # Hidden - agent learnings (YYYYMMDD-HHMMSS.md)
  lessons/           # Visible - project learnings
  decisions/         # Project ADRs
  patterns/         # Project patterns
  memory/            # Project sessions
```

## Output

After sync:
- New dated files created in project `.claude/` folders
- Cross-project learnings synced to global `.claude/` folders
- No single large MEMORY.md files - all dated individual files

## Notes

- NEVER create or update MEMORY.md files
- Always use date-based naming: `YYYYMMDD-HHMMSS-[type].md`
- Agents read ALL .md files in folder, not just one
- Use `/remember` to auto-create dated memory files
## Quick Commands
- `skill-load memory-sync` — Load this skill
