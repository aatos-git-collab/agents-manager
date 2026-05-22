---
name: verification-loop
description: Mandatory verification protocol for all agent team deliverables. Must be followed every time an agent produces output — no exceptions.
---



# Verification Loop — The Law

```
Agent produces → Leader verifies → If broken → Send errors BACK to agent
→ They fix → Verify again → Repeat until ALL checks pass
→ ONLY THEN mark complete and close session
```

**The leader is COORDINATOR, never implementer.** The only exception: agent explicitly cannot resolve something and escalates.

---

## The Verification Checklist

Run ALL of these in order. Nothing gets skipped. If ANY item fails, loop back to the producing agent.

### Phase 1: Build Verification
```bash
# Backend
cd /path/to/bolt-builder/backend && pnpm install && pnpm build

# Frontend
cd /path/to/bolt-builder/frontend && pnpm install && pnpm build

# Both must exit 0. If either fails → send errors to agent → wait for fix → re-verify
```

### Phase 2: Docker Compose Validation
```bash
# Test compose (local validation — fast)
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml config --quiet

# Prod compose
docker compose -f infra/docker-compose.yml -f infra/docker-compose.prod.yml config --quiet

# Both must pass with no errors (warnings about missing env vars are OK)
```

### Phase 3: Docker Test Execution (CRITICAL)
```bash
# ALL tests run inside Docker. Nothing runs locally.
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml up --build test

# Exit 0 = pass. Any non-zero = fail → send output to agent → wait for fix → re-verify
```

### Phase 4: Browser/E2E Testing (Playwright)
```bash
# Start services for testing
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml up -d

# Wait for services to be healthy
sleep 15

# Run Playwright tests via the test service
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml run --rm test

# Or exec into running frontend
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml exec -T frontend npx playwright test
```

See: `references/e2e-checklist.md` and `scripts/run-e2e.sh`

### Phase 5: CI/CD Pipeline Checks
```bash
# Verify GitHub Actions or equivalent CI passes
# Check: .github/workflows/*.yml are valid YAML
# Check: all required secrets are documented (not hardcoded)
# Check: tests run on PR and push to main

# Run CI locally (if using act)
act -j test

# If no act: inspect .github/workflows/ci.yml manually for:
#   - checkout + setup-node + pnpm-install + pnpm-build steps
#   - test command matches: docker compose -f infra/docker-compose.test.yml up --build test
```

See: `references/ci-cd-checklist.md`

### Phase 6: UX/UI Review (Browser Mandatory)
```bash
# Start the app
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml up -d

# Wait for services healthy
sleep 20

# Use mcp_browser_navigate to:
#   mcp_browser_navigate("http://localhost:3001")  # frontend

# Check:
#   - Homepage / dashboard loads without crash
#   - Login/auth flow works (if auth implemented)
#   - No console errors: mcp_browser_console()
#   - Responsive: mobile 375px vs desktop 1440px viewport
#   - Key user flows: create project, open builder, send chat message
```

See: `references/ux-checklist.md`

---

## The Loop Pseudocode

```python
def verification_loop(agent_name, deliverable):
    checks = [
        ("build",        run_build_check),
        ("compose",     run_compose_validation),
        ("docker-test", run_docker_tests),
        ("e2e",         run_e2e_tests),
        ("ci-cd",       run_ci_cd_checks),
        ("ux",          run_ux_review),
    ]

    for check_name, check_fn in checks:
        result = check_fn()
        if result.failed:
            error_msg = format_error(result)
            send_to_agent(agent_name, f"FAILED: {check_name}\n{error_msg}\nFix and resubmit.")
            wait_for_fix()
            # restart the loop from the failed phase
            continue  # or restart from first check
        else:
            log(f"PASSED: {check_name}")

    mark_complete()
    return True
```

---

## Sending Errors Back to Agents

When a check fails, send to the agent's inbox:

```bash
aatosteam inbox send <team> <agent-name> "FAILED: <check-name>

ERROR OUTPUT:
<full error output>

Fix the issue and re-run the build/test. Do NOT mark task complete until I verify it passes.
"
```

**Required in every message:**
- Which check failed
- Full error output
- What to fix
- Deadline: next iteration of verification

---

## Checklist Summary (Quick Reference)

| Phase | Command | Pass Criteria |
|-------|---------|---------------|
| Build | `pnpm build` (backend & frontend) | Exit 0 |
| Compose | `docker compose config --quiet` | No errors |
| Docker Test | `docker compose up test` | Exit 0 |
| E2E | `docker compose run --rm test` | All green |
| CI/CD | `act -j test` or inspect workflows | All green |
| UX | Browser snapshot + console check | No errors |

---

## Skills Reference

- `references/e2e-checklist.md` — detailed E2E test cases
- `references/ci-cd-checklist.md` — CI/CD validation steps
- `references/ux-checklist.md` — UX/UI review criteria
- `scripts/run-e2e.sh` — automated E2E runner script
- `scripts/run-tests.sh` — Docker test runner script
- `scripts/verify-all.sh` — master verification script (all phases)

## Important Rules

1. **Never skip a phase** — even if build passes, run Docker tests
2. **Never fix yourself** — always send errors back to the agent
3. **Never close session** until all 6 phases pass
4. **Both frontend AND backend** must pass all checks
5. **Browser test is mandatory** — not optional
6. **Tests only in Docker** — nothing runs locally ever
7. **Log every check result** — helps diagnose where the loop broke
8. **Checklists live in the skill folder** — references/ and scripts/ subdirectories

## Quick Commands
- `skill-load verification-loop` — Load this skill
