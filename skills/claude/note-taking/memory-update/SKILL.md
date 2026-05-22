---
name: memory-update
description: Sync knowledge across sessions - consolidate learnings, update memory, share insights
trigger: /memory-update or end of session
---

# /memory-update Command

Run this command to sync knowledge across sessions.

## Usage

```
/memory-update
```

## Description

Syncs knowledge and learnings across sessions:

1. **Collects** - Reads all .lessons/*.md files
2. **Consolidates** - Creates session summary
3. **Updates** - Updates root memory with key learnings
4. **Prepares** - Creates next session briefing

## When to Use

- End of each work session
- Before handing off to another agent
- When resuming previous work
- Before taking a break

## Steps

### 1. Collect Learnings from .lessons/
- Read all .lessons/*.md files
- Identify key insights
- Note bugs found and fixed
- Note patterns discovered

### 2. Consolidate Session Summary
Create session-summary.md with:
- Tasks completed
- Bugs found and fixed
- Architectural decisions
- Code quality improvements
- Performance optimizations

### 3. Update Memory
- Update root memory with key learnings
- Share relevant patterns with other agents
- Update shared knowledge base

### 4. Prepare for Next Session
- Document current work state
- Note pending tasks
- List blockers and assumptions

## Output

After sync:
- session-summary.md in .lessons/
- Updated memory files
- Next session briefing

## Example

```
/memory-update

Collecting learnings from .lessons/...
- qa-agent-lessons.md: 3 bugs found
- devops-agent-lessons.md: CI improvements
- security-agent-lessons.md: vulnerability patch

Creating session summary...
Summary created: .lessons/session-summary-2026-03-18.md

Memory synced successfully!
Ready for next session.
```

## Notes

- CTO is responsible for final consolidation
- All agents should write to .lessons/ during work
- Memory sync happens before session ends
