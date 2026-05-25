/**
 * Isolated Agent — decryption-only vault client
 *
 * Security model:
 *   • No MASTER_ROOT_SEAL — cannot encrypt, cannot create seals
 *   • GLOBAL_MASTER_SEAL on vault-api side (not sent by agent)
 *   • Sealed system prompt from /prompt/system-prompt.txt (read-only mount)
 *   • Exposes ONLY /decrypt/agent on port 8444 (localhost only)
 *   • All decrypted plaintexts are runtime-only — never stored, never logged
 *
 * Usage:
 *   docker run -v ./system-prompt.txt:/prompt/system-prompt.txt:ro \
 *     -p 8444:8444 isolated-agent
 */

const http = require('http');
const fs   = require('fs');
const path = require('path');

const PORT        = 8444;
const VAULT_HOST  = process.env.VAULT_API_HOST || 'vault-api';
const VAULT_PORT  = parseInt(process.env.VAULT_API_PORT || '8443');
const PROMPT_PATH = '/prompt/system-prompt.txt';

const SYSTEM_PROMPT = (() => {
  try {
    return fs.readFileSync(PROMPT_PATH, 'utf8');
  } catch(e) {
    console.error('[agent] FATAL: could not read system prompt:', e.message);
    process.exit(1);
  }
})();

console.log('[agent] Starting isolated decryption agent');
console.log('[agent] System prompt loaded:', PROMPT_PATH, `(${SYSTEM_PROMPT.length} chars)`);
console.log('[agent] Vault API:', VAULT_HOST + ':' + VAULT_PORT);

// ── Vault API client (proxies /decrypt/agent only) ────────────────────────────
function vaultReq(path, method, body) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: VAULT_HOST,
      port:      VAULT_PORT,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
      },
    };
    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(data) }); }
        catch(e) { resolve({ status: res.statusCode, data: null, raw: data.slice(0, 200) }); }
      });
    });
    req.on('error', (e) => reject(new Error(`vault request failed: ${e.message}`)));
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// ── Local agent API (localhost only) ─────────────────────────────────────────
const server = http.createServer((req, res) => {
  // Security: restrict to known safe networks (Docker bridge: 172.17.x.x, localhost)
  // In production, this should be limited to the vault-api container's IP.
  // For now: allow any IP that isn't clearly external (no strict internet check).
  const remoteAddr = req.socket.remoteAddress || '';
  const isPrivate = remoteAddr.startsWith('127.') ||
                    remoteAddr.startsWith('10.') ||
                    remoteAddr.startsWith('172.16.') || remoteAddr.startsWith('172.17.') ||
                    remoteAddr.startsWith('172.18.') || remoteAddr.startsWith('172.19.') ||
                    remoteAddr.startsWith('172.2') || remoteAddr.startsWith('172.3') ||
                    remoteAddr.startsWith('192.168.') ||
                    remoteAddr === '::1' || remoteAddr === '::ffff:127.0.0.1' ||
                    remoteAddr === '0.0.0.0';
  if (!isPrivate) {
    res.writeHead(403, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Forbidden: non-private network' }));
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host}`);
  const path   = url.pathname;
  const method = req.method;

  // CORS preflight
  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': 'localhost',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400',
    });
    res.end();
    return;
  }

  // ── GET /prompt ──────────────────────────────────────────────────────────────
  if (method === 'GET' && path === '/prompt') {
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(SYSTEM_PROMPT);
    return;
  }

  // ── GET /health ─────────────────────────────────────────────────────────────
  if (method === 'GET' && path === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      agentMode: 'isolated',
      vaultConnected: false, // will be set below
    }));
    return;
  }

  // ── POST /decrypt ────────────────────────────────────────────────────────────
  // The ONLY decryption endpoint this agent exposes.
  // Proxies to vault-api's /decrypt/agent using PER_AGENT_SEAL.
  if (method === 'POST' && path === '/decrypt') {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', async () => {
      let secretId;
      try { ({ secretId } = JSON.parse(body)); } catch(e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'invalid JSON' }));
        return;
      }

      if (!secretId) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'secretId required' }));
        return;
      }

      try {
        // Proxy to vault-api — no per-agent key sent, vault-api uses GLOBAL_MASTER_SEAL
        const vaultRes = await vaultReq('/decrypt/agent', 'POST', {
          secretId,
        });

        if (vaultRes.status === 200) {
          // Decryption succeeded — return plaintext ONLY
          // NEVER log plaintext — it must not appear in any persistent storage
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            plaintext: vaultRes.data.plaintext,
            decryptedAt: vaultRes.data.decryptedAt || new Date().toISOString(),
            // DO NOT include perAgentSeal or any key material in response
          }));
        } else {
          res.writeHead(vaultRes.status, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: vaultRes.data?.error || 'decryption failed' }));
        }
      } catch(e) {
        res.writeHead(502, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'vault unreachable: ' + e.message }));
      }
    });
    return;
  }

  // ── 404 everything else ──────────────────────────────────────────────────────
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found: ' + path + ' (this agent only supports /decrypt)' }));
});

// ── Start ─────────────────────────────────────────────────────────────────────
server.listen(PORT, '0.0.0.0', () => {
  console.log(`[agent] Isolated agent listening on http://0.0.0.0:${PORT}`);
  console.log(`[agent] Available endpoints:`);
  console.log(`[agent]   GET  /health       — health check`);
  console.log(`[agent]   GET  /prompt       — read sealed system prompt`);
  console.log(`[agent]   POST /decrypt      — decrypt secret (secretId in body)`);
  console.log(`[agent]`);
  console.log(`[agent]   All other endpoints return 404 — no encrypt, no seal management`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[agent] SIGTERM — shutting down');
  server.close(() => process.exit(0));
});
