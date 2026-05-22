---
name: webbuilder-backend
description: Backend implementation guide for AI WebBuilder. Covers service architecture, DB schema, Docker integration, TypeScript patterns, and testing.
---



# WebBuilder Backend Implementation Guide

## Stack
- **Runtime**: Node 22+ (ESM — `"type": "module"` in package.json, mandatory)
- **Framework**: Fastify 5.x
- **Database**: PostgreSQL 15 (node-pg-migrate)
- **Queue**: Redis 7
- **Container**: Dockerode → Docker-in-Docker (dind sidecar, NOT host socket)
- **Build**: TypeScript → `tsc` (NodeNext module resolution)

## Compile & test (Docker-only)
```bash
cd backend && pnpm install && pnpm build
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml up --build
```

## DB Schema (authoritative: `infra/schema.sql`)
```
users → sessions
users → projects → code_diffs, builds, containers, chat_messages
users → templates
job_queue (stand-alone, no FK to avoid cascade issues)
plans, audit_log, api_keys, notifications
```

### code_diffs (per-file, RFC 6902 JSON Patch)
```sql
file_path VARCHAR(1024), operation VARCHAR(20), diff_json JSONB, content_base64 TEXT
UNIQUE(project_id, file_path, version)
```

### job_queue payload shapes (jsonb)
```
build:       {type:'build', projectId, buildId}
apply_diff:  {type:'apply_diff', projectId, diffId}
cleanup:     {type:'cleanup', projectId?, containerId?}
publish:     {type:'publish', projectId}
```

## Service patterns

### Docker-in-Docker connection
```typescript
const tls = process.env.DOCKER_TLS_CERTDIR ? {
  ca: readFileSync(join(process.env.DOCKER_TLS_CERTDIR, 'ca.pem')),
  cert: readFileSync(join(process.env.DOCKER_TLS_CERTDIR, 'cert.pem')),
  key: readFileSync(join(process.env.DOCKER_TLS_CERTDIR, 'key.pem')),
} : undefined;
this.docker = new Docker({ host: dockerHost, tls: tls ? { ...tls } : undefined });
```
**IMPORTANT**: Spread TLS object: `{ host: dockerHost, ...tls }` — never pass TLS as nested object.

### ContainerManager.getOrCreateContainer
Returns `{ containerId: string, workDir: string }` — NOT a Dockerode Container object.

### DiffService.createDiff signature (v1.1+)
```typescript
createDiff(
  projectId: string,
  filePath: string,
  operation: 'PATCH' | 'CREATE' | 'DELETE',
  diffJson: JsonPatch[],       // RFC 6902 operations
  contentBase64?: string,     // for CREATE operations
  message?: string
): Promise<CodeDiff>
```

### SSE streaming (Fastify)
```typescript
// req.raw is http.IncomingMessage — use ac.signal for abort
const ac = new AbortController();
req.raw.on('close', () => ac.abort());

reply.raw.writeHead(200, { 'Content-Type': 'text/event-stream', ... });
// Use pipeline(stream, sseWriter) with a Writable transform
// SSE format: "data: {json}\n\n"
```

## Common mistakes (avoid these)

1. **`readFileSync` from 'path'`** → must be from 'fs'
2. **`container.config`** → use `info.Config` (capital C) on ContainerInspectInfo
3. **Dockerode `.push()`** → use Promise API: `docker.push(name, cb)` → wrap in Promise
4. **`docker.buildImage`** → returns a Promise<Writable>, not a callback pattern
5. **`noUnusedLocals: true`** → always remove unused imports and variables before building
6. **`getOrCreateContainer`** → returns `{containerId, workDir}`, not a Container with `.workDir`
7. **Migrations use .js with CommonJS exports** → node-pg-migrate expects `exports.up(pgm)` and `exports.down(pgm)`, not ESM
8. **ContainerManager.createContainer signature** → `createContainer(projectId, workDir, baseImage, options?)` where baseImage is required (e.g., 'node:22-alpine' or 'vibe-starter:latest')
9. **PreviewService.createContainer** → needs baseImage as 3rd argument (use 'node:22-alpine' for preview containers)
10. **Worker healthcheck** → use process alive check, NOT HTTP endpoint (Docker can probe via `docker kill --signal=0`)

## Build flow patterns

- **vibe-starter location**: `/home/cto-bolt/AI-WebBuilder/vibe-starter` (bind-mounted at `/vibe-starter` in container)
- **Project workDir**: `/workspace/projects/{projectId}/`
- **Build command**: `npm run build` (runs `next build`)
- **Build flow**: cloneBaseTemplate → applyDiffs → build → startServer → return preview URL
- **handleApplyDiffJob**: applies JSON Patch to correct file, no rebuild needed for PATCH ops

## Environment variables
```
POSTGRES_PASSWORD, REDIS_PASSWORD, API_SECRET_KEY, JWT_SECRET
ANTHROPIC_API_KEY, OPENAI_API_KEY
DOCKER_HOST=tcp://dind:2376, DOCKER_TLS_CERTDIR=/certs
REGISTRY_URL, REGISTRY_USERNAME, REGISTRY_PASSWORD
```
## Quick Commands
- `skill-load webbuilder-backend` — Load this skill
