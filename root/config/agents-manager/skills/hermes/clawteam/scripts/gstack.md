# gstack — Headless Browser & Workflow Skills

> Full reference. Summary available in `../SKILL.md` Part 2.

## What is gstack?

gstack is an AI engineering workflow toolkit (YC / Garry Tan) that gives any AI agent
a persistent headless Chromium browser and 30+ opinionated workflow skills.

**gstack runs on 10+ agents:** Claude Code, OpenAI Codex, OpenCode, Cursor, Factory Droid,
Slate, Kiro, Hermes, GBrain.

---

## Core Concept: `$B` Command Proxy

The core primitive is `$B` — a compiled binary that drives a persistent Chromium daemon.
First call auto-starts the daemon (~3s). Subsequent calls: ~100ms.
Browser state (cookies, tabs, login sessions) persists between calls.
Auto-shuts down after 30 minutes idle.

```bash
B="$HOME/.claude/skills/gstack/browse/dist/gstack"
$B goto https://example.com
$B snapshot -i
$B click @e3
$B screenshot /tmp/result.png
```

---

## `$B` Commands

### Navigation
```bash
$B goto <url>               # Navigate (auto-starts daemon)
$B back / forward           # History navigation
$B refresh                  # Reload current page
```

### Inspection
```bash
$B snapshot -i              # Interactive elements with refs (@e1, @e2…)
$B snapshot -a              # Annotated screenshot (labels on every element)
$B snapshot -D              # Diff against previous snapshot
$B snapshot -C              # Cursor-clickable elements (@c1, @c2…)
$B text                     # Read page text
$B html                     # Full page HTML
$B links                    # All links with hrefs
$B title                    # Page title
$B url                      # Current URL
```

### Interaction
```bash
$B click <ref>              # Click element (ref from snapshot)
$B fill <ref> "<text>"      # Type into input
$B upload <ref> <file>      # Upload file
$B press <key>              # Press key (Enter, Tab, Escape, etc.)
$B hover <ref>              # Hover over element
$B scroll <direction>       # up/down/top/bottom
$B select <ref> "<option>"  # Select dropdown option
```

### Assertions (stop the run if they fail)
```bash
$B assert-text <selector> "<expected>"
$B assert-visible <selector>
$B assert-absent <selector>
$B assert-count "<selector>" <n>
```

### Browser State
```bash
$B console                 # JS console errors/warnings
$B network                 # Failed network requests
$B cookies                 # Cookie metadata (no values)
$B tabs                    # List open tabs
$B tab new <url>            # Open new tab
$B tab switch <n>           # Switch to tab N
$B tab close <n>            # Close tab N
```

### Screenshots & Media
```bash
$B screenshot [path]              # Full page screenshot (PNG)
$B screenshot --viewport [path]   # Viewport only (no scroll)
$B screenshot "<selector>" [path] # Crop to element
$B screenshot --clip <x,y,w,h> [path]  # Region crop
$B responsive <path-prefix>       # Mobile/tablet/desktop screenshots
```

### Advanced
```bash
$B dialog-accept ["<text>"]        # Auto-accept next alert/confirm/prompt
$B dialog                         # Show what dialog appeared
$B cookie-import-browser          # Import cookies from real Chrome
$B cookie-import-browser <name> --domain <.domain.com>  # Import specific domain
$B diff <url1> <url2>             # Compare two pages visually
$B chain <json-command-array>     # Run multi-step chain efficiently
$B domain-skill save <domain> <note>  # Save per-site knowledge
$B cdp <Domain.method> <args>     # Raw Chrome DevTools Protocol
$B handoff                        # Open visible Chrome at current page (human handoff)
$B resume                         # Resume after human fixes in headed mode
```

---

## Workflow Skills (`/<skill-name>`)

These are invoked as slash commands inside a Claude Code worker that has gstack loaded.

### Product Thinking
| Skill | What it does |
|-------|--------------|
| `/office-hours` | YC-style product interrogation. Six forcing questions that reframe your idea before you write code. |
| `/plan-ceo-review` | CEO-level review. Find the 10-star product. Four modes: Expansion, Selective Expansion, Hold Scope, Reduction. |
| `/plan-eng-review` | Lock architecture, data flow, edge cases, failure modes, test plan. |
| `/plan-design-review` | Rate each design dimension 0–10. Interactive — one question per design choice. |
| `/plan-devex-review` | DX review: TTHW benchmarks, magical moments, friction points, persona traces. |
| `/autoplan` | One command runs CEO → design → eng → DX review automatically. |

### Implementation & Review
| Skill | What it does |
|-------|--------------|
| `/review` | Pre-landing code review. Find bugs that pass CI but blow up in prod. Auto-fixes obvious ones. |
| `/codex` | OpenAI Codex second opinion. Three modes: review, adversarial challenge, open consultation. |
| `/investigate` | Systematic root-cause debugging. No fixes without investigation. |
| `/design-review` | Live-site visual audit + fix loop with atomic commits. |
| `/design-shotgun` | Generate 4–6 AI mockup variants, comparison board, iterate. |
| `/design-html` | Turn a mockup into production HTML/CSS (Pretext-computed layout, 30KB zero-dep). |
| `/qa` | Open a real browser, find bugs, fix them, re-verify. Generates regression tests. |
| `/qa-only` | Same QA methodology, report only — no code changes. |
| `/devex-review` | Live developer experience audit. Actually tests your onboarding flow. |
| `/scrape` | Pull structured data from a web page (~200ms after first prototype). |
| `/skillify` | Codify the most recent successful `/scrape` flow into a permanent browser-skill. |

