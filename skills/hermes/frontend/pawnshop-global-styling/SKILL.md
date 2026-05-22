---
name: pawnshop-global-styling
description: pawnshop-global-styling skill
  Global styling rules and component patterns for the pawnshop Next.js app
  (risheng.team.nexeraa.io). Covers: primary token family, CtaBanner global
  component, PageHero, LandingHeader nav scroll behavior, per-page CTA context,
  dead import cleanup. Use when editing global/shared components or CTA banners.
version: 2.0.0
category: frontend
---

# Pawnshop Global Styling (v2.0)

## Token Family: `primary-*` (amber-500)

All global/shared components use `primary-*` tokens (amber-500 family). **NEVER use hardcoded `yellow-*` in shared/global components.**

Source: `tailwind.config.js` via `data/config/colors.js`

| Token | Hex | Usage |
|-------|-----|-------|
| `primary-100` | `#fef3c7` | Light mode base layer |
| `primary-300` | `#fcd34d` | Light mode glows, badge |
| `primary-400` | `#fbbf24` | Logo gradient start |
| `primary-500` | `#f59e0b` | Main brand, CTA gradient |
| `primary-600` | `#d97706` | Hover states, borders |
| `primary-700` | `#b45309` | Dark mode accents |
| `primary-900` | `#78350f` | Dark mode base layer |

## CtaBanner — Global CTA Component

**File:** `components/shared/CtaBanner.tsx`

**Background:** `bg-gradient-to-br from-primary-500 via-primary-400 to-primary-600` — SAME both light and dark mode
**Dot pattern:** `opacity-10 dark:opacity-20` + `fill-black dark:fill-white` (inline SVG via data URI)
**Buttons:** LINE = `bg-green-500 hover:bg-green-600 h-12 text-lg` | 0800 = `border border-white text-white hover:bg-white/20 h-12 text-lg bg-transparent`
**Subtitle:** `text-yellow-100`
**Import:** `MessageCircle, Phone` from lucide-react
**Title:** `text-white whitespace-pre-line text-3xl md:text-4xl lg:text-5xl font-bold`

**Per-page usage — pass title and subtitle props:**
```tsx
import { CtaBanner } from '@/components/shared';

// Services page
<CtaBanner title="還在猶豫嗎？" subtitle="立即聯絡我們，專業團隊為您評估，找出最適合您的借款方案！"/>

// Shop page
<CtaBanner title="找不到想要的商品？" subtitle="告訴我們您正在找的東西，我們幫您留意最新流當資訊"/>

// About page
<CtaBanner title="歡迎來電或 LINE 詢問" subtitle="專業團隊為您服務，快速估價、當日撥款，解決您的資金週轉問題！"/>

// FAQ page
<CtaBanner title="還有其他問題？" subtitle="專業團隊為您服務，快速解答您的借貸疑問"/>

// Default
<CtaBanner title="需要資金週轉嗎？\n日盛當舖幫您輕鬆解決！" subtitle="立即聯絡我們，專業團隊為您服務，快速估價、當日撥款！"/>
```

**Pages using CtaBanner:** `/services`, `/about`, `/shop`, `/faq`

**Blog:** Has custom newsletter section but it MUST match CtaBanner exactly: `from-yellow-500 via-yellow-400 to-yellow-600` gradient + `opacity-10` dot pattern + green LINE button + white 0800 button. Do NOT use `primary-*` tokens on blog newsletter. Do NOT use email input form only — must have LINE + 0800 buttons.

## LandingHeader — Navigation Bar

**File:** `components/landing/navigation/LandingHeader.tsx`

**⚠️ STICKY POSITIONING — NEVER GET WRONG AGAIN:**
- Mobile nav: `sticky top-0 left-0 right-0 z-50` (sits at very top, above desktop nav)
- Desktop nav: `sticky top-8 left-0 right-0 z-50` (sits BELOW mobile nav — mobile nav is h-16 = 64px, desktop needs top-8 = 32px to clear it)
- Search for `top-0` in this file — must ONLY appear on mobile nav instance

**Desktop light mode (at top):** solid white + `border-primary-400/40` + `shadow-lg shadow-primary-500/10`
**Desktop light mode (scrolled):** `bg-white/80 backdrop-blur-xl border-primary-400/30`
**Dark mode:** `dark:bg-slate-900/80 backdrop-blur-md` — same at top and scrolled
**Mobile:** always solid white + `border-b border-primary-400/40 dark:border-primary-700/40` — no transparency

Hamburger button: `border-primary-400/40 text-primary-700`

## ⚠️ CRITICAL: No Functions Across RSC Boundary

**Rule:** Server Components (pages like `app/(marketing)/faq/page.tsx`) CANNOT pass React components/functions as props to Client Components.

