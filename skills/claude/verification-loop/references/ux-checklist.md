# UX/UI Validation Checklist

## Browser Tools Required
- `mcp_browser_navigate` — open URL
- `mcp_browser_snapshot` — accessibility tree
- `mcp_browser_console` — JavaScript errors
- `mcp_browser_vision` — visual analysis
- `mcp_browser_scroll` — scroll detection

## Prerequisites
```bash
# Start services
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml up -d
sleep 20
```

## Phase 1: Homepage / Landing
- [ ] Page loads without white screen of death
- [ ] No crash (JavaScript errors in console)
- [ ] Main content visible within 3 seconds
- [ ] Navigation works (links clickable)
- [ ] Footer present with correct content

## Phase 2: Dashboard
- [ ] Login first → redirects to dashboard
- [ ] Dashboard shows user projects (or empty state)
- [ ] "New Project" button visible
- [ ] Project cards render with name, status, last updated
- [ ] Can click a project card → navigates to ProjectPage

## Phase 3: ProjectPage (Builder)
- [ ] Three-panel layout: file tree | editor | preview
- [ ] File tree shows files
- [ ] Clicking file → content in editor
- [ ] Preview iframe loads
- [ ] Chat panel toggle works
- [ ] Build status indicator visible

## Phase 4: Chat Interaction
- [ ] Can type in chat input
- [ ] Send button clickable
- [ ] AI response streams in (token by token, not all at once)
- [ ] Loading state visible during stream
- [ ] Build starts automatically after AI response
- [ ] Build status updates: pending → building → success/failed

## Phase 5: Responsive Design
```bash
# Desktop 1440px
# Check: dashboard, project page layout at 1440px

# Mobile 375px
# Check: same pages at 375px — no horizontal overflow
```

## Phase 6: Console Errors Check
After EVERY page load, run:
```bash
mcp_browser_console()
```
- Count of errors must be 0
- Warnings acceptable (but log them)
- Any `Error:` level → FAIL

## Viewport Testing
```bash
# Desktop
mcp_browser_navigate("http://localhost:3001")
# verify layout

# Mobile simulation (via browser tool or resize)
# verify no broken layout
```

## Error States (visual)
- [ ] Invalid URL → 404 page looks good
- [ ] API down → shows error message, not crash
- [ ] Build failed → red error state with log output

## Color & Typography (basic)
- [ ] Text readable (contrast)
- [ ] Font loads (no FOUT flash of unstyled text)
- [ ] Brand colors consistent (purple/indigo gradient for vibe)

## If UX Fails
1. Capture screenshot: `mcp_browser_vision(question="What is broken?")`
2. Capture console: `mcp_browser_console()`
3. Send to frontend-dev: `aatosteam inbox send <team> frontend-dev "FAILED: ux\n<screenshot path>\n<console errors>"`
4. Do NOT fix yourself
5. Wait for fix → re-verify UX → mark complete
