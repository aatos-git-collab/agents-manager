---
name: pawnshop-css-health
description: "Self-healing CSS health checker for risheng-pawnshop. Scans for undefined CSS custom properties, validates against colors.js, and auto-fixes before delivery."
---

# Pawnshop CSS Health Skill

Self-healing CSS health checker that prevents minification errors in production by ensuring all CSS custom properties are properly defined.

## The Problem

`risheng-pawnshop` uses CSS custom properties in `css/globals.css` that are **never defined**:
- `--primary-light`, `--primary-dark`, `--primary-lighter`, `--primary-darker`
- `--secondary-light`, `--secondary-dark`
- `--maximum-opacity`

These work in dev mode (no minification) but **fail in production** when SWC minifier is strict.

## The Solution

A self-healing system that:
1. **Scans** `css/globals.css` for all `var(*)]` references
2. **Cross-checks** against `:root` and `.dark` definitions
3. **Validates** against `data/config/colors.js` for known color values
4. **Auto-fixes** by adding missing definitions
5. **Prevents** broken builds from reaching production

## RULES (Always Follow)

### For CSS Changes
1. **ALWAYS run CSS health check BEFORE committing** any CSS changes
2. **ALWAYS run CSS health check AFTER pulling** latest changes
3. **If check fails, FIX before delivery** - never push broken CSS
4. **Verify fix works in BOTH dev AND production** before declaring done

### For Any Pawnshop Work
1. **Check console for errors** - Use Playwright to verify no CSS errors in browser
2. **Dev AND Prod must both work** - A fix that breaks production is NOT a fix
3. **Source consistency** - CSS must be consistent between source and built output
4. **No build-break fixes** - If the build fails after your fix, the fix is incomplete

### Pre-Delivery Checklist
- [ ] `npm run build` completes without errors
- [ ] `npm run dev` starts without errors
- [ ] Browser console shows NO CSS errors
- [ ] Both light and dark modes render correctly
- [ ] `scripts/check.sh` returns PASS

## Usage

### Quick Health Check
```bash
./scripts/check.sh
```

### Auto-Fix Missing Variables
```bash
./scripts/fix.sh
```

### Full Validation (Check + Fix + Verify)
```bash
./scripts/validate.sh
```

### Run as Pre-Commit Hook
Add to `.git/hooks/pre-commit`:
```bash
cd /root/risheng-pawnshop
../.claude/skills/pawnshop-css-health/scripts/check.sh
```

## Architecture

### Files Scanned
- `css/globals.css` - Main CSS with `:root` and `.dark` blocks
- `data/config/colors.js` - Source of truth for color values

### Variables Tracked
| Variable | Source | Purpose |
|----------|--------|---------|
| `--primary-lighter` | `colors.primary.lighter` | Lightest primary |
| `--primary-light` | `colors.primary.light` | Light primary |
| `--primary-main` | `colors.primary.main` | Main primary |
| `--primary-dark` | `colors.primary.dark` | Dark primary |
| `--primary-darker` | `colors.primary.darker` | Darkest primary |
| `--secondary-lighter` | `colors.secondary.lighter` | Lightest secondary |
| `--secondary-light` | `colors.secondary.light` | Light secondary |
| `--secondary-main` | `colors.secondary.main` | Main secondary |
| `--secondary-dark` | `colors.secondary.dark` | Dark secondary |
| `--secondary-darker` | `colors.secondary.darker` | Darkest secondary |
| `--maximum-opacity` | Computed | Max opacity for animations |

### Dark Mode
Dark mode uses lighter variants to compensate for dark backgrounds:
- `--primary-light: #eab308` (lighter on dark)
- `--primary-dark: #a16207` (darker on light)

## Browser Testing

Use Playwright to verify CSS loads correctly:

```bash
python3 << 'EOF'
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context()
    page = context.new_page()
    
    console_errors = []
    page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)
    
    page.goto("http://localhost:3000", timeout=30000)
    page.wait_for_timeout(2000)
    
    print("Console errors:", console_errors if console_errors else "None")
EOF
```

**CSS errors in browser = broken build = do not deliver**

## Lessons Learned

### 2026-04-27: Root Cause of Minification Failures

**Problem**: Production build CSS minification caused errors while dev worked fine.

**Root Cause**: CSS classes like `.fancy-overlay`, `.fancy-glass`, `.fancy-link` referenced custom properties (`--primary-light`, etc.) that existed in Tailwind config but were NEVER defined in the CSS `:root` block.

**Fix**: Added missing CSS custom property definitions to `:root` and `.dark` blocks in `globals.css`:
```css
:root {
  --primary-lighter: #fef9c3;
  --primary-light: #fde047;
  --primary-main: #eab308;
  --primary-dark: #ca8a04;
  --primary-darker: #a16207;
  /* ... etc */
}
```

**Prevention**: Self-healing skill runs check on every CSS change to catch this before it reaches production.

### 2026-04-27: React Hydration Error #418 - Nested `<a>` Tags

**Problem**: React error #418 "Hydration failed because the initial UI does not match what was rendered on the server" appearing in production.

**Root Cause**: In `Header.tsx`, `logoComponent` was passed as a complete `<Link href="/">` element. Then `LandingHeader.tsx` wrapped it AGAIN in another `<Link href="/">`, creating invalid nested `<a>` tags.

**Fix**: In `LandingHeader.tsx`, render `logoComponent` directly without wrapping in another `<Link>`:
```tsx
// Before (WRONG):
{logoComponent ? (
  <Link href="/">{logoComponent}</Link>
) : (
  <DefaultLogo />
)}

// After (CORRECT):
{logoComponent || <DefaultLogo />}
```

**Files Fixed**:
- `components/landing/navigation/LandingHeader.tsx` - Fixed both desktop and mobile nav logo rendering

### 2026-04-27: Inline Style Tag Hydration Issues

**Problem**: Inline `<style>` tag in `app/layout.tsx` generating dynamic CSS variables was causing hydration mismatches.

**Root Cause**: The inline style tag with dynamic content (`style.join(';')`) was injecting CSS that differed between server and client renders.

**Fix**: 
1. Removed the redundant inline `<style>` tag from `app/layout.tsx` (lines 90-96)
2. CSS variables are already properly defined in `css/globals.css` `:root` block
3. Removed unused `colors.js` import and `style` array generation from layout

**Files Fixed**:
- `app/layout.tsx` - Removed inline style tag and unused color imports

## Common Issues

### CSS Minification Errors
If production build fails with CSS errors:
1. Run CSS health check: `scripts/check.sh`
2. If it fails, run fix: `scripts/fix.sh`
3. Rebuild

### Hydration Errors
If browser shows React hydration errors:
1. Check for nested `<a>` tags (invalid HTML)
2. Check for client/server rendering mismatches
3. Verify any dynamic content has `suppressHydrationWarning` where appropriate
4. Test with dev server to see full error messages
