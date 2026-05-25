---
name: project-health-verify
description: "Self-healing health checker for any project. Scans code health, runs browser verification with Playwright, validates builds, and checks console for errors. Configurable for any project via PROJECT_DIR."
---

# Project Health Verify Skill

A reusable, self-healing health checker that works for **any project**. Based on the pawnshop-css-health pattern but generalized for any codebase.

## What It Does

1. **Code Health Scan** - Checks for undefined dependencies, broken imports, missing configs
2. **Build Verification** - Ensures production build completes without errors
3. **Dev Server Test** - Starts dev server and verifies it runs
4. **Browser Verification** - Uses Playwright to check pages load and console is clean
5. **Auto-Fix** - Can automatically fix common issues when possible

## For Nexeraa

### Quick Health Check
```bash
/root/.claude/skills/project-health-verify/scripts/check.sh /root/nexeraa
```

### Full Validation (Pre-Delivery Gate)
```bash
/root/.claude/skills/project-health-verify/scripts/validate.sh /root/nexeraa
```

## Architecture

### Files Scanned (Nexeraa Example)
- `packages/*/src/**` - Source code
- `*.config.js` - Configuration files
- `docker-compose.yml` - Container config

### Variables Tracked
- Project root directory (configurable)
- Build command (default: `npm run build`)
- Dev command (default: `npm run dev`)
- Dev port (default: 5678)
- Health check specific to project type

## Browser Testing

Uses Playwright to verify:
- Page loads with HTTP 200
- No console errors (Error level)
- No page errors (uncaught exceptions)
- Key UI elements render

**Console errors = broken build = do not deliver**

## Usage

### Quick Check
```bash
./scripts/check.sh /path/to/project
```

### Full Validation
```bash
./scripts/validate.sh /path/to/project
```

### As Pre-Commit Hook
Add to `.git/hooks/pre-commit`:
```bash
/root/.claude/skills/project-health-verify/scripts/check.sh "$(git rev-parse --show-toplevel)"
```

## Project-Specific Override

Create `PROJECT_CONFIG.sh` in project root to override defaults:

```bash
PROJECT_NAME="MyApp"
BUILD_CMD="pnpm build"
DEV_CMD="pnpm dev"
DEV_PORT=3000
HEALTH_CHECK_TYPE="node"  # node | python | next | generic
```

## Lessons Learned

### 2026-05-18: Reusable Health Check Pattern

**Problem**: Each project needed its own health check skill, leading to duplication.

**Solution**: Created generic skill with project-specific config override support.

**Pattern**:
1. Scan for common issues (undefined vars, broken imports)
2. Run build verification
3. Start dev server
4. Browser test with Playwright
5. Report findings with auto-fix capability