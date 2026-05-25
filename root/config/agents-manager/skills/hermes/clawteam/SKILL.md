---
name: clawteam
version: 1.0.0
category: devops
description: |
  Hermes integration for ClawTeam — multi-agent orchestration adapter that bridges
  Hermes to Claude Code CLI workers. ClawTeam is the operative skill for all agent
  coordination work: spawning workers, coordinating swarms, running browser-driven QA,
  and executing enterprise automation pipelines.

  Architecture: Hermes (leader) → ClawTeam (CLI adapter) → Claude Code workers
                                    ↕ via scripts/
                              gstack (headless browser, 30+ workflow skills)
                              ruflo  (314 MCP tools, 100+ agents, HNSW memory,
                                      self-learning swarms, AgentDB, Byzantine consensus)

triggers:
  - spawn agents / create a team / delegate to claude code
  - multi-agent coordination / launch a team / worker agents
  - coordinate agents / assign tasks to agents
  - clawteam spawn / team / task / inbox / launch
  - use gstack / ruflo / browse a page / run a gstack skill
  - qa test / office hours / context save / context restore
  - orchestrate agents / spawn swarm / memory store
  - agent federation / neural learning / run claude-flow
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Write
  - Patch
---

# ClawTeam — Multi-Agent Swarm Orchestration

## The Full Stack

```
HERMES (leader/orchestrator)
  └── ClawTeam  →  claude code --team attach <team>
       ├── scripts/gstack.md   →  headless $B, workflow skills, QA automation
       │                            (/qa, /ship, /review, /office-hours, etc.)
       └── scripts/ruflo.md    →  314 MCP tools, 100+ agents, HNSW memory,
                                   self-learning (SONA/EWC++), swarm topologies,
                                   hive-mind Byzantine consensus, AgentDB v3
```

**Load this skill first** whenever you need to delegate work, coordinate workers,
run browser automation, or orchestrate enterprise multi-agent pipelines.

---

## Directory Structure

```
clawteam/
├── SKILL.md                 ← This file. Entry point + architecture overview.
│                               Sections 1-5 are summaries — follow pointers
│                               to scripts/ and references/ for full detail.
│
├── scripts/
│   ├── gstack.md            ← Full $B browser command reference + workflow skills.
│   │                           Source: claude-commands/gstack/SKILL.md
│   │                           Usage: Load this when you need headless browser or
│   │                           QA automation in a spawned worker.
│   │                           Path: /waydriod/agent-installs/skills/hermes/clawteam/scripts/gstack.md
│   │
│   └── ruflo.md             ← Full ruflo MCP tool groups, CLI commands, swarm
│                               protocol, agents, plugins, federation, dual-mode.
│                               Source: claude-commands/ruflo/SKILL.md
│                               Usage: Load this when you need agent orchestration,
│                               HNSW memory, or self-learning swarms.
│                               Path: /waydriod/agent-installs/skills/hermes/clawteam/scripts/ruflo.md
│
├── references/
│   ├── presets.md           ← ClawTeam spawn presets (agent-loop, single-task,
│   │                           inspect-loop, interactive) — which to use when.
│   │
│   ├── patterns.md           ← 4 combined integration patterns showing how
│   │                           ClawTeam + gstack + ruflo work together end-to-end.
│   │
│   └── quick-ref.md          ← Single-page CLI command reference card.
│
└── claude-commands/
    ├── gstack/SKILL.md       ← Standalone gstack reference (preserved as-is).
    └── ruflo/SKILL.md        ← Standalone ruflo reference (preserved as-is).
```

---

## Part 1 — ClawTeam Core (Summarised)

Full command reference → `references/quick-ref.md`
Spawn presets → `references/presets.md`

### Team Lifecycle

```bash
clawteam team spawn-team <name>    # Create team (you are leader)
clawteam team list                  # List all teams
clawteam team attach <team>        # Attach → tiled tmux view of all workers
clawteam team status <team>        # Show team + worker status
clawteam team destroy <team>       # Destroy team
```

### Spawn Workers