### Release & Deploy
| Skill | What it does |
|-------|--------------|
| `/ship` | Sync main → tests → coverage audit → push → open PR. Bootstraps test framework if missing. |
| `/land-and-deploy` | Merge PR → wait for CI → deploy → verify production health. One command. |
| `/canary` | Post-deploy monitoring loop. Watches console errors, performance regressions. |
| `/document-release` | Update all project docs to match what just shipped. |
| `/document-generate` | Generate Diataxis docs (tutorial/how-to/reference/explanation) from code. |
| `/setup-deploy` | One-time deploy config detection (Fly.io, Render, Vercel, Railway, etc.). |

### Operational & Memory
| Skill | What it does |
|-------|--------------|
| `/context-save` | Save working context (git state, decisions, remaining work) as a checkpoint. |
| `/context-restore` | Resume from a saved context, even across Conductor workspaces. |
| `/learn` | Manage persistent learnings across sessions. Review, search, prune. |
| `/retro` | Weekly retro with per-person breakdowns, shipping streaks, test health trends. |
| `/health` | Code quality dashboard: type checker, linter, tests, dead code. |
| `/benchmark` | Page load times, Core Web Vitals, resource sizes. Compare before/after per PR. |
| `/benchmark-models` | Cross-model benchmark (Claude vs GPT vs Gemini) for skills. |

### Safety & Scoping
| Skill | What it does |
|-------|--------------|
| `/careful` | Warn before destructive commands (rm -rf, DROP TABLE, force-push). |
| `/freeze` | Lock edits to one directory. Hard block. |
| `/guard` | Activate both careful + freeze at once. |
| `/unfreeze` | Remove edit restrictions. |

### Browser & Agent Integration
| Skill | What it does |
|-------|--------------|
| `/browse` | The headless browser skill (this is what `$B` exposes). |
| `/open-gstack-browser` | Launch visible GStack Browser with sidebar + anti-bot stealth. |
| `/setup-browser-cookies` | Import cookies from real Chrome/Arc/Brave/Edge for authenticated testing. |
| `/pair-agent` | Share your browser with another AI agent (OpenClaw, Codex, Hermes, etc.). |

---

## Context Save / Restore

```bash
$B context-save    # Saves git state + decisions + remaining work
$B context-restore # Resumes from last checkpoint
```

- WIP commits get `WIP:` prefix + structured `[gstack-context]` body
- `/ship` filter-squashes WIP commits before PR (preserves non-WIP history)
- Continuous checkpoint mode: `gstack-config set checkpoint_mode continuous`
- Push is opt-in: `checkpoint_push=true` (default: local only, no CI triggers)

---

## Error Handling

| Error | Resolution |
|-------|-----------|
| `Element not found` | Run `snapshot -i` to get fresh refs |
| `Selector matched multiple elements` | Use `@refs` from `snapshot` instead |
| `Navigation timed out` | Check URL, retry, or increase timeout |
| `Daemon not running` | `$B` auto-starts on first call — just wait 3s |

For daemon issues:
```bash
pkill -f "gstack.*browse" 2>/dev/null  # Kill stale daemon
# Next $B call auto-starts it
```

---

## Installation Check

```bash
GSTACK_BIN="$HOME/.claude/skills/gstack/browse/dist/gstack"
if [ -f "$GSTACK_BIN" ]; then
  echo "gstack: $($GSTACK_BIN --version 2>/dev/null || echo 'ready')"
else
  echo "gstack: not installed"
fi
```

---

## gstack CLI Tools

```bash
gstack-config get/set/ls          # View/set config values
gstack-analytics                 # Local usage dashboard (from ~/.gstack/)
gstack-update-check              # Check for new version
gstack-model-benchmark            # Cross-model benchmark
gstack-taste-update              # Update design taste profile from approvals/rejections
gstack-security-dashboard          # Local security attempt log aggregator
gstack-uninstall                 # Clean removal of gstack
```

---

## Integration with ClawTeam

| Scenario | Approach |
|----------|---------|
| Spawn a worker with gstack loaded | `clawteam spawn --name w1 -- gstack` |
| QA test inside a spawned worker | Worker runs `/qa <url>` |
| Direct Hermes-side browser control | Use `$B` commands in Hermes terminal |
| Shared browser session | Worker does `$B cookie-import-browser` then shares cookie state |
| Cross-agent browser sharing | Worker does `$B handoff` → human solves → `$B resume` |
| Plan before building | Spawn worker → `/office-hours` → `/autoplan` → save plan |
| Review a branch | Spawn worker → `/review` → results come back via mailbox |
| Ship with full pipeline | Spawn worker → `/ship` → CI → `/land-and-deploy` |
| Security audit | Spawn worker → `/cso` (OWASP Top 10 + STRIDE) |

---

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `GSTACK_BIN` | Override gstack binary path | `~/.claude/skills/gstack/browse/dist/gstack` |
| `GSTACK_CLAUDE_BIN` | Path to Claude binary for gstack CLI | `claude` (searches PATH) |
| `GSTACK_ANTHROPIC_API_KEY` | Override Anthropic key (for Conductor) | from `ANTHROPIC_API_KEY` |
| `GSTACK_OPENAI_API_KEY` | Override OpenAI key (for Conductor) | from `OPENAI_API_KEY` |
| `GSTACK_HOME` | gstack state root | `~/.gstack/` |
| `GSTACK_SECURITY_ENSEMBLE=deberta` | Opt-in to 721MB DeBERTa ensemble | off (22MB BERT-small default) |
| `GSTACK_SECURITY_OFF=1` | Kill switch for ML security layer | off |