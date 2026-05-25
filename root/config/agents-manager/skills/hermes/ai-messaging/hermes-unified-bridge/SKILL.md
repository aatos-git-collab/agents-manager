---
name: hermes-unified-bridge
description: Connect Hermes agents to Mattermost (team chat) and OpenWebUI (chat UI) via unified bridge
---

# Hermes Unified Bridge

## Architecture
```
Mattermost ──WebSocket──→ Hermes Gateway ──┬─→ Agent Brain
                                           └─→ API Server (:8088) ←── OpenWebUI
```

## Components

### Mattermost Bot (WebSocket)
- **Adapter**: `/root/hermes-agent/gateway/platforms/mattermost.py`
- **Env vars** in `/root/.hermes/.env`:
  - `MATTERMOST_URL=https://mm.dash.nexeraa.io`
  - `MATTERMOST_TOKEN=<bot-token>`
  - `MATTERMOST_HOME_CHANNEL=<channel-id>`

### Hermes API Server (OpenAI-compatible)
- **Env vars** in `/root/.hermes/.env`:
  - `API_SERVER_ENABLED=true`
  - `API_SERVER_KEY=<key>`
  - `API_SERVER_PORT=8088`
  - `API_SERVER_HOST=0.0.0.0`
  - `API_SERVER_CORS_ORIGINS=*`

### OpenWebUI
- **Compose**: `/root/.hermes/open-webui/docker-compose.yml`
- **URL**: `http://89.167.96.223:8080`
- **Config**: `OPENAI_API_BASE_URL=http://host.docker.internal:8088/v1`

## Setup Steps

### 1. Create Mattermost Bot Account
1. Open `https://mm.dash.nexeraa.io` → System Console → Integrations → Bot Accounts
2. Add Bot: username=`hermes`, enable Post All/Channels
3. Copy **Token**

### 2. Get Channel ID
1. In Mattermost, go to desired channel
2. Click channel name → View Info
3. Copy **Channel ID**

### 3. Configure + Restart Gateway
```bash
# Edit /root/.hermes/.env - add:
# MATTERMOST_URL, MATTERMOST_TOKEN, MATTERMOST_HOME_CHANNEL
# API_SERVER_ENABLED, API_SERVER_KEY, API_SERVER_PORT

hermes gateway restart
```

### 4. Start OpenWebUI
```bash
cd /root/.hermes/open-webui && docker compose up -d
```

## Verify
```bash
# Mattermost token valid?
curl -s -H "Authorization: <token>" https://mm.dash.nexeraa.io/api/v4/users/me

# Hermes API responding?
curl -s -X POST http://localhost:8088/v1/chat/completions \
  -H "Authorization: Bearer <API_SERVER_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"model":"test","messages":[{"role":"user","content":"hi"}]}'

# Gateway status
cat /root/.hermes/gateway_state.json | python3 -m json.tool
```
## Quick Commands
- `skill-load hermes-unified-bridge` — Load this skill
