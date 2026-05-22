---
name: vault-decrypt-tool
description: Isolated agent decryption tool — decrypt secrets, licenses, and API keys retrieved from vault-api. DECRYPTION ONLY — cannot encrypt
category: security
---

# vault-decrypt-tool

Isolated agent's **decryption-only** tool. Cannot encrypt — only decrypts secrets via vault-api.

## Architecture

```
isolated-agent container
│
├── /app/seals/agent.seal     ← .seal file (read-only mount)
├── AGENT_SEAL_KEY            ← env var (the agent's root key)
│
└── vault-agent (decryption client)
    ├── decrypt_secret()       → decrypt by secret_id
    ├── decrypt_license()      → decrypt + validate license
    ├── decrypt_apikey()       → decrypt API key
    └── list_secrets()         → list available secrets
        │
        └── vault-api (proxy decrypt)
            └── vault-postgres (stores .anc)
```

**Security Model:**
- Isolated agent has **NO MASTER-ROOT-SEAL**
- Decryption goes through vault-api which holds MASTER-ROOT-SEAL
- Agent sends `.seal_b64` + `agent_seal_key` to prove identity
- Plaintext is returned but **never persisted to disk**

## Prerequisites
- vault-api running and healthy
- Agent provisioned with `.seal` file and `AGENT_SEAL_KEY`

## Environment
```bash
VAULT_API_URL=https://vault-api:8443
AGENT_SEAL_FILE=/app/seals/agent.seal
AGENT_SEAL_KEY=<from provisioning>
```

## CLI Usage

### Show Agent Info
```bash
python3 /app/app.py --info
```

### List Available Secrets
```bash
python3 /app/app.py --list
```

### Decrypt a Secret
```bash
# By secret_id
python3 /app/app.py --decrypt <secret_id>

# Raw .anc blob (ad-hoc)
python3 /app/app.py --decrypt-string <anc_b64>
```

### Decrypt and Validate a License
```bash
python3 /app/app.py --license <license_id>
```

### Decrypt an API Key
```bash
python3 /app/app.py --apikey <apikey_id>
```

## Python API

```python
from agent import decrypt_secret, decrypt_license, decrypt_apikey, list_secrets

# List what secrets you can access
secrets = list_secrets()

# Decrypt a secret
result = decrypt_secret('secret-uuid')
plaintext = result['plaintext']

# Decrypt a license and validate
license = decrypt_license('license-uuid')
if license['valid']:
    features = license['payload']['features']
    expires = license['payload'].get('expires_at')

# Decrypt an API key
apikey = decrypt_apikey('apikey-uuid')
api_key = apikey['api_key']
```

## Security Guarantees

| Property | Guarantee |
|----------|-----------|
| No encryption | Agent cannot create new secrets |
| No master key | MASTER-ROOT-SEAL never in agent container |
| Memory only | Plaintext decrypted in-memory, never written to disk |
| Seal-gated | Each agent can only decrypt secrets with matching seal_name |
| Revocable | Deleting secret from DB immediately blocks access |

## Limitations

- **No `--encrypt` flag** — intentional, by design
- **No `--seal-create`** — only root can provision new seals
- **No direct DB access** — must go through vault-api
- **Network required** — needs vault-api to be reachable

## Docker Integration

In docker-compose, each isolated agent gets:
```yaml
volumes:
  - ./agent-seals/agent-1.seal:/app/seals/agent.seal:ro
environment:
  - AGENT_SEAL_PASSWORD=${AGENT_SEAL_KEY}
```

The `:ro` mount means the seal file is **read-only** from the agent's perspective.
## Quick Commands
- `skill-load vault-decrypt-tool` — Load this skill