```bash
clawteam spawn <worker-name> \
  --adapter claude \
  --preset agent-loop \
  --team <team> \
  --context "<instructions for the worker>"

# With model, backend, background
clawteam spawn coder-1 --adapter claude --model sonnet --backend tmux --team myteam --bg

# With custom context
clawteam spawn reviewer-1 \
  --adapter claude \
  --team myteam \
  --context "Review all PRs for: SQL injection, hardcoded secrets, \
    insecure deserialization, missing auth checks."
```

### Task Management

```bash
clawteam task create <team> <task-id> "<description>" --assign <worker>
clawteam task list <team>
clawteam task start <team> <task-id>
clawteam task done <team> <task-id>
```

### Inter-Agent Messaging (Mailbox)

```bash
clawteam inbox send <team> <worker> "<message>"     # Send to worker
clawteam inbox check <team> <worker>               # Check inbox
clawteam inbox broadcast <team> "<message>"         # Broadcast to all
```

---

## Part 2 — gstack (Summarised)

Full reference → `scripts/gstack.md`

**gstack runs on Claude Code workers** — include gstack instructions in the
worker's `--context` so it can invoke `$B` commands and `/skill-name` workflows.

### Quick gstack Overview

| Capability | Command / Skill |
|------------|-----------------|
| Headless browser | `$B goto <url>` `$B click @e3` `$B screenshot` |
| Browser assertions | `$B assert-text` `$B assert-visible` `$B assert-absent` |
| QA workflow | `/qa` — navigate, interact, assert, screenshot, generate regression tests |
| Ship checklist | `/ship` — sync → tests → coverage → push → open PR |
| Code review | `/review` — pre-landing review, auto-fixes obvious bugs |
| Product thinking | `/office-hours` — YC-style six forcing questions |
| Plan review | `/plan-ceo-review` `/plan-eng-review` `/plan-design-review` |
| Design | `/design-shotgun` `/design-html` |
| Context save/restore | `/context-save` `/context-restore` |
| Safety | `/careful` `/freeze` `/guard` `/unfreeze` |

### Spawning a gstack-enabled worker

```bash
clawteam spawn qa-worker \
  --adapter claude \
  --preset agent-loop \
  --team myteam \
  --context "
    Use gstack \$B for headless browser automation:
    - \$B goto <url>, \$B click <ref>, \$B fill <ref> '<text>', \$B screenshot
    - Workflow skill: /qa for full QA runs
    Task: Run QA on https://example.com
    - Login with test credentials
    - Assert all key elements visible
    - Screenshot final state
  "
```

---

## Part 3 — ruflo (Summarised)

Full reference → `scripts/ruflo.md`

**ruflo supercharges Claude Code workers** with 314 MCP tools, 100+ agent types,
self-learning neural routing (SONA + EWC++), and Byzantine fault-tolerant consensus.
Workers start the ruflo MCP server and call `agent_spawn`, `swarm_init`, `memory_search`.

### Quick ruflo Overview

| Capability | Command |
|------------|---------|
| Initialize project | `npx ruflo@latest init wizard` |
| Add MCP to Claude Code | `claude mcp add ruflo -- npx ruflo@latest mcp start` |
| Spawn agent | `npx claude-flow@v3alpha agent spawn -t coder --name <name>` |
| Init swarm | `npx claude-flow@v3alpha swarm init --topology hierarchical --max-agents 8` |
| Store memory | `npx claude-flow@v3alpha memory store --namespace <ns> --key <k> --value <v>` |
| Search memory | `npx claude-flow@v3alpha memory search --namespace <ns> --query <q>` |
| Hive-mind Byzantine | `npx ruflo@latest hive-mind spawn "<objective>"` |
| Self-learning status | `npx ruflo@latest hooks intelligence --status` |
| Security audit | `npx ruflo@latest security scan --depth full` |
| Federation (cross-machine) | `npx ruflo@latest federation init` |
| System diagnostics | `npx ruflo@latest doctor --fix` |

### MCP Tool Groups (available in workers)

