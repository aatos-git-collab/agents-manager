---
name: coolify-workflow
description: "Dynamic Coolify deployment automation. Push to git → triggers Coolify deploy → monitor → if failed fix & retry → until success."
---

# Coolify Workflow

Automated deployment workflow using Coolify API + Git push triggers.

## RULES (Always Follow)

1. **Always retrieve deployment logs after failures** - Use `GET /api/v1/deployments/{uuid}` with token that has `read:sensitive` permission. Never blind-fix without seeing actual error.

2. **Document all lessons learned** - When a deployment fails, document the fix in skills so we don't repeat mistakes.

3. **Verify fixes work** - After any fix, always redeploy and confirm healthy status.

4. **Check health check configuration** - Unhealthy status usually means port mismatch or health check misconfiguration.

5. **ALWAYS verify via BROWSER** - Before declaring "done" or "working":
   - Use Playwright (installed) to navigate to URL
   - Check page loads correctly (not blank, not broken)
   - Capture console errors and page errors
   - Verify page title and content
   - Check for 404/503 errors
   - Take screenshot if needed
   - A "half-baked cake" is NOT acceptable - don't serve what you wouldn't eat

6. **Use Playwright for automated browser testing**:
```bash
# Test website with Playwright
python3 << 'EOF'
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(ignore_https_errors=True)
    page = context.new_page()
    
    console_messages = []
    page.on("console", lambda msg: console_messages.append(f"[{msg.type}] {msg.text}"))
    
    page_errors = []
    page.on("pageerror", lambda err: page_errors.append(str(err)))
    
    response = page.goto("https://your-domain.com", timeout=30000)
    page.wait_for_timeout(3000)
    
    print(f"Status: {response.status}")
    print(f"Title: {page.title()}")
    print("\nConsole Errors:")
    for msg in console_messages:
        if msg.startswith('[error]'):
            print(msg)
EOF
```

**BROWSER TEST FAILURE = DEPLOYMENT FAILED**

If any of these occur, the deployment is NOT successful:
- HTTP status code >= 400 (404, 503, etc.)
- Console errors present
- Page errors (JavaScript exceptions)
- Page title is empty when it should have content
- Blank page or no content
- CSS not loading properly
- Resource loading failures

**Deployment is only SUCCESS when:**
- HTTP status is 200
- Page title is correct
- NO console errors
- NO page errors
- Page content loads correctly
- All resources (CSS, JS, images) load successfully

6. **Full stack verification** - Both frontend AND backend must be working:
   - Frontend: Page renders correctly, no console errors
   - Backend: API endpoints respond correctly
   - Database: Connections work, no connection errors

7. **Wait for stability** - After restart/redeploy, wait 30-60 seconds before checking status. Health checks need time to settle.

8. **Debugging unhealthy apps**:
   - Check application logs first
   - Verify port mappings (not just exposes)
   - Check if health check is enabled vs disabled
   - Verify app binds to 0.0.0.0 not 127.0.0.1
   - Check traefik routing if external URL not working

## Two Types of Failures

### 1. Deployment Failure (Build Failed)
- Build process failed (e.g., "pnpm not found", syntax errors)
- Container never started
- **Fix**: Push code fix to git → Coolify auto-deploys OR manually trigger deploy
- **Monitor**: Poll deployment status until finished

### 2. Unhealthy App (Container Running but Unhealthy)
- Container started but health check fails
- App may be running but not responding correctly
- **Fix**: Use `/applications/{uuid}/restart` to restart container
- **Verify**: Check browser URL, console errors, API calls

## Important: API Token Permissions

**To access deployment logs via API, the token requires `read:sensitive` or `root` permission.**

Without these permissions, the `logs` field is hidden from `/api/v1/deployments/{uuid}` responses.

Required permissions:
- `read:sensitive` - Can read deployment logs and sensitive data
- OR `root` - Full access (use carefully)

Set in Coolify dashboard: Keys & Tokens → API Tokens → Create/Edit token with permissions.

## Pre-Deployment Checklist

Before deploying ANY application to Coolify, verify:

- [ ] **Port Configuration**: `ports_exposes` in Coolify matches app's actual port
  - Next.js standalone typically runs on `PORT=6006`
  - Check `EXPOSE` in Dockerfile AND Coolify app settings
- [ ] **Health Check Enabled**: Either Dockerfile has HEALTHCHECK or Coolify health check is configured
- [ ] **PORT env var**: App respects PORT environment variable
- [ ] **HOST binding**: App binds to `0.0.0.0` not `127.0.0.1`
- [ ] **Dependencies in docker-compose**: Database and other services have `condition: service_healthy`
- [ ] **.env file exists**: Coolify adds `env_file: .env` to all services

## Setup

### 1. Configure Environment
```bash
# In /root/.env
COOLIFY_API_KEY=your_api_key_with_deploy_and_read_sensitive_permissions
COOLIFY_URL=https://control.agent.nexeraa.io
```

### 2. Add Projects to Config
Edit `config/projects.json`:
```json
{
  "projects": {
    "project-name": {
      "uuid": "coolify-uuid",
      "git_repo": "org/repo",
      "branch": "main",
      "fqdn": "app.domain.com"
    }
  }
}
```

## Usage

### Continuous Deploy Loop (Recommended)
```bash
# Runs deploy → monitor → if failed wait & retry → until success
./workflows/deploy-loop.sh <project_name> [--fix]

# Example
./workflows/deploy-loop.sh risheng-pawnshop --fix
```

