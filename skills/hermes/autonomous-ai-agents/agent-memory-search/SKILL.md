---
name: agent-memory-search
description: agent-memory-search skill
  Search across all indexed agent sessions, learnings, memory banks, and skills.
  Use when: user asks "search sessions", "what were we working on", "find previous work",
  "search memory", "search learnings", "what skills do we have", "find related work".
  Loads and searches the consolidated index of all 233 sessions from cto-bolt, cto-coolify,
  cto-employees, test agents plus skills and memory banks.
version: 1.0.0
---

# Agent Memory Search

Search across all indexed agent sessions, learnings, memory banks, and skills.

## Index Location
`/root/.hermes/memory/agent-sessions/`

## Index Files

| File | Contents |
|------|----------|
| `session-index.json` | 233 sessions with metadata |
| `search-index.json` | Full search index of all sessions |
| `learnings-index.json` | Learning files from agents |
| `memory-bank-index.json` | Memory bank locations |
| `consolidated-learnings.md` | All learnings consolidated |
| `consolidated-memory.md` | Memory banks consolidated |
| `all-memory-files.md` | All memory files dump |
| `skills-index.json` | 187 available skills |

## Usage

### Search Sessions
```python
import json

with open('/root/.hermes/memory/agent-sessions/session-index.json') as f:
    sessions = json.load(f)

# Search for keyword
keyword = "coolify"
results = [s for s in sessions if keyword.lower() in 
           str(s.get('first_user_message', '')).lower() or
           keyword.lower() in str(s.get('last_assistant_message', '')).lower()]

for r in results[:10]:
    print(f"[{r['agent']}] {r['created_at']}")
    print(f"  {r['first_user_message'][:100]}")
```

### Search Learnings
```python
with open('/root/.hermes/memory/agent-sessions/learnings-index.json') as f:
    learnings = json.load(f)
```

### Search Skills
```python
with open('/root/.hermes/memory/agent-sessions/skills-index.json') as f:
    skills = json.load(f)

# Find skill by name or category
results = [s for s in skills if 'coolify' in s['category'].lower()]
```

## Session Search Quick Command
```bash
grep -l "keyword" /root/.hermes/memory/agent-sessions/*.json
```

## Agents Indexed
- cto-bolt: 79 sessions (33 .claude + 46 .hermes)
- cto-coolify: 3 sessions
- cto-employees: 213 sessions  
- test: 2 sessions
