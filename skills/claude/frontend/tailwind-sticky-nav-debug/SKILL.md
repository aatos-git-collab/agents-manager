---
name: tailwind-sticky-nav-debug
description: Debug CSS sticky nav issues in Next.js/Tailwind — margin collapsing breaks sticky positioning
triggers:
  - "nav stuck to top"
  - "sticky not working"
  - "desktop nav not floating"
  - "header negative margin breaks sticky"
---

# Tailwind Sticky Nav Debug

## Problem
Desktop nav using `sticky top-4` appears "stuck to top" immediately instead of floating. Mobile nav works. Site is Next.js + Tailwind.

## Root Cause
Negative margin (`-mb-4 !important`) on the Header in the layout collapses the margin of the header's parent, breaking the scroll stacking context that `position: sticky` depends on.

## Fix (in order of trial)
1. **Remove negative margins on Header** — `className="-mb-4 !important"` in `MarketingLayout` was the culprit. Remove it first.
2. **Reduce top offset** — `top-4` → `top-2` (smaller gap)
3. **Separate mobile/desktop nav** — Both mobile and desktop navs using `sticky` in same scroll context causes conflicts. Mobile: `sticky top-0`, Desktop: `sticky top-2` (or `static` to scroll away)

## Anti-Patterns
- ✗ Do NOT apply negative margins (`-mb-`, `-mt-`, etc.) to Header/Layout elements when nav uses `position: sticky`
- ✗ Do NOT use `!important` to force negative margins — it overrides everything and breaks sticky
- ✗ Do NOT have both mobile and desktop sticky navs in the same scroll context

## Correct Pattern
```tsx
// layout.tsx — NO negative margins on Header
<Header />  // no className="-mb-4 !important"

// LandingHeader.tsx — desktop
<nav className="sticky top-2 left-0 right-0 z-50 backdrop-blur-xl ...">

// LandingHeader.tsx — mobile (separate element, md:hidden)
<nav className="md:hidden sticky top-0 ...">
```

## File Locations
- `/root/pawnshop/app/(marketing)/layout.tsx`
- `/root/pawnshop/components/landing/navigation/LandingHeader.tsx`
- `/root/pawnshop/components/shared/Header.tsx`

## Verification
After fix: Desktop nav should float 2px from top when scrolled. Mobile nav should pin to top immediately. Both should be independent.
## Quick Commands
- `skill-load tailwind-sticky-nav-debug` — Load this skill
