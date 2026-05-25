---
name: session-continuity
description: "At ~80% context → auto-trigger /new. Sessions auto-save losslessly to SQLite + JSONL. No handoff docs, no compression."
version: 2.0.0
trigger_conditions:
  - "context window > 78%"
  - "user says 'new session', '/new'"
---

# Session Continuity v2

At ~80% context → trigger `/new`. Sessions auto-save. No handoff docs.

## How Auto-Trigger Works

```
pre_llm_call hook (auto-new-trigger)
  → reads prompt_tokens / max_context_tokens
  → if ratio >= 0.78 → injects "/new" into conversation
  → new session starts, old session saved first
```

Hook: `~/.hermes/hooks/auto-new-trigger/handler.py`

## Session Storage (Permanent, Lossless)

| Storage | What | Location |
|---------|------|----------|
| SQLite `state.db` | Full message history every turn | `~/.hermes/state.db` |
| JSONL transcript | One JSON per message, appended realtime | `~/.hermes/sessions/{session_id}.jsonl` |
| `sessions.json` | Session index | `~/.hermes/sessions/sessions.json` |
| Daily memory | End-of-day digest | `~/.hermes/memory/daily/YYYY-MM-DD.md` |
| Obsidian vault | Mirror of daily memory | `~/.hermes/vault/daily/YYYY-MM-DD.md` |
| Weekly digest | Week compilation | `~/.hermes/memory/weekly/YYYY-Www.md` |

## When to Trigger /new

- Auto: context > 78% (pre_llm_call hook)
- Manual: `nove`, `/new`, session milestone done

## After /new

Use `session_search` to recall context:
```
session_search(query="project-name or task")
```

## Memory Guardian (Self-Healing)

`session-memory-guardian` hook fires on every `session:end`:
- Writes daily digest to `~/.hermes/memory/daily/YYYY-MM-DD.md`
- Mirrors to `~/.hermes/vault/daily/YYYY-MM-DD.md` (Obsidian)
- Auto-compiles weekly digest when week boundary crossed
- Logs session events to `~/.hermes/memory/session_log.jsonl`

Daily format:
```
## YYYY-MM-DD
### Session {id} (HH:MM, N turns)
#### Key Decisions
- ...
#### Skills Created
- ...
#### Errors Resolved
- ...
```

## Skill Nudge (Built-In, Enhanced)

- Every **8 tool-calling iterations** → background review spawns
- Review agent decides if a reusable skill was learned
- Counter resets when `skill_manage` is called
- Threshold lowered from 15 → 8 (more frequent learning)

## Memory Nudge (Enhanced)

- Every **6 user turns** → memory nudge fires
- Minimum 4 turns before flush on exit
- Threshold lowered from 10 → 6 (more frequent)

## What NOT To Do

- Do NOT create handoff docs — sessions are the memory
- Do NOT disable the built-in compressor — it's the safety net
- Do NOT use PENDING_HANDOVER markers
## Quick Commands
- `skill-load session-continuity` — Load this skill
