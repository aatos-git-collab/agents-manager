---
name: aatosteam-orchestration
description: AatosTeam template-based orchestration — short task + template name = clean handover. All templates enforce MANDATORY production gates: Docker builds, pytest pass, Playwright webtest, CI/CD valid. Proof before completion.
trigger: /orchestrate or when spawning aatosteam agents, launching teams, or managing multi-agent workflows
---

# AatosTeam Orchestration Skill

## Architecture

```
HERMES (Aatos CTO)
  └── aatosteam launch TEMPLATE --goal "short task"
        ├── Template (TOML): identity + coordination + workflow
        ├── Skills: symlinks in ~/.claude/skills/ (NOT in prompt)
        ├── Backend spawns: claude --append-system-prompt [template content]
        └── Agent runs clean — no 15KB prompt bloat
```

## THE RULE: Proof Before Completion

**No claiming done without proof.** If it wasn't tested automatically, it's not done.

Every template enforces these MANDATORY production gates before any task is marked complete.

## Production Gates (Non-Negotiable)

| Gate | What | How |
|------|------|-----|
| GATE 1 | Docker builds + starts | `docker compose build --pull && docker compose up -d && docker compose ps` |
| GATE 2 | Backend tests pass | `docker compose run --rm api pytest --tb=short -q` |
| GATE 3 | Playwright webtest passes | `cd frontend && npx playwright test --reporter=line` |
| GATE 4 | CI/CD workflows valid | `ls -la .github/workflows/` — must have test.yml + playwright.yml + docker.yml |
| GATE 5 | Production checklist | Fill + verify: no secrets, README complete, no TODO/FIXME |
| GATE 6 | Ship (only after gates 1-5) | `git add -A && git commit -m "feat: ... | tests: ✓ | playwright: ✓ | ci: ✓"` |

## Available Templates

| Command | Use When | Agents | Production Gates |
|---------|----------|--------|-----------------|
| `aatosteam launch boris -t NAME --goal "..."` | Complex multi-step tasks | orchestrator + executor | All 5 gates enforced |
| `aatosteam launch cto -t NAME --goal "..."` | CTO decisions, architecture | orchestrator + cto-specialist | Gates enforced |
| `aatosteam launch full-stack -t NAME --goal "..."` | Full web app | architect + backend + frontend + qa | All 5 gates + dedicated qa |
| `aatosteam launch software-dev -t NAME --goal "..."` | Multi-agent dev (builtin) | varies | Default |
| `aatosteam launch strategy-room -t NAME --goal "..."` | Planning & tradeoffs (builtin) | varies | Default |
| `aatosteam launch code-review -t NAME --goal "..."` | PR analysis (builtin) | varies | Default |

Override backend: `--backend subprocess` (headless) or `--backend tmux` (visual)

## Skill-to-Symlink Bridge

Claude Code reads skills from `~/.claude/skills/`. Hermes skills live in `~/.hermes/skills/`.

Symlinks bridge them (auto-created/verified by self-heal.sh):
- `aatosteam` → `~/.hermes/tools/AatosTeam/skills/aatosteam/`
- `cto/ceo/cfo/cmo/coo/cso` → `~/.hermes/skills/agent-brains/{skill}/`
- `grant-cardone/jordan-belfort/zig-ziglar/talent-architect/reasoning-personas` → `~/.hermes/skills/agent-brains/{skill}/`
- `boris-workflow` → native (already installed)

## Testing Skills Available

These skills are auto-linked and available to all spawned agents:

| Skill | Purpose |
|-------|---------|
| `/playwright-pro` | Playwright E2E testing — use `/init` to set up if not present |
| `/test` | Generate unit tests (pytest) |
| `/production-ready` | Production checklist verification |
| `/docker-development` | Docker setup and debugging |
| `/review` | Code review |
| `/ship` | Ship workflow |
| `/qa` | QA webapp testing |

**Rule for GATE 3 (Playwright):** If `/init` has not been run in the frontend directory:
1. `/init` to set up Playwright
2. Write tests: auth flow, main user journey, error states, empty states
3. Run: `npx playwright test --reporter=line`
4. ALL must pass. Any failure → FIX IT.

## Self-Healing

- Check: `~/.hermes/skills/aatosteam-orchestration/scripts/self-heal.sh --check`
- Fix: `~/.hermes/skills/aatosteam-orchestration/scripts/self-heal.sh --fix`

Crontab watchdog: every 6h (auto-installed by --fix)

Checks:
1. Symlinks: all `~/.claude/skills/` → `~/.hermes/skills/` bridges intact
2. Templates: valid TOML with production gates in `~/.aatosteam/templates/`
3. Binary: `/usr/local/bin/aatosteam` v0.3.0+
4. Config: `~/.aatosteam/config.yaml` has `skip_permissions: true`
5. Cron: watchdog entry present

## Quick Reference

```bash
# Launch boris orchestrator (recommended for complex tasks)
aatosteam launch boris -t my-team --goal "Build user auth system"
aatosteam launch boris -t my-team --backend subprocess --goal "Fix login bug"

# Launch full-stack dev team (recommended for web apps)
aatosteam launch full-stack -t web-app --goal "Build a SaaS CRM"
aatosteam launch full-stack -t web-app --backend subprocess --goal "Add payment integration"

# Check board (tasks with production gate tracking)
aatosteam board show my-team

# Check inbox
aatosteam inbox peek my-team --agent orchestrator

# Force a gate check
aatosteam inbox send my-team qa-engineer "Re-run Playwright tests: cd frontend && npx playwright test"

# Health check
~/.hermes/skills/aatosteam-orchestration/scripts/self-heal.sh --check
```

## Files

- Self-heal: `~/.hermes/skills/aatosteam-orchestration/scripts/self-heal.sh`
- Templates: `~/.aatosteam/templates/boris.toml`, `cto.toml`, `full-stack.toml`

## Anti-Pattern: What NOT To Do

```
❌ "Build complete — tests passed locally"     → Shipped without CI/CD
❌ "Feature works in dev"                       → Docker not tested
❌ "Manually tested — looks good"               → No Playwright = not tested
❌ "TODO: add tests later"                       → Not done until tests exist and pass
❌ "Code review done"                           → Must also have Playwright webtest
```

## Correct Pattern

```
✅ Docker compose build → ✅ Services start
✅ pytest → ✅ ALL pass
✅ Playwright → ✅ ALL pass (auth + main flow + error + empty)
✅ CI/CD workflows → ✅ test.yml + playwright.yml + docker.yml exist
✅ Checklist → ✅ ALL [X] filled
✅ git push
```

## Quick Commands
- `skill-load aatosteam-orchestration` — Load this skill
