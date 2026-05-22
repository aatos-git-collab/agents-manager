---
name: mattermost-api
description: "Complete Mattermost Web Services API v4 integration. Full REST API coverage for channels, posts, users, bots, and more."
---

# Mattermost API v4 Skill 💬

Complete reference for Mattermost Web Services API v4. Base URL: `your-mattermost-url/api/v4`

---

## API Token Setup

### Adding Bot Token

To add a bot/Mattermost API token:

```bash
# Add Mattermost channel with bot token
```

### Token Storage

Tokens are stored in environment variables or a credentials file.

### Required Permissions

Bot token needs:
- `read_user_access_token` — Read user info
- `write_user_access_token` — Manage own tokens
- `read_channel` — Read channels
- `write_channel` — Create channels
- `read_post` — Read messages
- `write_post` — Post messages

---

## Authentication

### Creating Bot Accounts

**Via Mattermost UI (Admin):**
1. Go to Mattermost System Console
2. Users → Create User → Select "Bot"
3. Set username, display name
4. Copy the bot token

**Via API:**
```bash
# Create bot user
curl -X POST https://your-mattermost.com/api/v4/users \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "cfo-bot@yourcompany.com",
    "username": "cfo-bot",
    "first_name": "CFO",
    "last_name": "Bot",
    "password": "secure-password",
    "roles": "system_user"
  }'

# Then create bot account
curl -X POST https://your-mattermost.com/api/v4/bots \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "cfo-bot",
    "display_name": "CFO Bot",
    "description": "CFO Agent for financial operations"
  }'
```

### Getting Bot Token

Once bot is created:
1. Go to Mattermost → Account Settings → Security → Personal Access Tokens
2. Create new token for bot
3. Copy the token

---

## Using the Token

### Session Token
```bash
# Login
POST /api/v4/users/login
Body: {"login_id": "email@.com", "password": "pass", "token": "mfa_code"}

# Get token from response header, then use:
Header: Authorization: Bearer <token>
```

### Personal Access Token
```bash
Header: Authorization: Bearer <personal_access_token>
```

### WebSocket
```bash
# Connect to /api/v4/websocket
# Authenticate with:
{"seq": 1, "action": "authentication_challenge", "data": {"token": "<token>"}}
```

## Base Conventions

- All requests: `application/json`
- Use `me` instead of user ID for current user
- Pagination: max 200 items/page, default 60
- Rate limit headers: `X-Ratelimit-Limit`, `X-Ratelimit-Remaining`, `X-Ratelimit-Reset`

---

## API Endpoints by Category

### USERS (`/api/v4/users`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/users/login` | Login user |
| POST | `/users/logout` | Logout |
| GET | `/users` | List users |
| GET | `/users/{user_id}` | Get user |
| GET | `/users/me` | Get current user |
| PUT | `/users/{user_id}` | Update user |
| DELETE | `/users/{user_id}` | Delete user |
| POST | `/users/{user_id}/sessions/revoke` | Revoke session |
| GET | `/users/{user_id}/groups` | Get user's groups |

### CHANNELS (`/api/v4/channels`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/channels` | List all channels |
| POST | `/channels` | Create channel |
| GET | `/channels/{channel_id}` | Get channel |
| PUT | `/channels/{channel_id}` | Update channel |
| DELETE | `/channels/{channel_id}` | Delete (archive) channel |
| PATCH | `/channels/{channel_id}/patch` | Patch channel |
| PUT | `/channels/{channel_id}/privacy` | Change privacy (O/P) |
| POST | `/channels/{channel_id}/restore` | Restore channel |
| POST | `/channels/{channel_id}/move` | Move to team |
| GET | `/channels/{channel_id}/stats` | Get channel stats |

**Channel Types:** `O` = Public, `P` = Private

**Create Channel Body:**
```json
{
  "team_id": "required",
  "name": "unique-handle",
  "display_name": "Display Name",
  "purpose": "Channel purpose",
  "header": "Markdown header",
  "type": "O" or "P"
}
```

### Direct/Group Messages

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/channels/direct` | Create DM (2 users) |
| POST | `/channels/group` | Create group message (3-8 users) |
| POST | `/channels/group/search` | Search group channels |

### POSTS (`/api/v4/posts`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/posts` | Create post |
| GET | `/posts/{post_id}` | Get post |
| PUT | `/posts/{post_id}` | Update post |
| DELETE | `/posts/{post_id}` | Delete post |
| PATCH | `/posts/{post_id}/patch` | Patch post |
| GET | `/posts/{post_id}/thread` | Get thread |
| GET | `/channels/{channel_id}/posts` | Get channel posts |
| POST | `/teams/{team_id}/posts/search` | Search posts |

**Create Post Body:**
```json
{
  "channel_id": "required",
  "message": "Markdown content",
  "root_id": "parent_post_id (for replies)",
  "file_ids": ["file_id_array"],
  "props": {"key": "custom_props"},
  "metadata": {"priority": {"priority": "important"}}
}
```

### REACTIONS (`/api/v4/reactions`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/reactions` | Add reaction |
| DELETE | `/reactions/{user_id}/{post_id}/{emoji_name}` | Remove reaction |
| GET | `/posts/{post_id}/reactions` | Get post reactions |

