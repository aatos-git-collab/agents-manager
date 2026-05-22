---
name: mobile-sticky-header-chat-panel
description: Fix mobile-first chat widget panels and sticky navigation headers in Next.js/Tailwind apps.
triggers:
  - chat widget not showing on mobile
  - mobile nav not sticky
  - mobile sheet panel not working
  - bottom sheet chat mobile
  - sticky header mobile tailwind
---

# Mobile Sticky Header + Chat Panel Fix

## Problem 1: Chat Panel Invisible on Mobile

### Symptom
Chat widget FAB works on desktop but the chat panel does not appear when tapping the chat button on mobile.

### Root Cause
The chat panel was nested inside `className="hidden md:flex"` — the entire panel (including when `isOpen=true`) was hidden on mobile by CSS.

```tsx
// BROKEN: Panel is invisible on mobile because outer wrapper hides it
<div className="hidden md:flex">
  {isOpen && <ChatPanel />}  {/* Hidden on mobile even when isOpen=true */}
</div>
```

### Fix: Full-Screen Mobile Sheet + Floating Desktop Panel

Separate the concerns — FAB is desktop-only, panel is screen-size-aware:

```tsx
<>
  {/* Mobile sticky CTA bar — always visible */}
  <div className="md:hidden fixed bottom-0 left-0 right-0 z-50 ...">
    <button onClick={() => setIsOpen(true)}>線上即時諮詢</button>
  </div>

  {/* Desktop FAB — only shown when chat is closed */}
  <div className="hidden md:flex fixed bottom-6 right-6 z-50">
    {!isOpen && (
      <motion.button onClick={() => setIsOpen(true)} className="...">
        <MessageCircleIcon />
      </motion.button>
    )}
  </div>

  {/* Chat panel — shown on ALL screen sizes when open */}
  <AnimatePresence>
    {isOpen && (
      <motion.div className="fixed inset-0 z-50 flex items-end justify-center md:items-end md:justify-end p-0 md:p-6">
        {/* Mobile backdrop */}
        <div className="absolute inset-0 bg-black/40 md:hidden" onClick={() => setIsOpen(false)} />

        {/* Panel: full-width bottom sheet on mobile, floating on desktop */}
        <div className="relative w-full md:w-[360px] md:h-[520px] rounded-t-2xl md:rounded-2xl ..."
          style={{ maxHeight: '85vh', height: 'auto' }}>
          {/* Header with close button */}
          {/* Messages area */}
          {/* Input area */}
        </div>
      </motion.div>
    )}
  </AnimatePresence>
</>
```

Key CSS: `fixed inset-0` covers full viewport. `items-end justify-center` anchors to bottom. `md:items-end md:justify-end` keeps desktop alignment bottom-right.

## Problem 2: Mobile Header Not Truly Sticky

### Symptom
Mobile navigation doesn't stick to top when scrolling — it scrolls away.

### Root Cause
Mobile nav is often placed inside a non-sticky wrapper div with `w-[90%]` centering. `position: sticky` only works if the sticky element's parent doesn't have `overflow: hidden/auto/scroll`.

```tsx
// BROKEN: Sticky is inside a centered non-sticky wrapper
<div className="mx-auto w-[90%]">  {/* overflow context breaks sticky */}
  <nav className="sticky top-0">   {/* won't stick */}
  </nav>
</div>
```

### Fix: Separate Desktop and Mobile Navs with True Sticky

```tsx
<>
  {/* Desktop nav — hidden on mobile */}
  <div className="hidden md:block">
    <nav className="sticky top-4 ... w-[90%] mx-auto rounded-2xl ...">
      {/* logo + desktop nav items */}
    </nav>
  </div>

  {/* Mobile nav — full width, sticky top, no wrapper */}
  <nav className="md:hidden sticky top-0 left-0 right-0 z-50 w-full backdrop-blur-xl border-b ...">
    <div className="flex items-center justify-between px-4 py-3">
      {/* logo */}
      {/* hamburger menu */}
    </div>
  </nav>
</>
```

Key: `md:hidden sticky top-0 left-0 right-0 w-full` — the `<nav>` itself is sticky, not wrapped in anything that breaks sticky behavior.

## Mobile Nav Children: Menu Items in Sheet Only

When mobile nav items (`children`) are used both in the sticky bar AND in the sheet, they'll duplicate. The correct pattern:

```tsx
{/* Mobile sticky bar: Logo + Hamburger only */}
<nav className="md:hidden sticky top-0 ...">
  <div className="flex items-center justify-between">
    <Link href="/">{logo}</Link>
    <Sheet>
      <SheetTrigger><MenuButton /></SheetTrigger>
      <SheetContent>
        <nav className="flex flex-col gap-4 mt-8">{children}</nav>
      </SheetContent>
    </Sheet>
  </div>
</nav>
```

`children` (nav menu items) only appear in the Sheet — not in the sticky bar row.

## Shared PhoneIcon Pattern

For the Phone icon in shared components, always use inline SVG to avoid Next.js RSC bare identifier bug:

```tsx
// components/shared/PhoneIcon.tsx
export function PhoneIcon({ className = 'w-5 h-5' }: { className?: string }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24"
      fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
      className={className}>
      <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
    </svg>
  );
}
```

Then import and use: `import { PhoneIcon } from '@/components/shared/PhoneIcon'` and `<PhoneIcon className="w-4 h-4" />`.
## Quick Commands
- `skill-load mobile-sticky-header-chat-panel` — Load this skill
