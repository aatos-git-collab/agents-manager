#!/usr/bin/env node
/**
 * n8n-mcp bridge - connects Claude Code (stdio) to n8n-mcp (HTTP/SSE)
 *
 * Usage: node bridge.js [--port 3001] [--token AUTH_TOKEN]
 */

const http = require('http');
const https = require('https');

const args = process.argv.slice(2);
let port = 3001;
let token = '';
let host = '127.0.0.1';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--port' && args[i + 1]) port = args[++i];
  if (args[i] === '--token' && args[i + 1]) token = args[++i];
  if (args[i] === '--host' && args[i + 1]) host = args[++i];
}

// Read from stdin
let stdinBuffer = '';
process.stdin.setEncoding('utf8');

process.stdin.on('data', (chunk) => {
  stdinBuffer += chunk;
});

process.stdin.on('end', async () => {
  try {
    await processRequests();
  } catch (e) {
    console.error(JSON.stringify({ jsonrpc: '2.0', error: { code: -32000, message: e.message }, id: null }));
    process.exit(1);
  }
});

let sessionId = null;

async function processRequests() {
  if (!stdinBuffer.trim()) return;

  const requests = parseJSONLines(stdinBuffer);

  for (const req of requests) {
    const response = await sendRequest(req);
    if (response) {
      console.log(JSON.stringify(response));
    }
  }
}

function parseJSONLines(input) {
  const lines = input.trim().split('\n');
  const results = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed) {
      try {
        results.push(JSON.parse(trimmed));
      } catch (e) {
        // Skip non-JSON lines
      }
    }
  }
  return results;
}

function sendRequest(req) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(req);

    const options = {
      hostname: host,
      port: port,
      path: '/mcp',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
        'Authorization': `Bearer ${token}`,
        'Content-Length': Buffer.byteLength(body)
      }
    };

    // Use HTTPS if not localhost
    const client = host === 'localhost' || host === '127.0.0.1' ? http : https;

    const httpReq = client.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        // Parse SSE format: event: message\ndata: {...}\n\n
        const lines = data.split('\n');
        for (const line of lines) {
          if (line.startsWith('data: ')) {
            try {
              const jsonStr = line.substring(6);
              const result = JSON.parse(jsonStr);
              // Extract session from initialize response
              if (req.method === 'initialize' && result.result?.sessionId) {
                sessionId = result.result.sessionId;
              }
              resolve(result);
              return;
            } catch (e) {
              // Try next line
            }
          }
        }

        // Try direct JSON parse
        try {
          const result = JSON.parse(data);
          resolve(result);
        } catch (e) {
          resolve({ jsonrpc: '2.0', error: { code: -32000, message: 'Failed to parse response' }, id: req.id });
        }
      });
    });

    httpReq.on('error', (e) => {
      resolve({ jsonrpc: '2.0', error: { code: -32000, message: `Connection error: ${e.message}` }, id: req.id });
    });

    httpReq.setTimeout(30000, () => {
      httpReq.destroy();
      resolve({ jsonrpc: '2.0', error: { code: -32000, message: 'Request timeout' }, id: req.id });
    });

    httpReq.write(body);
    httpReq.end();
  });
}