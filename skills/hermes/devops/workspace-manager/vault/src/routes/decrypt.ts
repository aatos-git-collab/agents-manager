/**
 * routes/decrypt.ts - Dedicated decryption routes for agents
 */

import { Router, Request, Response } from 'express';
import * as db from '../db/index.js';
import { decryptString, base64Decode } from '../security/vault.js';
import { unpack } from '../security/anc.js';
import { decrypt } from '../security/cipher.js';

const router = Router();

function masterRootSeal(): string {
  const s = process.env.MASTER_ROOT_SEAL ?? '';
  if (!s) throw new Error('MASTER_ROOT_SEAL not configured');
  return s;
}

/**
 * POST /decrypt
 * Two-factor decrypt using stored seal for this secret.
 * Looks up the per-secret sealB64 from DB by secretId.
 * Uses GLOBAL_MASTER_SEAL to unwrap the .seal layer.
 */
router.post('/', async (req: Request, res: Response) => {
  const { secretId } = req.body as { secretId?: string };

  if (!secretId) {
    return res.status(400).json({ error: 'secretId required' });
  }

  const secret = await db.secretGetById(secretId);
  if (!secret) return res.status(404).json({ error: 'Secret not found' });

  const globalSeal = process.env.GLOBAL_MASTER_SEAL;
  if (!globalSeal) {
    return res.status(500).json({ error: 'GLOBAL_MASTER_SEAL not configured' });
  }

  try {
    const plaintext = decryptString(secret.ancB64!, secret.sealB64!, globalSeal);
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
router.post('/agent', async (req: Request, res: Response) => {
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

export default router;
