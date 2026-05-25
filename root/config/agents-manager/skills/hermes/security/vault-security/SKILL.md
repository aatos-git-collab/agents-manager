---
name: vault-security
description: Two-factor encryption vault for AI agent secrets — ChaCha20-Poly1305, per-secret seals, vault-api + isolated-agent model. Source code, architecture, API reference, and troubleshooting.
triggers:
  - vault-security
  - two-factor encryption
  - secrets management for agents
  - vault api
  - chaCha20
category: security
---

# vault-security — Two-Factor Encryption Vault for AI Agents

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ vault-api (:8443) — Root-only, TLS, PostgreSQL              │
│  ├── POST /seal/create  → registers sealName, stores perKeyB64│
│  ├── POST /secrets      → encrypts with GLOBAL_MASTER_SEAL   │
│  ├── POST /decrypt      → two-factor using stored sealB64    │
│  └── POST /decrypt/agent → decrypts for agent (GLOBAL_MASTER_SEAL)│
└──────────────────────────────────────────────────────────────┘
            │
            │  Agent mode: isolated
            ▼
┌──────────────────────────────────────────────────────────────┐
│ isolated-agent (:8444) — uses GLOBAL_MASTER_SEAL directly    │
│  └── POST /decrypt → decrypts secretId without per-agent key │
└──────────────────────────────────────────────────────────────┘
```

## Two-Factor Encryption

```
ENCRYPT (vault-api):
  plaintext → ChaCha20-Poly1305(GLOBAL_MASTER_SEAL, salt=AAD) → .anc
  GLOBAL_MASTER_SEAL → ChaCha20-Poly1305(MASTER_ROOT_SEAL, salt=AAD) → .seal

DECRYPT path 1 — Agent direct:
  secret.ancB64 + GLOBAL_MASTER_SEAL → plaintext (no DB needed)

DECRYPT path 2 — Vault two-factor:
  secret.sealB64 (DB) → GLOBAL_MASTER_SEAL → key → secret.ancB64 → plaintext
```

## Source Code

**Vault works in-place** from skill source (no /opt, no intermediate copy):

```
skills/devops/workspace-manager/vault/
├── src/
│   ├── vault-api/     ← TypeScript vault-api
│   │   ├── security/  ← cipher.ts, vault.ts, seal.ts, anc.ts
│   │   ├── routes/    ← secrets.ts, decrypt.ts, seals.ts
│   │   └── app.ts     ← Express + startup
│   └── isolated-agent/ ← agent.js (decrypt-only)
├── docker/
│   └── docker-compose.yml  ← vault-api + vault-postgres + isolated-agent
└── scripts/
    ├── vault-install.sh    ← Build + start from skill source
    ├── vault-self-heal.sh ← Health check + repair
    └── create-agent.sh    ← Bootstrap new isolated agent
```

## API Reference

### POST /seal/create
Create per-agent seal (registers sealName in vault).
```json
Request:  { "sealName": "alice", "agentId": "alice" }
Response: { "sealName": "alice", "perAgentSeal": "base64(sealData)" }
```

### POST /secrets
Encrypt and store a secret.
```json
Request:  { "name": "api-key", "plaintext": "sk-123", "sealName": "alice", "secretType": "api-key" }
Response: { "secretId": "uuid", "ancB64": "..." }
```

### POST /decrypt/agent
Agent decrypt — uses GLOBAL_MASTER_SEAL directly.
```json
Request:  { "secretId": "uuid" }
Response: { "plaintext": "sk-123" }
```

### POST /decrypt (vault-api)
Two-factor decrypt — uses per-secret sealB64 from DB.
```json
Request:  { "secretId": "uuid" }
Response: { "plaintext": "sk-123" }
```

### GET /seal/pull/:sealName
Get stored sealData for a sealName (for two-factor recovery).
```json
Response: { "sealName": "alice", "sealB64": "base64(sealData)" }
```

## Environment Variables

| Variable | Value | Purpose |
|---|---|---|
| `GLOBAL_MASTER_SEAL` | `dev-root-seal-change-in-production` | Encrypts all secrets |
| `MASTER_ROOT_SEAL` | `dev-root-seal-change-in-production` | Wraps GLOBAL_MASTER_SEAL in seal layer |
| `VAULT_DB_HOST` | `vault-postgres` | PostgreSQL host |
| `VAULT_DB_NAME` | `vaultdb` | Database name |
| `VAULT_DB_USER` | `vaultuser` | Database user |
| `VAULT_DB_PASS` | `vaultpass` | Database password |
| `PORT` | `8443` | vault-api TLS port |
| `ISOLATED_AGENT_PORT` | `8444` | Isolated agent TLS port |

## Database Schema

```sql
-- Per-agent seals (registers sealNames)
CREATE TABLE seal_registry (
  seal_name   VARCHAR(255) UNIQUE PRIMARY KEY,
  agent_id    VARCHAR(255),
  seal_b64    TEXT,       -- encrypt(perKeyBytes, GLOBAL_MASTER_SEAL)
  per_key_b64 TEXT        -- base64(raw 16-byte key)
);

-- Secrets (per-secret sealB64 for two-factor decrypt)
CREATE TABLE secrets (
  id          UUID PRIMARY KEY,
  name        TEXT NOT NULL,
  secret_type TEXT DEFAULT 'generic',
  anc_path    TEXT NOT NULL,
  anc_b64     TEXT,
  seal_b64    TEXT,       -- base64(.seal) for this secret
  seal_name   VARCHAR(255),
  metadata    JSONB DEFAULT '{}',
  creator_tag TEXT
);
```

## Security Model

- **Root agent** (vault-api): full vault management — create seals, encrypt, two-factor decrypt
- **Isolated agent** (port 8444): decrypt-only using GLOBAL_MASTER_SEAL — cannot encrypt, cannot create seals
- **Two-factor**: .anc (encrypted content) + .seal (encrypted key stored in DB)
- **Defense**: isolated agent CANNOT reach vault-api endpoints — network isolation enforced by docker compose

## Setup

```bash
cd /opt/vault-security/docker
docker compose up -d --build

# Verify
curl https://localhost:8443/health
curl https://localhost:8444/health
```

## Troubleshooting

1. **"Unsupported state" on decrypt**: TypeScript cipher missing `setAAD(salt)` — fix cipher.ts
2. **Two-factor decrypt 401**: `seal_b64` not mapped in `rowToSecret()` — add `sealB64: row.seal_b64`
3. **seal_b64 column missing**: Postgres volume not fresh — `docker compose down -v && up -d`
4. **Migration fails**: `initDb()` must run BEFORE migrations in app.ts startup order
5. **Agent decrypt 401**: Agent doesn't have correct GLOBAL_MASTER_SEAL — check env var
## Quick Commands
- `skill-load vault-security` — Load this skill
