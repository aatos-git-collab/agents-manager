/**
 * routes/seals.ts - .seal management routes
 */

import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import * as db from '../db/index.js';
import { createSeal } from '../security/seal.js';

const router = Router();

/**
 * POST /seal/create
 * Create a .seal entry for an agent.
 * The per-agent key is raw random bytes stored as base64 in the DB.
 * The API returns perAgentSeal = base64(raw_key) for the agent to use.
 */
router.post('/create', async (req: Request, res: Response) => {
  if (process.env.VAULT_MODE !== 'root') {
    return res.status(403).json({ error: 'Seal creation is root-only' });
  }

  const { sealName, agentId } = req.body as { sealName?: string; agentId?: string };
  if (!sealName) return res.status(400).json({ error: 'sealName required' });

  // Generate raw random key bytes (16 bytes)
  const rawKeyBytes = crypto.randomBytes(16);

  // perAgentSeal = base64(rawKeyBytes) — safe for JSON transport
  const perAgentSeal = rawKeyBytes.toString('base64');

  // Build .seal bytes: encrypt(rawKeyBytes, MASTER_ROOT_SEAL)
  const rootSeal = process.env.MASTER_ROOT_SEAL ?? '';
  const sealData = createSeal(rawKeyBytes, rootSeal);
  const sealB64  = sealData.toString('base64');

  // Store: sealB64 = .seal, per_key_b64 = base64(rawKeyBytes)
  await db.sealCreate(sealName, agentId ?? sealName, sealB64, perAgentSeal);

  return res.status(201).json({
    sealName,
    agentId:  agentId ?? sealName,
    sealB64,            // base64(.seal) — for two-factor root decryption
    perAgentSeal,       // base64(raw key) — agent uses this to decrypt anc
    message: 'Store perAgentSeal securely in agent env. Use /seal/pull/:name to retrieve .seal.',
  });
});

/**
 * GET /seal/pull/:sealName
 * Pull .seal b64 for an agent.
 */
router.get('/pull/:sealName', async (req: Request, res: Response) => {
  const seal = await db.sealPull(req.params.sealName as string);
  if (!seal) return res.status(404).json({ error: 'Seal not found' });

  return res.json({
    sealName: seal.sealName,
    agentId:  seal.agentId,
    sealB64:  seal.sealB64,
    perAgentSeal: seal.perKeyB64,
    message: 'Write sealB64 to temp file for decryption. Delete after use.',
  });
});

/**
 * GET /seal/list
 * List all seals.
 */
router.get('/list', async (_req: Request, res: Response) => {
  const seals = await db.sealList();
  return res.json({
    seals: seals.map(s => ({
      sealName:  s.sealName,
      agentId:   s.agentId,
      createdAt: s.createdAt?.toISOString(),
      isActive:  s.isActive,
    })),
  });
});

/**
 * POST /seal/revoke/:sealName
 * Revoke a seal.
 */
router.post('/revoke/:sealName', async (req: Request, res: Response) => {
  if (process.env.VAULT_MODE !== 'root') {
    return res.status(403).json({ error: 'Root only' });
  }
  const revoked = await db.sealRevoke(req.params.sealName as string);
  if (!revoked) return res.status(404).json({ error: 'Seal not found' });
  return res.json({ sealName: req.params.sealName as string, revoked: true });
});

export default router;
