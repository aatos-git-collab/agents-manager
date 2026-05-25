---
name: aatos-ai-employees-project
description: Multi-agent group chat platform for docker-to-docker SaaS
---

# AI-Employees Multi-Agent Group Chat Platform

## Project Overview
Transform `/root/AI-Employees/open-webui` (OpenWebUI fork) into a multi-agent group chat SaaS platform with Docker-to-Docker communication to `/root/AI-Employees/hermes-agent`.

## Key Paths
- OpenWebUI workspace: `/root/AI-Employees/open-webui/`
- Hermes agent codebase: `/root/AI-Employees/hermes-agent/`
- SOUL templates: `/root/AI-Employees/hermes-agent/skills/agent-brains/{role}/SOUL.md`

## Build Rule
- `/root/AI-Employees/` project code → ALWAYS in CODEBASE (`/root/AI-Employees/hermes-agent/` or `/root/AI-Employees/open-webui/`)
- Local runtime skills → `/root/.hermes/`

## Architecture

### What's Built (2026-04-05)
| File | Status | Purpose |
|------|--------|---------|
| `backend/open_webui/utils/mentions.py` | ✅ | @mention parser |
| `backend/open_webui/utils/agentic_bus.py` | ✅ | Typing events, SSE agent_id injection |
| `backend/open_webui/utils/soul_loader.py` | ✅ | Reads SOUL from agent-brains git repo |
| `backend/open_webui/utils/hermes_adapter.py` | ✅ | OpenWebUI → Hermes Agent HTTP bridge |
| `src/lib/stores/agent_typing.ts` | ✅ | Frontend typing state store |
| `src/lib/components/chat/Chat.svelte` | ✅ Modified | `agent:typing` event handler |
| `src/lib/components/app/NewChatGroupModal.svelte` | ✅ | 3-mode modal (Single/Group/Team) |
| `backend/open_webui/routers/openai.py` | ✅ Modified | SOUL injection, typing events |

### Pending
1. **Multi-agent fan-out routing** — fan out to multiple Hermes agents in parallel
2. **Agent session management** — start/kill/manage Hermes sessions per chat
3. **Hermes gateway API** — add `/api/sessions/start`, `/api/chat`, etc to hermes-agent
4. **Docker compose** — local dev with both services
5. **Frontend agents panel** — right sidebar: top=agents, bottom=files

### Docker Communication
```
OpenWebUI container (:8080) → HTTP → Hermes Agent container (:8081)
Env vars: HERMES_AGENT_URL, HERMES_GATEWAY_TOKEN
```

## Hermes Adapter API
- `init(base_url, token)` — configure
- `health_check()` → bool
- `start_agent(agent_id, agent_name, chat_id, soul_role, tools)` → session_id
- `stop_agent(session_id)` → bool
- `send_message_stream(session_id, message, context, agent_id)` → AsyncGenerator[bytes]
- `build_context(chat_id, chat_history, files, system_prompt)` → dict

## SOUL Templates
Path: `/root/AI-Employees/hermes-agent/skills/agent-brains/{role}/SOUL.md`
Roles: ceo, cto, cfo, cmo, coo, cso, grant-cardone, jordan-belfort, talent-architect, zig-ziglar

## Agentic Bus API
- `extract_mentions(text)` → list[str]
- `get_target_agents(text, available_agents)` → list[dict]
- `emit_agent_typing(agent_id, status, chat_id)`  # 'thinking'|'responding'|'idle'
- `agentic_stream_wrapper(generator, agent_id)` → AsyncGenerator[bytes]

## Frontend
`src/lib/stores/agent_typing.ts` — `setAgentTyping(agentId, status)` | status: 'thinking'|'responding'|'idle'
## Quick Commands
- `skill-load aatos-ai-employees-project` — Load this skill