**❌ WRONG — causes "Functions cannot be passed directly to Client Components" error:**
```tsx
// app/(marketing)/faq/page.tsx (Server Component)
import { HelpCircle } from 'lucide-react';
import { PageHero } from '@/components/shared'; // PageHero is 'use client'

// Page.tsx — Server Component
<PageHero badge="常見問題" badgeIcon={HelpCircle} title="日盛當舖" />
//                                        ^^^^^^^^^^ React function — NOT ALLOWED
```

**✅ CORRECT — remove icon prop from Server Component pages:**
```tsx
// Page.tsx — Server Component
<PageHero badge="常見問題" title="日盛當舖" subtitle="..." />
// No badgeIcon prop — the badge text alone is sufficient
```

**Why it happens:** Lucide icons are functions. Next.js serializes Server→Client props but cannot serialize function references. The fix is to never pass icon components as props from pages that are Server Components. Remove `badgeIcon={IconName}` entirely — it's cosmetic and the badge text alone works fine.

**Current affected pages:** `/faq` — badgeIcon removed, works fine without it.

## PageHero — Hero Banner Component

**File:** `components/shared/PageHero.tsx`

NO dot SVG (removed). Amber base layer + primary glows only.

```tsx
<section className={`
  w-full py-12 md:py-16 relative overflow-hidden
  ${className.includes('bg-') ? className : 'bg-primary-100/20 dark:bg-primary-900/10'}
`}>
  {/* Glows — NO dot SVG */}
  <div className="absolute top-0 right-0 w-96 h-96 bg-primary-300/10 dark:bg-primary-600/10 rounded-full blur-[128px] -translate-y-1/2 translate-x-1/2 pointer-events-none" />
  <div className="absolute bottom-0 left-0 w-96 h-96 bg-primary-500/10 dark:bg-primary-700/10 rounded-full blur-[128px] translate-y-1/2 -translate-x-1/2 pointer-events-none" />
  {/* Badge */}
  <span className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full
    bg-primary-100/20 dark:bg-primary-900/20
    text-primary-700 dark:text-primary-300
    text-sm font-medium mb-6 border border-primary-300/30 dark:border-primary-700/30">
    {BadgeIcon && <BadgeIcon className="w-4 h-4" />}
    {badge}
  </span>
  <h1 className="text-3xl md:text-4xl lg:text-5xl font-bold text-slate-900 dark:text-white mb-1">{title}</h1>
  <p className="text-base md:text-lg text-slate-600 dark:text-slate-300">{subtitle}</p>
</section>
```

## Per-Page Change Workflow

### Step 1: Commit revert point first
```bash
cd /root/pawnshop && git add -A && git commit -m "WIP: before styling changes"
```

### Step 2: Change ONE page at a time
- Apply PageHero or CtaBanner to ONE page
- Build → deploy → browser verify
- Only then move to next page

### Step 3: Verify ALL of this in browser
- [ ] Hero badge text correct
- [ ] Hero title correct
- [ ] Hero subtitle correct
- [ ] CTA title/subtitle correct
- [ ] No duplicate sections (old inline + new global)
- [ ] Nav sticky, responsive, scroll behavior correct
- [ ] Footer looks correct
- [ ] Light AND dark mode

### Step 4: Clean dead imports
After removing a component from a page, remove its import:
```tsx
// ❌ Dead import — CtaBanner removed from page but import remains
import { PageHero, CtaBanner } from '@/components/shared';

// ✅ Clean — only what's used
import { PageHero } from '@/components/shared';
```

### Revert
```bash
cd /root/pawnshop
# Revert to last commit
git revert --no-commit HEAD
git commit -m "revert"
```

## Current Page Status (2026-04-24)

| Page | Hero | CTA |
|------|------|-----|
| `/services` | PageHero + Wrench | CtaBanner "還在猶豫嗎？" |
| `/shop` | PageHero + ShoppingBag | CtaBanner "找不到想要的商品？" |
| `/blog` | PageHero + BookOpen | Custom newsletter (amber gradient, email form) |
| `/about` | Original custom hero (dark slate) | CtaBanner "歡迎來電或 LINE 詢問" |
| `/contact` | PageHero + Phone | None |
| `/faq` | PageHero + HelpCircle | CtaBanner "還有其他問題？" |

## Key Files
- `/root/pawnshop/components/shared/PageHero.tsx`
- `/root/pawnshop/components/shared/CtaBanner.tsx`
- `/root/pawnshop/components/shared/Footer.tsx`
- `/root/pawnshop/components/landing/navigation/LandingHeader.tsx`
- `/root/pawnshop/app/(marketing)/layout.tsx`
- Working dir: `/root/pawnshop/` | Branch: `version-2.0`

## Deploy
```bash
cd /root/pawnshop && pnpm build && docker build -t pawnshop-app:latest . && docker rm -f pawnshop-app-1 && docker run -d --name pawnshop-app-1 -p 6006:6006 --restart unless-stopped pawnshop-app:latest && sleep 8 && curl -s -o /dev/null -w "%{http_code}" http://localhost:6006/
```
## Quick Commands
- `skill-load pawnshop-global-styling` — Load this skill
