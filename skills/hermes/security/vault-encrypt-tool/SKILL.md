---
name: vault-encrypt-tool
description: Root agent encryption and credential management tool — encrypt secrets, issue licenses, manage API keys using the vault-api service
category: security
---

# vault-encrypt-tool

Root agent's **encryption-only** tool for managing secrets, licenses, and API keys.

## Architecture

```
Root Agent (YOU)
├── MASTER-ROOT-SEAL (never leaves vault-api)
│
├── vault-api (encryption service)
│   ├── POST /encrypt         → encrypt and store secret
│   ├── POST /seal/create     → create .seal for an agent
│   ├── POST /license/issue    → issue a license
│   ├── POST /apikey/issue    → issue an API key
│   └── GET  /secrets         → list all secrets
│
└── vault-postgres (stores .anc encrypted data)
    └── Each secret has: id, name, secret_type, anc_data, seal_name
```

**Security Model:**
- `.anc` = encrypted data blob (stored in postgres)
- `.seal` = SEAL encrypted with MASTER-ROOT-SEAL (created per-agent at provisioning)
- MASTER-ROOT-SEAL = **never stored**, only in vault-api memory

**Isolation:** Isolated agents CANNOT encrypt. They can only decrypt via `/decrypt/agent` endpoint.

## Setup

### Prerequisites
- Docker & Docker Compose
- vault-api running (see `/opt/vault-security/docker/docker-compose.yml`)
- `MASTER_ROOT_SEAL` environment variable set

### Environment
```bash
# Export for local testing
export VAULT_API_URL="https://localhost:8443"
export VAULT_API_TOKEN="your-token"  # future: add auth
```

## API Reference

### Encrypt a Secret
```bash
curl -sk -X POST https://localhost:8443/encrypt \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "my-db-password",
    "secret_type": "password",
    "plaintext": "super-secret-password",
    "seal_name": "isolated-agent",
    "metadata": {"env": "production", "service": "postgres"}
  }'
```

Response:
```json
{
  "secret_id": "uuid",
  "name": "my-db-password",
  "anc_b64": "...",
  "seal_b64": "...",
  "created_at": "2026-03-31T..."
}
```

### Create Agent Seal
```bash
curl -sk -X POST https://localhost:8443/seal/create \
  -H 'Content-Type: application/json' \
  -d '{
    "seal_name": "agent-1",
    "agent_id": "coding-agent-1",
    "metadata": {"capabilities": ["decrypt"], "tier": "standard"}
  }'
```

Response:
```json
{
  "seal_name": "agent-1",
  "seal_b64": "...",
  "agent_seal_key": "b64-encoded-key",
  "message": "Store seal_b64 in agent config..."
}
```

**IMPORTANT:** Give `agent_seal_key` to the isolated agent. This is their decryption token.

### Issue a License
```bash
curl -sk -X POST https://localhost:8443/license/issue \
  -H 'Content-Type: application/json' \
  -d '{
    "payload": {
      "license_key": "PRO-XXXX-XXXX",
      "features": ["code-gen", "debug"],
      "expires_at": "2027-01-01T00:00:00Z",
      "seats": 5
    },
    "seal_name": "client-agent"
  }'
```

### Issue an API Key
```bash
curl -sk -X POST https://localhost:8443/apikey/issue \
  -H 'Content-Type: application/json' \
  -d '{
    "api_key": "sk-live-xxxxxxxxxxxx",
    "metadata": {
      "service": "openai",
      "scope": "full",
      "expires_at": "2026-12-31T00:00:00Z"
    }
  }'
```

### Batch Encrypt
```bash
curl -sk -X POST https://localhost:8443/encrypt/batch \
  -H 'Content-Type: application/json' \
  -d '{
    "seal_name": "agent-1",
    "items": [
      {"name": "db-pass", "plaintext": "pass1", "secret_type": "password"},
      {"name": "api-key", "plaintext": "key1", "secret_type": "api-key"}
    ]
  }'
```

### List Secrets
```bash
curl -sk https://localhost:8443/secrets
```

## Secret Types
| Type | Use Case |
|------|----------|
| `password` | Database passwords, service credentials |
| `ssh-key` | SSH private keys |
| `api-key` | Third-party API keys |
| `license` | Software licenses, subscription keys |
| `generic` | Any other secret value |

## Workflow: Adding a New Secret

1. **Encrypt** (root agent):
   ```
   POST /encrypt with plaintext, seal_name
   → Get back secret_id + seal_b64
   ```

2. **Distribute seal to agent**:
   ```
   POST /seal/create with agent_id
   → Get back agent_seal_key
   ```

3. **Agent stores**:
   - `agent_seal_key` → their environment variable
   - `seal_b64` → their sealed volume at `/app/seals/agent.seal`

4. **Agent decrypts** (via CLI or API):
   ```
   Isolated agent → GET /secrets (sees metadata only)
   Isolated agent → POST /decrypt/agent with secret_id
   → Receives plaintext
   ```

## Local Development
```bash
cd /opt/vault-security/docker
docker compose up -d
./scripts/setup-vault.sh
```

## Security Notes
- **Never log plaintext secrets**
- **Never commit `.env.master` or `.env.agent`** (add to `.gitignore`)
- **Rotate MASTER-ROOT-SEAL**: Create new seal, re-encrypt all secrets, distribute new seals
- **Revoke agent**: `DELETE /secrets/{id}` (removes .anc from DB, agent can't decrypt anymore)
## Quick Commands
- `skill-load vault-encrypt-tool` — Load this skill
