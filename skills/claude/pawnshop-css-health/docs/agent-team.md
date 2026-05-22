# Pawnshop CSS Agent Team

## Overview

For ongoing pawnshop (risheng-pawnshop) CSS maintenance, use a team of specialized agents to ensure:
1. CSS health is maintained (no undefined variables)
2. Both dev and production work correctly
3. Browser console is checked for errors
4. Source consistency is maintained

## Agent Roles

### 1. CSS Health Agent
**Purpose**: Monitor and maintain CSS variable consistency

**Responsibilities**:
- Run CSS health check before any CSS changes
- Auto-fix missing CSS custom properties
- Verify `:root` and `.dark` blocks are in sync with `data/config/colors.js`

**Trigger**: Before any CSS-related work

### 2. Build Verification Agent
**Purpose**: Ensure builds work in both dev and production

**Responsibilities**:
- Run `npm run build` successfully
- Verify dev server starts (`npm run dev`)
- Check for any build warnings or errors

**Trigger**: After any code change, before delivery

### 3. Browser Verification Agent
**Purpose**: Verify the app renders correctly in browser

**Responsibilities**:
- Launch headless browser (Playwright)
- Navigate to the app
- Check console for errors
- Verify page loads with correct content
- Test both light and dark modes

**Trigger**: After any deployment, before declaring success

## Workflow Integration

### For Any Pawnshop Work:

1. **Start**: Agent receives task
2. **CSS Health Check**: Run `/root/.claude/skills/pawnshop-css-health/scripts/check.sh`
   - If FAIL → run `fix.sh` → recheck
3. **Code/Design Changes**: Make changes (do NOT modify design or content per user request)
4. **Build Check**: Run `npm run build`
   - If FAIL → diagnose and fix
5. **Dev Check**: Run `npm run dev` briefly
   - If FAIL → diagnose and fix
6. **Browser Check**: Run Playwright verification
   - If console errors → fix source before delivery
7. **Delivery**: Only after all checks pass

### Workflow Script

```bash
cd /root/risheng-pawnshop

# 1. CSS Health
/.claude/skills/pawnshop-css-health/scripts/check.sh

# 2. Build
npm run build

# 3. Dev (in background, then kill)
/npm run dev &
sleep 10
kill %1

# 4. Browser verification via Playwright
python3 << 'EOF'
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    errors = []
    page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)
    page.goto("http://localhost:3000", timeout=30000)
    page.wait_for_timeout(2000)
    print("Console errors:", errors if errors else "None")
EOF
```

## Error Handling

### CSS Errors in Browser
**If browser shows CSS errors**:
1. Check `css/globals.css` for undefined variables
2. Run CSS health check
3. Run fix script
4. Rebuild
5. Re-verify in browser

### Build Works But Browser Has Errors
**This means source code inconsistency**:
1. The built CSS differs from source expectations
2. Check if Tailwind purge is removing needed classes
3. Verify all CSS custom properties are defined
4. Check `@layer` directives are correct

### Dev Works, Production Fails
**Classic minification issue**:
1. Run CSS health check - likely undefined variables
2. Production SWC minifier is strict about undefined `var()` references
3. Add missing definitions to `:root` or `.dark` blocks

## Pre-Delivery Checklist

- [ ] CSS health check passes
- [ ] `npm run build` succeeds
- [ ] `npm run dev` starts without errors
- [ ] Browser console shows NO errors
- [ ] Light mode renders correctly
- [ ] Dark mode renders correctly
- [ ] Content and design unchanged (per user request)

## Key Files

| File | Purpose |
|------|---------|
| `/root/risheng-pawnshop/css/globals.css` | Main CSS - check `:root` and `.dark` blocks here |
| `/root/risheng-pawnshop/data/config/colors.js` | Source of truth for color values |
| `/root/.claude/skills/pawnshop-css-health/scripts/check.sh` | CSS health checker |
| `/root/.claude/skills/pawnshop-css-health/scripts/fix.sh` | CSS auto-fixer |
| `/root/.claude/skills/pawnshop-css-health/scripts/validate.sh` | Full validation |

## Important Notes

1. **Do NOT change design or content** - User explicitly requested this
2. **Always check browser console** - CSS errors may not show in build but appear in browser
3. **Source consistency** - The built CSS must match source expectations
4. **Self-healing** - The CSS health skill should auto-fix most issues, but always verify
