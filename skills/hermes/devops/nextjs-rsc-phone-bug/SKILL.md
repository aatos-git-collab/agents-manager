---
name: nextjs-rsc-phone-bug
description: Fix ReferenceError in Next.js RSC Docker deployments when using lucide-react icons in server components.
triggers:
  - Phone is not defined
  - Next.js RSC icon not defined
  - lucide-react server component Docker
  - ReferenceError server chunk
  - bare identifier in server chunk
---

# Next.js RSC: Phone is not defined Bug Fix

## Symptom

`ReferenceError: Phone is not defined` during Docker container startup. Locally `pnpm dev` works fine. Error appears in Docker logs repeatedly and in CI/CD build prerendering (e.g. `/services` page fails to build).

## Root Cause

Next.js RSC compiler bug — specific lucide-react icon usages in server components get compiled as **bare identifiers** (e.g., `(0,d.jsx)(Phone,{className:"w-4 h-4"})`) instead of proper namespace access (e.g., `(0,d.jsx)(h.A,{...})`).

At runtime in Docker's Node.js server, `Phone` is not in scope because:
1. lucide-react has ESM-only exports — `import {Phone} from 'lucide-react'` works with ESM but not CJS
2. Next.js RSC server bundles create isolated module contexts where the namespace import mapping doesn't propagate correctly
3. The compiled output references `Phone` as a bare variable name never declared in that scope

The bug affects **any marketing page** that uses lucide-react `Phone` — not just Footer. All of these were broken:
- `app/(marketing)/page.tsx`
- `app/(marketing)/about/page.tsx`
- `app/(marketing)/services/page.tsx`
- `app/(marketing)/services/[slug]/page.tsx`
- `app/(marketing)/contact/page.tsx`
- `components/shared/Header.tsx`
- `components/shared/Footer.tsx`
- `components/chatbot/ChatWidget.tsx`

## Diagnosis

```bash
# Search all TSX files for bare Phone identifier (not part of PhoneIcon)
grep -rn 'Phone[^a-zA-Z]' --include="*.tsx" .

# Search for lucide-react imports that include Phone
grep -rn "from 'lucide-react'.*Phone\|import.*Phone.*from 'lucide-react'" --include="*.tsx" .

# In compiled chunk (after build):
python3 -c "
import re
data = open('.next/server/chunks/269.js').read()
matches = [m.start() for m in re.finditer(r'\bPhone\b', data)]
print(f'Bare Phone refs: {len(matches)}')
for pos in matches:
    print(f'  pos {pos}: {data[max(0,pos-60):pos+60]}')
"
```

## Fix: Create Shared PhoneIcon Component

Create `components/shared/PhoneIcon.tsx`:
```tsx
export function PhoneIcon({ className = 'w-5 h-5' }: { className?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
    </svg>
  );
}
```

## Fix: Replace Phone in Every File

For each affected file, replace:
```tsx
// BEFORE:
import { Phone, MessageCircle } from 'lucide-react';
<Phone className="w-5 h-5" />

// AFTER:
import { MessageCircle } from 'lucide-react';  // Phone removed from import
import { PhoneIcon } from '@/components/shared/PhoneIcon';
<PhoneIcon className="w-5 h-5" />
```

**Files to update:**
1. `app/(marketing)/page.tsx` — 2 instances
2. `app/(marketing)/about/page.tsx` — 2 instances (including icon map)
3. `app/(marketing)/services/page.tsx` — 1 instance
4. `app/(marketing)/services/[slug]/page.tsx` — 1 instance
5. `app/(marketing)/contact/page.tsx` — 1 instance
6. `components/shared/Header.tsx` — 1 instance
7. `components/shared/Footer.tsx` — 3 icons (Phone, MapPin, MessageCircle)
8. `components/chatbot/ChatWidget.tsx` — 1 instance (inline PhoneIcon defined locally)

## Also: Root Layout

`app/layout.tsx` — add at top:
```tsx
export const dynamic = 'force-dynamic';
```
Skips static prerendering entirely — all pages render on-demand, preventing build-time prerender errors.

## Why Inline SVGs Work

Inline SVGs have no external module dependency. The Next.js RSC compiler handles them correctly because they are pure JSX — not imported identifiers from ESM-only packages with inconsistent CJS/ESM export maps.

## Prevention

- After adding any lucide-react icon to a shared/marketing component, run the bare-identifier diagnostic above
- For shared components rendered by both server and client, always use inline SVGs
- Test `pnpm build` before deploying — look for `ReferenceError` in any prerendering output
## Quick Commands
- `skill-load nextjs-rsc-phone-bug` — Load this skill