### Individual Commands
```bash
# Trigger deployment
./scripts/deploy.sh <project_name>

# Check deployment status (includes logs if permitted)
./scripts/status.sh <project_name>

# Get deployment logs (requires read:sensitive permission)
./scripts/logs.sh <project_name> --tail 50
./scripts/logs.sh <project_name> --last 3 --errors  # show errors from last 3 deployments

# List all projects
./scripts/list.sh
```

### Log Retrieval

**Deployment logs require `read:sensitive` token permission.**

Logs are available at:
- `GET /api/v1/deployments/{uuid}` - Full deployment data with logs field
- `GET /api/v1/applications/{uuid}/logs` - Runtime container logs (only when app running)

The `/applications/{uuid}/logs` endpoint returns "Application is not running" for failed/stopped apps.
Use `/deployments/{uuid}` to get build logs even for failed deployments.

## Workflow

1. **Loop Start** → Push code to git
2. **Coolify Auto-Deploys** → Git push triggers Coolify webhook → automatic build starts
3. **Monitor** → Poll status every 10s
4. **Verify via Browser** → Navigate to URL, check console, verify page loads correctly
5. **If Failed** → Get logs, fix code, push again (Coolify auto-deploys)
6. **Repeat** → Until success or max 10 loops

**Important**: Coolify has auto-deploy enabled. Pushing to git triggers deployment automatically. No need to manually trigger deploy unless testing.

## Getting Logs

The `logs.sh` script retrieves deployment build logs:

```bash
# Last 50 log entries
./logs.sh risheng-pawnshop

# Last 30 entries
./logs.sh risheng-pawnshop --tail 30

# Show errors only
./logs.sh risheng-pawnshop --errors

# Check last 3 deployments
./logs.sh risheng-pawnshop --last 3

# Just show status summary
./logs.sh risheng-pawnshop --status
```

## Dynamic Project Resolution

Projects resolved by name from `config/projects.json`. To add new project:

1. Find UUID: `./scripts/list.sh`
2. Add to `config/projects.json`
3. Use name in commands

## API Endpoints Used

| Method | Endpoint | Purpose | Permission |
|--------|----------|---------|------------|
| GET | `/applications` | List/discover projects | read |
| GET | `/deployments/applications/{uuid}` | Get deployment history | read |
| GET | `/deployments/{uuid}` | Get deployment details + logs | read:sensitive |
| POST | `/deploy` | Trigger deploy | write |
| PATCH | `/applications/{uuid}` | Update app settings (e.g., ports) | write |
| GET | `/applications/{uuid}/logs` | Runtime container logs | read |
| POST | `/applications/{uuid}/stop` | Stop app | write |
| POST | `/applications/{uuid}/restart` | Restart app | write |

## Troubleshooting

### "Application is not running" when getting logs
- Use `/deployments/{uuid}` (not `/applications/{uuid}/logs`) for failed deployments
- Runtime logs only exist while app is running

### Logs field hidden in API response
- Token needs `read:sensitive` or `root` permission
- Check token permissions in Coolify dashboard

### Build fails with "pnpm: not found"
- Ensure `corepack enable pnpm` is run before `pnpm build` in Dockerfile

### App shows as "unhealthy"
1. Check `ports_exposes` matches actual app port (Coolify setting, not docker-compose)
2. Verify health check path exists and returns 200
3. Check app binds to `0.0.0.0` not `127.0.0.1`
4. Check `health_check_port` if set is correct

## Lessons Learned

### 2026-04-25: Docker Compose Deployment Failures

**Problem**: Multiple deployments failed without logs visible via API

**Root Cause 1**: Token missing `read:sensitive` permission
- Fix: Updated token with `read:sensitive` permission
- Now logs appear in `GET /api/v1/deployments/{uuid}`

**Root Cause 2**: Dockerfile builder stage missing `corepack enable pnpm`
- Error: `pnpm: not found` at `RUN pnpm build`
- Fix: Added `corepack enable pnpm &&` before `pnpm build`

**Root Cause 3**: App showed as "unhealthy" after successful deployment
- Cause: `ports_exposes` was set to `3000` in Coolify but app runs on `6006`
- Health check used wrong port → always failed → unhealthy
- Fix: PATCH `/applications/{uuid}` with `{"ports_exposes":"6006"}`

**Root Cause 4**: Health check failing despite app being running
- App logs show "Ready in 200ms" but Coolify marks unhealthy
- Health check via traefik may not work without proper FQDN routing
- App shows "Feature is disabled" and 503 errors - likely auth/db connection issues

**Lesson**: Check actual port configuration both in docker-compose AND Coolify settings

### Important Findings

1. **Port 6007 does NOT exist** - only 6006 is configured in docker-compose and Dockerfile
2. **Single process architecture** - Next.js standalone serves all routes (/api, /admin) on port 6006
3. **FQDN is critical** - Without fqdn set, traefik can't route traffic, app returns 404
4. **PATCH endpoint has limited fields** - fqdn is NOT in the allowedFields for update_by_uuid
5. **docker_compose_domains update works** - but doesn't set fqdn properly for routing
6. **Need local Coolify** - for better debugging visibility into container logs and traefik config

## Coolify Docker App Requirements

See `docs/docker-app-rules.md` for detailed requirements. Key points:

- Expose correct port (matches `ports_exposes` in Coolify)
- Listen on `0.0.0.0` (not `127.0.0.1`)
- Respond to health check at configured path
- Handle `PORT` environment variable