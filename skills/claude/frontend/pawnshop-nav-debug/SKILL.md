---
name: pawnshop-nav-debug
description: Debug pawnshop navigation issues — isolate desktop vs mobile before touching any CSS
category: frontend
tags: [pawnshop, nav, sticky, mobile, desktop]
version: 1.0.0
created: 2026-04-25
---

# Pawnshop Nav Debug — CRITICAL RULE

**The single most expensive mistake: changing mobile nav CSS when user reports desktop nav broken.**

---

## Golden Rule

When user reports a nav issue, **always ask which viewport** (mobile / desktop / both) before changing anything. The fix for desktop is never the same as mobile.

---

## Desktop Nav — LandingHeader.tsx

The desktop nav lives inside `<div className="hidden md:block">` and uses:
```tsx
className={clsx(
  'flex items-center justify-between gap-6 p-4 mx-auto w-[90%] lg:rounded-2xl',
  fixed ? 'sticky top-4 left-0 right-0 z-50 backdrop-blur-xl' : '',
  ...
)}
```
- `sticky top-4` = floats 4px below viewport top, sticks on scroll
- `rounded-2xl` = pill-shaped corners
- `backdrop-blur-xl` = frosted glass
- `w-[90%]` = 90% width with auto margins (centered)

**If desktop nav appears stuck to top immediately**: this is how `sticky` works — it sticks when the element reaches `top-4`. This is CORRECT behavior.

**If desktop nav is not floating/sticky at all**: check if `fixed=false` is being passed from `Header.tsx` (line 13: `fixed` prop is `true`).

---

## Mobile Nav — LandingHeader.tsx

The mobile nav lives inside the outer `<nav>` (no `hidden md:block` wrapper) and uses:
```tsx
className={clsx(
  'md:hidden sticky top-0 left-0 right-0 z-50 w-full backdrop-blur-xl border-b border-zinc-100 dark:border-zinc-800',
  fixed ? 'bg-white/90 dark:bg-slate-950/90' : '',
  className,
)}
```
- `sticky top-0` = sticks to very top of viewport on mobile
- This is CORRECT for mobile — it should stay visible as user scrolls

**DO NOT change `sticky top-0` to `relative` on mobile nav.** That removes all sticky behavior and breaks mobile UX.

---

## Debug Checklist

Before changing any nav CSS:

1. **Which viewport is broken?** (mobile / desktop / both)
2. **What is the expected behavior?** (floating pill / sticky top / scrolls away)
3. **What does the current CSS do?** (read LandingHeader.tsx lines 36-99)
4. **What commit/state was working?** (check `git log --oneline`)
5. **Is the issue in the parent layout?** (`app/(marketing)/layout.tsx` wraps with `-mb-4`)

---

## If Desktop Nav Is NOT Sticking

1. Check if `fixed=true` prop is being passed from `Header.tsx` line 13
2. Check if parent has `overflow-hidden` which breaks sticky
3. Check if `top-4` is being overridden somewhere

## If Mobile Nav Is NOT Sticking

1. Mobile should use `sticky top-0` — do NOT change to `relative`
2. If mobile nav disappears on scroll, that IS the bug (not sticky)

---

## Relevant Files

- `/root/pawnshop/components/landing/navigation/LandingHeader.tsx` — nav component
- `/root/pawnshop/components/shared/Header.tsx` — passes `fixed=true` + logo + nav items
- `/root/pawnshop/app/(marketing)/layout.tsx` — wraps with `Header className="-mb-4"`
- Git history: `c89db2f` (mobile chat panel + sticky header) — confirms sticky is intentional

## Relevant Commits

- `c89db2f` — introduced sticky full-width header (both mobile + desktop)
- `110a3d8` — shop built, LandingHeader unchanged
## Quick Commands
- `skill-load pawnshop-nav-debug` — Load this skill
