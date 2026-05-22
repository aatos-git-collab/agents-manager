---
name: vault-decrypt
description: "Decrypt secrets using isolated vault-agent or vault-api. Agent holds GLOBAL_MASTER_SEAL — can decrypt but not encrypt, create seals, or manage vault."
triggers:
  - "decrypt a secret"
  - "get the api key value"
  - "use a sealed secret"
  - "decrypt from vault"
category: security
---

# vault-decrypt

Isolated agent skill for decrypting secrets using `GLOBAL_MASTER_SEAL`.

## Architecture

```
Agent (isolated):  decrypt(secret.ancB64, GLOBAL_MASTER_SEAL)
                   → plaintext (no DB lookup needed)

Vault-api (two-factor):  decrypt(secret.sealB64, GLOBAL_MASTER_SEAL) → .anc key
                         decrypt(secret.ancB64, key) → plaintext
```

## Two Decryption Paths

### Path 1 — Agent Direct (fastest, recommended)
Agent decrypts using `GLOBAL_MASTER_SEAL` directly (no per-secret seal lookup needed):
```bash
curl -s -X POST https://localhost:8444/decrypt \
  -H "Content-Type: application/json" \
  -d '{"secretId":"<uuid>"}'
```
Agent must have `GLOBAL_MASTER_SEAL` env var set.

### Path 2 — Vault Two-Factor (recovery mode)
Vault-api uses stored per-secret `.seal` from DB:
```bash
curl -s -X POST https://localhost:8443/decrypt \
  -H "Content-Type: application/json" \
  -d '{"secretId":"<uuid>"}'
```
This is for recovery when agent doesn't have GLOBAL_MASTER_SEAL.

## Prerequisites
- Agent: `ISOLATED_AGENT_PORT=8444` and `GLOBAL_MASTER_SEAL` env var set
- Vault-api: running at http://localhost:8443

## Usage

### Agent decrypt endpoint (:8444)
```bash
curl -s -X POST http://localhost:8444/decrypt \
  -H "Content-Type: application/json" \
  -d '{"secretId":"<uuid>"}'
```
Response: `{ "plaintext": "...", "decryptedAt": "..." }`

### Health check (agent)
```bash
curl -s http://localhost:8444/health
# Should return: {"status":"ok","agentMode":"isolated",...}
```

## Security Rules
1. NEVER log, repeat, or include plaintext values in responses
2. NEVER store decrypted values in conversation context or memory
3. Decrypted values exist only in runtime memory for task duration
4. Agent CANNOT call `/encrypt`, `/seal/create`, or `/secrets` — these do not exist on isolated-agent
5. Agent cannot create new seals or encrypt new secrets

## Error Responses
| Status | Meaning |
|--------|---------|
| 400 | Missing or empty secretId |
| 401 | Decryption failed (wrong key or corrupted data) |
| 404 | Secret not found or not accessible |
| 502 | Vault API unreachable |
