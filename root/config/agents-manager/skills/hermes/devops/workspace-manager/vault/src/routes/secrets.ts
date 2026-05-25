/**
 * routes/secrets.ts - Secret management + encrypt/decrypt routes
 */

import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import path from 'path';
import * as db from '../db/index.js';
import { encryptString } from '../security/vault.js';
import { base64Decode } from '../security/vault-utils.js';
import { unpack } from '../security/anc.js';
import { decrypt } from '../security/cipher.js';
import type { SecretType } from '../types/index.js';

const router = Router();

// ─── Helper ───────────────────────────────────────────────────────────────────

function masterRootSeal(): string {
  const seal = process.env.MASTER_ROOT_SEAL ?? '';
  if (!seal) throw new Error('MASTER_ROOT_SEAL not configured');
  return seal;
}

function ensureRoot(req: Request, res: Response): boolean {
  if (process.env.VAULT_MODE !== 'root') {
    res.status(403).json({ error: 'Root-only operation' });
    return false;
  }
  return true;
}

function getAncDir(): string {
  return process.env.VAULT_ANC_DIR ?? '/opt/vault/anc';
}

// ─── Encrypt ───────────────────────────────────────────────────────────────────

/**
 * POST /encrypt
 * Two-factor encrypt a string secret.
 */
router.post('/', async (req: Request, res: Response) => {
  if (!ensureRoot(req, res)) return;

  const {
    name,
    plaintext,
    sealName = 'default',
    secretType = 'generic',
    metadata = {},
    creatorTag = 'root',
  } = req.body as {
    name?: string;
    plaintext?: string;
    sealName?: string;
    secretType?: SecretType;
    metadata?: Record<string, unknown>;
    creatorTag?: string;
  };

  if (!name || !plaintext || plaintext.trim() === '') {
    return res.status(400).json({ error: 'name and plaintext are required' });
  }

  // Global seal model: encrypt with GLOBAL_MASTER_SEAL for agent access.
  // The agent uses GLOBAL_MASTER_SEAL directly (no per-agent key needed).
  // Two-factor seal layer is still created for manual recovery (MASTER_ROOT_SEAL).
  const globalSeal = process.env.GLOBAL_MASTER_SEAL;
  if (!globalSeal) {
    return res.status(500).json({ error: 'GLOBAL_MASTER_SEAL not configured on vault-api' });
  }

  // Look up per-agent seal from DB (still needed to validate sealName exists)
  const seal = await db.sealPull(sealName);
  if (!seal) {
    return res.status(400).json({ error: `Seal "${sealName}" not found. Create it first with /seal/create` });
  }

  // Two-factor encrypt: plaintext → encrypt(plaintext, GLOBAL_MASTER_SEAL) → .anc
  //   The seal layer stores GLOBAL_MASTER_SEAL (wrapped by MASTER_ROOT_SEAL)
  //   so two-factor decrypt recovers GLOBAL_MASTER_SEAL and can decrypt .anc
  const { anc: ancB64, seal: sealB64 } = encryptString(plaintext, globalSeal, masterRootSeal());

  // Store .anc to disk
  const secretId = crypto.randomUUID();
  const ancPath  = path.join(getAncDir(), `${secretId}.anc`);
  const fs = await import('fs');
  fs.writeFileSync(ancPath, base64Decode(ancB64));
  fs.chmodSync(ancPath, 0o400);

  // Save to DB (includes seal_b64 for two-factor decrypt)
  await db.secretCreate({
    id: secretId,
    name,
    secretType,
    ancPath,
    ancB64,
    sealB64,
    sealName,
    metadata,
    creatorTag,
  });

  return res.status(201).json({
    secretId,
    name,
    secretType,
    sealName,
    ancB64,
    ancPath,
    createdAt: new Date().toISOString(),
    message: 'Store ancB64 securely. Needed to decrypt.',
  });
});

// ─── Decrypt ──────────────────────────────────────────────────────────────────

/**
 * POST /decrypt
 * Two-factor decrypt using ancB64 + sealB64 + MASTER_ROOT_SEAL.
 */
router.post('/decrypt', async (req: Request, res: Response) => {
  const { decryptString } = await import('../security/vault.js');
  const { ancB64, sealB64 } = req.body as { ancB64?: string; sealB64?: string };

  if (!ancB64 || !sealB64) {
    return res.status(400).json({ error: 'ancB64 and sealB64 required' });
  }

  try {
    const plaintext = decryptString(ancB64, sealB64, masterRootSeal());
    return res.json({ plaintext, decryptedAt: new Date().toISOString() });
  } catch (e) {
    return res.status(401).json({ error: `Decryption failed: ${(e as Error).message}` });
  }
});

/**
 * POST /decrypt/agent
 * Agent decryption using GLOBAL_MASTER_SEAL (no per-agent key from request body).
 * Uses the vault-api's GLOBAL_MASTER_SEAL env var for all agent decrypts.
 */
router.post('/decrypt/agent', async (req: Request, res: Response) => {
  const { secretId } = req.body as { secretId?: string };

  if (!secretId) {
    return res.status(400).json({ error: 'secretId required' });
  }

  const globalSeal = process.env.GLOBAL_MASTER_SEAL;
  if (!globalSeal) {
    return res.status(500).json({ error: 'GLOBAL_MASTER_SEAL not configured on vault-api' });
  }

  const secret = await db.secretGetById(secretId);
  if (!secret) return res.status(404).json({ error: 'Secret not found' });

  try {
    const ancData = base64Decode(secret.ancB64!);
    const { ciphertext, salt, nonce } = unpack(ancData);
    const plaintext = decrypt(ciphertext, globalSeal, salt, nonce);
    return res.json({ plaintext: plaintext.toString('utf8'), decryptedAt: new Date().toISOString() });
  } catch (e) {
    return res.status(401).json({ error: `Decryption failed: ${(e as Error).message}` });
  }
});

// ─── Secrets list / get / delete ────────────────────────────────────────────

router.get('/', async (_req: Request, res: Response) => {
  const secrets = await db.secretList();
  return res.json({
    secrets: secrets.map(s => ({
      id:          s.id,
      name:        s.name,
      secretType:  s.secretType,
      sealName:    s.sealName,
      createdAt:   s.createdAt?.toISOString(),
      updatedAt:   s.updatedAt?.toISOString(),
      metadata:    s.metadata,
      creatorTag:  s.creatorTag,
    })),
  });
});

router.get('/:id', async (req: Request, res: Response) => {
  const secret = await db.secretGetById(req.params.id as string);
  if (!secret) return res.status(404).json({ error: 'Not found' });
  return res.json({
    id:         secret.id,
    name:       secret.name,
    secretType: secret.secretType,
    ancPath:    secret.ancPath,
    ancB64:     secret.ancB64,
    sealName:   secret.sealName,
    createdAt:  secret.createdAt?.toISOString(),
    updatedAt:  secret.updatedAt?.toISOString(),
    metadata:   secret.metadata,
    creatorTag: secret.creatorTag,
  });
});

router.delete('/:id', async (req: Request, res: Response) => {
  if (!ensureRoot(req, res)) return;
  const secret = await db.secretGetById(req.params.id as string);
  if (!secret) return res.status(404).json({ error: 'Not found' });
  try {
    const fs = await import('fs');
    fs.unlinkSync(secret.ancPath);
  } catch { /* file may not exist */ }
  await db.secretDelete(req.params.id as string);
  return res.json({ deleted: req.params.id as string });
});

export default router;
