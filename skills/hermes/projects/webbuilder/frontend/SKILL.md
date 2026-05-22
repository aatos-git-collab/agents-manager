---
name: webbuilder-frontend
description: Frontend implementation guide for AI WebBuilder SaaS app. Next.js 14 app router, Zustand state, shadcn/ui, streaming SSE, and vibe-starter integration.
---



# WebBuilder Frontend Guide

## Stack
- **Framework**: Next.js 14 (App Router, TypeScript)
- **State**: Zustand
- **UI**: shadcn/ui + Tailwind CSS
- **Styling**: CSS variables (no hardcoded colors)
- **API client**: fetch with SSE streaming

## File organization
```
frontend/src/
  app/                    # Next.js App Router pages
  components/
    ui/                   # shadcn components (button, input, dialog, etc.)
    builder/              # Builder-specific: Editor, Preview, FileTree, Chat
    dashboard/            # Dashboard, ProjectCard, PlanBadge
  lib/
    api.ts                # Typed fetch helpers
    utils.ts               # cn(), formatters
    constants.ts
  stores/
    builderStore.ts        # Zustand: current project, selected file, preview URL
    userStore.ts           # user session, plan limits
  types/
    index.ts               # Project, CodeDiff, Build, ChatMessage, Plan types
```

## Key types (mirrored from backend)
```typescript
interface Project {
  id: string; slug: string; name: string; plan: 'free'|'pro'|'team';
  createdAt: string; updatedAt: string;
}
interface CodeDiff {
  id: string; projectId: string; filePath: string;
  operation: 'PATCH' | 'CREATE' | 'DELETE';
  diffJson: JsonPatch[];  // RFC 6902 — NOT the raw content
  version: number; message: string; createdAt: string;
}
interface ChatMessage {
  id: string; role: 'user'|'assistant'; content: string; createdAt: string;
}
```

## JSON Patch (RFC 6902) from backend
Backend stores PATCH operations as `diffJson`. Frontend receives per-file patches:
```typescript
// Example diffJson received from GET /api/diffs/:projectId
[{ op: 'replace', path: '/lines/0', value: 'import...' }]
```
Apply with `fast-json-patch` library:
```typescript
import { applyPatch } from 'fast-json-patch';
const result = applyPatch(existingContent, diff.diffJson);
```

## SSE streaming (POST /api/chat/:projectId/send)
```typescript
const res = await fetch(`/api/chat/${projectId}/send`, {
  method: 'POST',
  body: JSON.stringify({ message }),
  headers: { 'Content-Type': 'application/json' },
});
const reader = res.body!.getReader();
while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  const text = new TextDecoder().decode(value);
  // parse SSE: "data: {json}\n\n"
  for (const line of text.split('\n')) {
    if (!line.startsWith('data: ')) continue;
    const event = JSON.parse(line.slice(6));
    if (event.token) appendToken(event.token);
    if (event.done) finalizeMessage();
  }
}
```

## vibe-starter integration
Frontend does NOT clone vibe-starter directly — it delegates to the backend worker.
Flow:
1. User creates project → frontend POST /api/projects → backend creates project
2. Backend pulls vibe-starter base image → starts container
3. Frontend polls GET /api/projects/:id/status or uses SSE for container_ready event
4. Chat/editor sends diffs → backend applies JSON Patch → rebuilds

## Environment variables
```
NEXT_PUBLIC_API_URL   # http://builder-api:3000 (Docker) or http://localhost:3000 (dev)
NEXT_PUBLIC_APP_URL   # http://localhost (SaaS domain)
NEXT_PUBLIC_WS_URL    # ws://builder-api:3000 (for future live collaboration)
```
## Quick Commands
- `skill-load webbuilder-frontend` — Load this skill
