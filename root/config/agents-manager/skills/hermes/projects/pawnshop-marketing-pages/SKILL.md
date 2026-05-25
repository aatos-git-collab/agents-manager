---
name: pawnshop-marketing-pages
description: Global PageHero + CtaBanner pattern for pawnshop Next.js marketing pages. One file controls all page headers/footers.
---

# Pawnshop Marketing Pages — Hero & CTA Pattern

## Overview
All public frontend pages in `app/(marketing)/` share two global components:
- **PageHero** — page header banner (slate dark bg + badge + white title + yellow gradient accent + subtitle)
- **CtaBanner** — bottom CTA contact banner (yellow/gold gradient matching home page style)

Footer is global via `MarketingLayout` — do NOT add explicit `<Footer />` to individual pages.

## Files

### `components/shared/PageHero.tsx`
Global page header. Props:
```ts
interface PageHeroProps {
  badge?: string;        // e.g. "流當品專區" — shown in yellow pill
  title: string;        // e.g. "日盛當舖" — white, bold
  titleAccent?: string; // e.g. "精品拍賣" — yellow gradient, shown below title
  subtitle?: string;    // body text in slate-300
  className?: string;
}
```
Design spec: `py-12 md:py-16`, `bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900`, dot SVG pattern, gold glow accents.

### `components/shared/CtaBanner.tsx`
Global CTA banner at bottom of every page. Props:
```ts
interface CtaBannerProps {
  title?: string;   // default: "需要資金週轉嗎？\n日盛當舖幫您輕鬆解決！"
  subtitle?: string; // default: "立即聯絡我們，專業團隊為您服務，快速估價、當日撥款！"
  className?: string;
}
```
Design spec: `py-16 md:py-20`, `bg-gradient-to-br from-yellow-500 via-yellow-400 to-yellow-600`, dot SVG pattern, white text.

### `components/shared/index.ts`
Must export both:
```ts
export { PageHero } from './PageHero';
export { CtaBanner } from './CtaBanner';
```

## Adding a New Marketing Page

1. Import:
```ts
import { PageHero, CtaBanner } from '@/components/shared';
```

2. Add hero (before content):
```tsx
<PageHero
  badge="頁面標籤"
  title="日盛當舖"
  titleAccent="口號副標"
  subtitle="描述文字"
/>
```

3. Add CTA before `</>`:
```tsx
<CtaBanner
  title="想要的自訂標題"
  subtitle="想要的自訂副標"
/>
```

4. NO `<Footer />` — it's global in `MarketingLayout`.

## Design Decisions

- **Hero = slate dark** (`from-slate-900 via-slate-800 to-slate-900`) — corporate, trustworthy
- **Hero titleAccent = yellow gradient** (`from-yellow-400 via-yellow-300 to-yellow-500`) — brand accent
- **Badge = yellow pill** (`bg-yellow-500/10 text-yellow-400 border-yellow-500/20`)
- **CTA Banner = yellow/gold** (`from-yellow-500 via-yellow-400 to-yellow-600`) — matches home page CTA exactly
- **Hero height = py-12 md:py-16** — shorter/proportionate (shop page standard)
- **No contact buttons in hero** — chat widget handles all contact actions

## SEO Notes

- One `h1` per page with proper hierarchy
- Hero `h1` = `title` + `titleAccent` combined — both parts semantically part of the heading
- Inner page h2/h3 sections for content below hero
- JSON-LD structured data in page metadata (FAQ uses `faqSchema`, About uses `localBusinessSchema`)

## Common Mistakes

- **Adding explicit `<Footer />`** — Footer is in `MarketingLayout`. Explicit import causes double Footer.
- **Using `titleAccent` in `title`** — e.g. "日盛當舖精品拍賣" should be `title="日盛當舖"` + `titleAccent="精品拍賣"` — the accent gets yellow gradient treatment.
- **Changing home page hero** — home page uses its own custom hero. PageHero/CtaBanner are for inner pages only. Home is sacred.

## Adding Pages to Navigation

Header nav lives in `components/shared/Header.tsx`. Update the nav items array there — no need to modify layout.
## Quick Commands
- `skill-load pawnshop-marketing-pages` — Load this skill
