---
name: pawnshop-nav-header
description: Pawnshop nav/header/CtaBanner rules — sticky positioning, per-page CTAs, token usage. Rules to never repeat.
---

# Pawnshop Nav & Header — Rules to Never Repeat

## Sticky Header Positioning

**THE RULE:** Mobile nav = `sticky top-0`. Desktop nav = `sticky top-8`. ALWAYS.

Mobile nav is `h-16` (64px). Desktop nav MUST be `top-8` (32px below mobile nav). `top-0` on desktop means it sits on top of mobile nav. `top-16` is wrong — mobile nav is `h-16 = 16 units`, desktop needs `top-8 = 8 units` to sit just below it.

**When editing LandingHeader.tsx:**
- Mobile nav: `sticky top-0 left-0 right-0 z-50 ...`
- Desktop nav: `sticky top-8 left-0 right-0 z-50 ...`

Check BOTH instances every time before committing.

## CtaBanner on Every Page

**THE RULE:** Every marketing page (services, shop, about, faq, blog) MUST have a CtaBanner at the bottom. Blog is NOT exempt. If a page doesn't have CtaBanner, add it.

**Per-page context:**
- services: `title="還在猶豫嗎？" subtitle="立即聯絡我們，專業團隊為您評估，找出最適合您的借款方案！"`
- shop: `title="找不到想要的商品？" subtitle="告訴我們您正在找的東西，我們幫您留意最新流當資訊"`
- about: `title="歡迎來電或 LINE 詢問" subtitle="專業團隊為您服務，快速估價、當日撥款，解決您的資金週轉問題！"`
- faq: `title="還有其他問題？" subtitle="專業團隊為您服務，快速解答您的借貸疑問"`
- blog: `title="訂閱最新借貸資訊" subtitle="專業團隊為您服務，快速估價、當日撥款！"` OR if using custom newsletter section, it must use `from-yellow-500 via-yellow-400 to-yellow-600` (NOT primary-*) and same buttons as homepage.

**Blog newsletter:** If blog has a custom newsletter section (with email input), it MUST use `from-yellow-500 via-yellow-400 to-yellow-600` gradient + `opacity-10` dot pattern + same LINE + 0800 buttons as homepage CtaBanner. Do NOT use `primary-*` tokens here. Do NOT use email input form as the only CTA — add the LINE + 0800 buttons.

## CtaBanner Exact Style (don't reinvent)

**Background:** `bg-gradient-to-br from-yellow-500 via-yellow-400 to-yellow-600`
**Dot pattern:** Single div, `opacity-10`, same SVG dot pattern as homepage. NOT dark:opacity-[0.15] — just `opacity-10` both modes.
**Buttons:** LINE = `bg-green-500 hover:bg-green-600 text-white h-12 text-lg`. 0800 = `border border-white text-white hover:bg-white/20 h-12 text-lg bg-transparent`.
**Subtitle:** `text-yellow-100`
**Import:** `MessageCircle, Phone` from lucide-react

## Primary vs Yellow Tokens

- **CtaBanner / Homepage CTA section:** `yellow-*` tokens (THIS IS THE BRAND COLOR)
- **Global components (Header, Footer, PageHero):** `primary-*` tokens (amber-500 family)
- **When in doubt:** Check `tailwind.config.js` — primary = amber family, yellow = yellow family. CtaBanner is the exception and uses yellow directly.

## Sticky Nav Scroll Behavior

- Desktop light at-top: solid white + `border-primary-400/40` + `shadow-lg shadow-primary-500/10`
- Desktop light scrolled: `bg-white/80 backdrop-blur-xl border-primary-400/30 shadow-sm`
- Desktop dark at-top: `bg-slate-900/80 backdrop-blur-md border-primary-700/40`
- Desktop dark scrolled: `bg-slate-900/80 backdrop-blur-xl border-primary-700/30`
- Mobile: always solid white/dark, `border-b border-primary-400/40`, NO transparency

## Before Any Deploy Checklist

1. [ ] Search for `top-0` in LandingHeader.tsx — must only appear on mobile nav
2. [ ] Search for `top-8` in LandingHeader.tsx — must appear on desktop nav
3. [ ] Check every marketing page has CtaBanner or exact-matching newsletter section
4. [ ] Check blog newsletter uses yellow-* (NOT primary-*)
5. [ ] Verify CtaBanner.tsx uses `from-yellow-500 via-yellow-400 to-yellow-600`
6. [ ] Verify buttons match homepage exactly (green LINE + bordered 0800)
## Quick Commands
- `skill-load pawnshop-nav-header` — Load this skill