```
intelligence : hooks_route, hooks_remember, hooks_recall, hooks_pretrain
agents       : agent_spawn, agent_list, swarm_init, task_create, workflow_execute
memory       : memory_store, memory_search, agentdb_hierarchical-store
devtools     : analyze_diff, performance_benchmark, github_repo_analyze
security     : aidefence_scan, claims_check (enable: MCP_GROUP_SECURITY=true)
browser      : browser_navigate, browser_click, browser_screenshot
neural       : neural_train, sona_trajectory, pattern_learn
```

### 3-Tier Model Routing (ADR-026)

| Tier | Handler | Latency | Cost | Use |
|------|---------|---------|------|-----|
| 1 | Agent Booster (WASM) | <1ms | $0 | Simple transforms: var→const, add types, async-await |
| 2 | Haiku | ~500ms | $0.0002 | Simple tasks, <30% complexity |
| 3 | Sonnet/Opus | 2-5s | $0.003-0.015 | Architecture, security, complex reasoning |

Watch for `[AGENT_BOOSTER_AVAILABLE]` — skip LLM for trivial transforms.

### Spawning a ruflo-enabled worker

```bash
clawteam spawn orchestrator \
  --adapter claude \
  --preset agent-loop \
  --team myteam \
  --context "
    You have ruflo MCP tools. Initialize swarm:
    1. Start MCP server: npx ruflo@latest mcp start
    2. Init swarm: mcp__swarm_init({ topology: hierarchical, maxAgents: 8, strategy: specialized })
    3. Spawn agents via Task tool: researcher → architect → coder → tester → reviewer
    4. Coordinate via SendMessage tool
    5. Store results in memory: memory_store --namespace results --key <findings>
  "
```

---

## Part 4 — Combined Patterns

Full patterns → `references/patterns.md`

### Pattern 1: Full-stack worker (Browser + Agents + Memory)

Spawn a worker with all three capabilities. The `--context` gives it everything it needs.

### Pattern 2: Swarm + Browser

Leader initialises ruflo swarm, ClawTeam spawns workers, each worker uses `$B` for browser tasks and MCP for coordination.

### Pattern 3: Multi-Agent Code Review

Review team + security-reviewer (ruflo hooks + agent_spawn) + ui-tester (gstack $B). Results returned via mailbox.

### Pattern 4: Enterprise Pipeline

Full stack diagram — orchestrator worker with ruflo swarm_init spawning architect/coder/tester/reviewer, gstack QA phase, memory_store for future recall.

---

## Part 5 — Environment Variables

```bash
# ClawTeam
CLAUDE_CODE_PATH=/path/to/claude       # Override claude binary path
CLAWTEAM_TEAM_DIR=~/.clawteam/teams    # Team state directory

# gstack
GSTACK_BROWSER_HEADLESS=true
GSTACK_VIEWPORT_WIDTH=1280
GSTACK_SCREENSHOT_DIR=./screenshots

# ruflo
ANTHROPIC_API_KEY=sk-ant-...
MCP_GROUP_INTELLIGENCE=true
MCP_GROUP_AGENTS=true
MCP_GROUP_MEMORY=true
MCP_GROUP_BROWSER=true
RUFLO_MCP_PORT=3001
```

---

## Quick Decision Guide

| Need | Action |
|------|--------|
| Spawn 1–5 workers for parallel tasks | `clawteam spawn` with `--adapter claude` |
| Complex multi-step pipeline | `clawteam` + ruflo swarm protocol |
| Browser-driven QA / screenshots | `clawteam` worker + `scripts/gstack.md` |
| Code review with inline comments | `clawteam` worker + gstack `/review` |
| Ship-ready checklist | `clawteam` worker + gstack `/ship` |
| Self-learning agent teams | `clawteam` + ruflo (SONA/EWC++) |
| HNSW vector memory recall | Worker uses ruflo `memory_search` |
| Byzantine fault-tolerant decisions | Worker uses ruflo `hive-mind` |
| Enterprise-grade orchestration | Full stack: ClawTeam + gstack + ruflo |

---

## Sub-Skills (bundled with clawteam)

- **gstack**: `scripts/gstack.md` — `$B` commands, workflow skills, integration patterns
- **ruflo**: `scripts/ruflo.md` — MCP tools, CLI commands, swarm protocol, agents, plugins, federation