### TEAMS (`/api/v4/teams`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/teams` | List teams |
| POST | `/teams` | Create team |
| GET | `/teams/{team_id}` | Get team |
| PUT | `/teams/{team_id}` | Update team |
| DELETE | `/teams/{team_id}` | Delete team |
| GET | `/teams/{team_id}/channels` | Get team channels |
| GET | `/teams/{team_id}/members` | Get team members |

### STATUS (`/api/v4/status`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users/{user_id}/status` | Get user status |
| PUT | `/users/{user_id}/status` | Set user status |
| GET | `/users/status/ids` | Get statuses by IDs |

**Status Values:** `online`, `away`, `dnd`, `offline`

### PREFERENCES (`/api/v4/users/{user_id}/preferences`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/preferences` | Get user preferences |
| PUT | `/preferences` | Update preferences |
| DELETE | `/preferences/{category}/{name}` | Delete preference |

### FILES (`/api/v4/files`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/files` | Upload file |
| GET | `/files/{file_id}` | Get file info |
| GET | `/files/{file_id}/get` | Download file |
| DELETE | `/files/{file_id}` | Delete file |

### WEBHOOKS (`/api/v4/webhooks`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/webhooks/incoming` | Create incoming webhook |
| POST | `/webhooks/outgoing` | Create outgoing webhook |
| GET | `/webhooks/{hook_id}` | Get webhook |
| DELETE | `/webhooks/{hook_id}` | Delete webhook |

### COMMANDS (`/api/v4/commands`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/commands` | Create command |
| GET | `/commands/{command_id}` | Get command |
| PUT | `/commands/{command_id}` | Update command |
| DELETE | `/commands/{command_id}` | Delete command |

### BOT ACCOUNTS (`/api/v4/bots`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/bots` | List bots |
| POST | `/bots` | Create bot |
| GET | `/bots/{bot_id}` | Get bot |
| PUT | `/bots/{bot_id}` | Update bot |
| DELETE | `/bots/{bot_id}` | Disable bot |

### EMOJI (`/api/v4/emoji`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/emoji` | List custom emoji |
| POST | `/emoji` | Create custom emoji |
| GET | `/emoji/{emoji_id}` | Get emoji |
| DELETE | `/emoji/{emoji_id}` | Delete emoji |

### SYSTEM (`/api/v4/system`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/system/ping` | Health check |
| GET | `/system/config` | Get config (admin) |
| PUT | `/system/config` | Update config (admin) |

### PLUGINS (`/api/v4/plugins`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/plugins` | List plugins |
| POST | `/plugins` | Install plugin |
| DELETE | `/plugins/{plugin_id}` | Remove plugin |

---

## WebSocket Events

### Common Events

| Event | Description |
|-------|-------------|
| `posted` | New post created |
| `post_edited` | Post updated |
| `post_deleted` | Post deleted |
| `reaction_added` | Reaction added |
| `reaction_removed` | Reaction removed |
| `typing` | User typing |
| `status_change` | User status changed |
| `channel_created` | Channel created |
| `channel_deleted` | Channel deleted |
| `user_added` | User added to team/channel |
| `user_removed` | User removed |
| `memberrole_updated` | Member role changed |

---

## Error Handling

All errors return:
```json
{
  "id": "error.id",
  "message": "Human readable message",
  "request_id": "request_id",
  "status_code": 400,
  "is_oauth": false
}
```

### Common Error Codes

| Code | Meaning |
|------|---------|
| 400 | Bad request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not found |
| 413 | Payload too large |
| 429 | Rate limit exceeded |

---

## Integration

The `message` tool handles:
- ✅ Send messages
- ✅ React (emoji)
- ✅ Create polls
- ✅ Delete/edit messages

For advanced API calls, can use `exec` with curl to Mattermost server.

---

**API Source:** https://github.com/mattermost/mattermost/tree/master/api/v4  
**Docs:** https://developers.mattermost.com/api-reference

---

## Using the Token

# Add Mattermost channel with bot token
mattermost channels add --channel mattermost --token <BOT_TOKEN>
```



---

## Creating Channels

### Create Channel for Agent
```bash
curl -X POST https://your-mattermost.com/api/v4/channels \
  -H "Authorization: Bearer <BOT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "cfo-office",
    "display_name": "CFO Office",
    "purpose": "CFO agent operations",
    "type": "P",
    "team_id": "your-team-id"
  }'
```

### Get Team ID
```bash
curl -X GET https://your-mattermost.com/api/v4/teams \
  -H "Authorization: Bearer <BOT_TOKEN>"
```


---

## Environment Variable Setup

### Adding via Environment Variables

You can also configure API tokens via environment variables for agents:



### For Mattermost Bot Tokens



### Setting Environment Variables

```bash
# Set for current session
export MATTERMOST_BOT_TOKEN="your-bot-token-here"
export MATTERMOST_URL="https://your-mattermost.com"


```

### Using in Skills

```bash
# Access token in scripts
curl -X POST "$MATTERMOST_URL/api/v4/channels" \
  -H "Authorization: Bearer $MATTERMOST_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "new-channel", "display_name": "New Channel", "type": "O"}'
```
## Quick Commands
- `skill-load mattermost-api` — Load this skill
