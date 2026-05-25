/**
 * db/index.ts - PostgreSQL database layer
 */

import { Pool } from 'pg';
import type { Seal, Secret, SecretType } from '../types/index.js';

const pool = new Pool({
  host:     process.env.VAULT_DB_HOST ?? 'localhost',
  port:     parseInt(process.env.VAULT_DB_PORT ?? '5432'),
  database: process.env.VAULT_DB_NAME ?? 'vaultdb',
  user:     process.env.VAULT_DB_USER ?? 'vaultuser',
  password: process.env.VAULT_DB_PASS ?? '',
});

export async function initDb(): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS seal_registry (
        id          SERIAL PRIMARY KEY,
        seal_name   VARCHAR(255) UNIQUE NOT NULL,
        agent_id    VARCHAR(255),
        seal_b64    TEXT NOT NULL,   -- base64(.seal) = encrypt(key_bytes, rootSeal)
        per_key_b64 TEXT NOT NULL,   -- base64(key_bytes) = actual key for anc encryption
        created_at  TIMESTAMP DEFAULT NOW(),
        is_active   BOOLEAN DEFAULT TRUE,
        metadata    JSONB DEFAULT '{}'
      )
    `);
    await client.query(`
      CREATE TABLE IF NOT EXISTS secrets (
        id          UUID PRIMARY KEY,
        name        TEXT NOT NULL,
        secret_type TEXT NOT NULL DEFAULT 'generic',
        anc_path    TEXT NOT NULL,
        anc_b64     TEXT,
        seal_b64    TEXT,    -- base64(.seal) for this specific secret (for two-factor decrypt)
        seal_name   VARCHAR(255),
        created_at  TIMESTAMP DEFAULT NOW(),
        updated_at  TIMESTAMP DEFAULT NOW(),
        metadata    JSONB DEFAULT '{}',
        creator_tag TEXT
      )
    `);
    // Add seal_b64 column if it doesn't exist (for existing databases)
    await client.query(`ALTER TABLE secrets ADD COLUMN IF NOT EXISTS seal_b64 TEXT`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_secrets_name    ON secrets(name)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_secrets_type    ON secrets(secret_type)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_secrets_seal    ON secrets(seal_name)`);
  } finally {
    client.release();
  }
}

// Migrate: add per_key_b64 column if it doesn't exist (existing seals need it)
export async function migrateAddPerKeyB64(): Promise<void> {
  const client = await pool.connect();
  try {
    // Check if column exists
    const result = await client.query(`
      SELECT column_name FROM information_schema.columns
      WHERE table_name='seal_registry' AND column_name='per_key_b64'
    `);
    if (result.rows.length === 0) {
      await client.query(`ALTER TABLE seal_registry ADD COLUMN per_key_b64 TEXT NOT NULL DEFAULT ''`);
      await client.query(`UPDATE seal_registry SET per_key_b64=seal_b64 WHERE per_key_b64=''`);
    }
  } finally {
    client.release();
  }
}

// ─── Seal operations ───────────────────────────────────────────────────────────

export async function sealCreate(
  sealName: string,
  agentId: string,
  sealB64: string,
  perKeyB64: string   // base64(key bytes)
): Promise<Seal> {
  const result = await pool.query(
    `INSERT INTO seal_registry (seal_name, agent_id, seal_b64, per_key_b64)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (seal_name) DO UPDATE
       SET agent_id    = EXCLUDED.agent_id,
           seal_b64    = EXCLUDED.seal_b64,
           per_key_b64 = EXCLUDED.per_key_b64,
           is_active   = TRUE
     RETURNING *`,
    [sealName, agentId, sealB64, perKeyB64]
  );
  return rowToSeal(result.rows[0]);
}

export async function sealPull(sealName: string): Promise<Seal | null> {
  const result = await pool.query(
    `SELECT * FROM seal_registry WHERE seal_name = $1 AND is_active = TRUE`,
    [sealName]
  );
  return result.rows[0] ? rowToSeal(result.rows[0]) : null;
}

export async function sealList(): Promise<Seal[]> {
  const result = await pool.query(
    `SELECT seal_name, agent_id, created_at, is_active FROM seal_registry ORDER BY created_at`
  );
  return result.rows.map(r => ({
    sealName:   r.seal_name,
    agentId:    r.agent_id,
    createdAt:  r.created_at,
    isActive:   r.is_active,
  }));
}

export async function sealRevoke(sealName: string): Promise<boolean> {
  const result = await pool.query(
    `UPDATE seal_registry SET is_active = FALSE WHERE seal_name = $1`,
    [sealName]
  );
  return (result.rowCount ?? 0) > 0;
}

// ─── Secret operations ──────────────────────────────────────────────────────────

export async function secretCreate(params: {
  id: string;
  name: string;
  secretType: SecretType;
  ancPath: string;
  ancB64: string;
  sealB64: string;   // base64(.seal) for two-factor decrypt
  sealName: string;
  metadata?: Record<string, unknown>;
  creatorTag?: string;
}): Promise<Secret> {
  const result = await pool.query(
    `INSERT INTO secrets (id, name, secret_type, anc_path, anc_b64, seal_b64, seal_name, metadata, creator_tag)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING *`,
    [
      params.id,
      params.name,
      params.secretType,
      params.ancPath,
      params.ancB64,
      params.sealB64,
      params.sealName,
      JSON.stringify(params.metadata ?? {}),
      params.creatorTag ?? 'root',
    ]
  );
  return rowToSecret(result.rows[0]);
}

export async function secretGetById(id: string): Promise<Secret | null> {
  const result = await pool.query(`SELECT * FROM secrets WHERE id = $1`, [id]);
  return result.rows[0] ? rowToSecret(result.rows[0]) : null;
}

export async function secretDelete(id: string): Promise<boolean> {
  const result = await pool.query(`DELETE FROM secrets WHERE id = $1`, [id]);
  return (result.rowCount ?? 0) > 0;
}

export async function secretList(limit = 100): Promise<Secret[]> {
  const result = await pool.query(
    `SELECT id, name, secret_type, seal_name, created_at, updated_at, metadata, creator_tag
     FROM secrets ORDER BY created_at DESC LIMIT $1`,
    [limit]
  );
  return result.rows.map(rowToSecret);
}

// ─── Mappers ───────────────────────────────────────────────────────────────────

function rowToSeal(row: Record<string, unknown>): Seal {
  return {
    id:         row.id as number,
    sealName:   row.seal_name as string,
    agentId:    row.agent_id as string,
    sealB64:    row.seal_b64 as string | undefined,
    perKeyB64:  row.per_key_b64 as string | undefined,
    createdAt:  row.created_at as Date,
    isActive:   row.is_active as boolean,
    metadata:   row.metadata as Record<string, unknown>,
  };
}

function rowToSecret(row: Record<string, unknown>): Secret {
  return {
    id:         row.id as string,
    name:       row.name as string,
    secretType: row.secret_type as SecretType,
    ancPath:    row.anc_path as string,
    ancB64:     row.anc_b64 as string | undefined,
    sealB64:    row.seal_b64 as string | undefined,  // for two-factor decrypt
    sealName:   row.seal_name as string,
    createdAt:  row.created_at as Date,
    updatedAt:  row.updated_at as Date,
    metadata:   row.metadata as Record<string, unknown>,
    creatorTag: row.creator_tag as string,
  };
}

export { pool };
