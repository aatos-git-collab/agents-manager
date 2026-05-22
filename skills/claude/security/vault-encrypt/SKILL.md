---
name: vault-encrypt
description: "Encrypt and store secrets in vault using two-factor encryption (root agent only). Encrypts with GLOBAL_MASTER_SEAL, stores per-secret seal for recovery."
triggers:
  - "encrypt a secret"
  - "store an api key"
  - "seal a secret"
  - "encrypt to vault"
category: security
---

# vault-encrypt

Root-only skill for encrypting and storing secrets in vault.

## Architecture

```
plaintext → ChaCha20-Poly1305(GLOBAL_MASTER_SEAL, salt=AAD) → .anc
GLOBAL_MASTER_SEAL → ChaCha20-Poly1305(MASTER_ROOT_SEAL, salt=AAD) → .seal (stored in DB)
```

## Prerequisites
- vault-api running at http://localhost:8443
- `GLOBAL_MASTER_SEAL` and `MASTER_ROOT_SEAL` env vars set
- `VAULT_MODE=root` (root agent only)

## Workflow

### Step 1: Create agent seal (registers sealName in vault)
```bash
curl -s -X POST https://localhost:8443/seal/create \
  -H "Content-Type: application/json" \
  -d '{"sealName":"my-agent","agentId":"my-agent"}'
```
Response: `{ "sealName": "my-agent", "perAgentSeal": "base64(sealData)" }`

The `perAgentSeal` is the agent's personal seal (encrypted with per-agent key). Give to agent via env var `PER_AGENT_SEAL`.

### Step 2: Encrypt and store the secret
```bash
curl -s -X POST https://localhost:8443/secrets \
  -H "Content-Type: application/json" \
  -d '{"name":"my-api-key","plaintext":"sk-...","sealName":"my-agent","secretType":"api-key"}'
```
Response: `{ "secretId": "uuid", "ancB64": "...", "name": "my-api-key" }`

Store the `secretId` — agents use this to request decryption.

## Two-Factor Decryption

Anyone with GLOBAL_MASTER_SEAL can decrypt directly. For recovery without GLOBAL_MASTER_SEAL:
```bash
curl -s -X POST https://localhost:8443/decrypt \
  -H "Content-Type: application/json" \
  -d '{"secretId":"<uuid>"}'
```
Uses the per-secret `.seal` stored in DB (encrypted with MASTER_ROOT_SEAL).

## Security Notes
- Never log or repeat plaintext values
- Two-factor: `.anc` (encrypted content) + `.seal` stored in DB (encrypted key)
- Agent only gets `GLOBAL_MASTER_SEAL` or `PER_AGENT_SEAL` — can decrypt but not re-encrypt other secrets
- Vault rejects unauthorized agents — only registered sealNames can encrypt

## Verification
```bash
curl -s https://localhost:8443/health
# Should return: {"status":"ok","vaultMode":"root",...}
```
## Quick Commands
- `skill-load vault-encrypt` — Load this skill
