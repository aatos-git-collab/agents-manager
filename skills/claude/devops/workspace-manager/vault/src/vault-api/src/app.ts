/**
 * app.ts - Vault API entry point
 * HTTPS server with self-signed cert in dev, real cert in prod
 */

import express, { Router } from 'express';
import cors from 'cors';
import https from 'https';
import fs from 'fs';
import { initDb, migrateAddPerKeyB64 } from './db/index.js';
import sealsRouter   from './routes/seals.js';
import secretsRouter from './routes/secrets.js';
import decryptRouter from './routes/decrypt.js';

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Health
app.get('/health', (_req, res) => {
  res.json({
    status:    'ok',
    vaultMode: process.env.VAULT_MODE ?? 'root',
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use('/seal',    sealsRouter);
app.use('/secrets', secretsRouter);
app.use('/decrypt', decryptRouter);

// ─── Init dirs ──────────────────────────────────────────────────────────────

function initDirs(): void {
  const ancDir  = process.env.VAULT_ANC_DIR  ?? '/opt/vault/anc';
  const sealDir = process.env.VAULT_SEAL_DIR ?? '/opt/vault/seals';
  fs.mkdirSync(ancDir,  { recursive: true, mode: 0o700 });
  fs.mkdirSync(sealDir, { recursive: true, mode: 0o700 });
}

// ─── HTTPS server ──────────────────────────────────────────────────────────

function getSslOptions(): { key: string | Buffer; cert: string | Buffer } | null {
  const key  = process.env.SSL_KEY;
  const cert = process.env.SSL_CERT;
  if (key && cert && fs.existsSync(key) && fs.existsSync(cert)) {
    return { key: fs.readFileSync(key), cert: fs.readFileSync(cert) };
  }
  return null;
}

async function main(): Promise<void> {
  initDirs();
  await initDb();
  await migrateAddPerKeyB64();

  const port = parseInt(process.env.PORT ?? '8443');
  const ssl = getSslOptions();

  if (ssl) {
    const server = https.createServer(ssl, app);
    server.listen(port, '0.0.0.0', () => {
      console.log(`vault-api (HTTPS) running on https://0.0.0.0:${port}`);
    });
  } else {
    // Dev: HTTP only, log warning
    app.listen(port, '0.0.0.0', () => {
      console.warn(`WARNING: vault-api running on HTTP (no SSL)`);
      console.log(`vault-api (HTTP) running on http://0.0.0.0:${port}`);
    });
  }

  console.log(`VAULT_MODE=${process.env.VAULT_MODE ?? 'root'}`);
}

main().catch(err => {
  console.error('Failed to start:', err);
  process.exit(1);
});

export default app;
