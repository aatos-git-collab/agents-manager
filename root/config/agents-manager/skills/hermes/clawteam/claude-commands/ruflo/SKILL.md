---
name: hermes-ruflo
version: 1.0.0
description: |
  Hermes integration for Ruflo — multi-agent AI orchestration for Claude Code. Ruflo
  gives Claude Code 100+ specialized agents, MCP tools, swarm coordination, HNSW
  vector memory, SONA self-learning, and agent federation across trust boundaries.
  Hermes uses ClawTeam to spawn Claude Code workers and drives them via Ruflo's
  MCP tools and CLI commands.
triggers:
  - orchestrate agents
  - spawn swarm
  - use ruflo
  - multi-agent coordination
  - memory store
  - agent federation
  - neural learning
  - run claude-flow
---

# hermes-ruflo — Hermes × Ruflo Integration

## What is Ruflo?

Ruflo is a multi-agent orchestration platform for Claude Code (by ruv.io / Cognitum.One).
One `npx ruflo@latest init` gives you:

- **314 MCP tools** for agents, memory, swarm, hooks, security, providers
- **100+ specialized agents**: coder, tester, reviewer, architect, security-auditor,
  researcher, performance-engineer, memory-specialist, and more
- **Swarm coordination**: hierarchical, mesh, adaptive topologies with queen-led
  Raft/Byzantine/Gossip consensus
- **HNSW vector memory**: 150x-12,500x faster search via AgentDB
- **SONA self-learning**: agents learn from successful patterns
- **Agent federation**: cross-machine collaboration with zero-trust security, PII
    stripping, behavioral trust scoring
- **33 plugins**: core, swarm, RAG, security-audit, testgen, browser, observability,
  cost-tracker, neural-trader, and more
- **Dual-mode**: Claude Code + OpenAI Codex workers running in parallel with shared
    memory coordination

---

## Architecture

```
User (Hermes) --> ClawTeam --> [ Claude Code workers + Ruflo MCP ]
                               --> Swarm --> 100+ agents
                               --> Memory (HNSW/AgentDB)
                               --> Federation (cross-machine)
```

---

## Installation Check

```bash
# Check if Ruflo is available
npx ruflo@latest --version 2>/dev/null && echo "ruflo ready" || echo "ruflo not installed"

# Or via claude-flow
npx claude-flow@v3alpha --version 2>/dev/null && echo "claude-flow ready" || echo "not installed"
```

---

## Core Commands (MCP Tools & CLI)

Ruflo exposes tools via MCP server and CLI. Use MCP tools when Claude Code workers
are running. Use CLI directly from Hermes terminal for orchestration commands.

### MCP Tools (available in Claude Code workers)

```javascript
// Swarm initialization
mcp__ruv-swarm__swarm_init({
  topology: "hierarchical",  // hierarchical | mesh | adaptive
  maxAgents: 8,
  strategy: "specialized"   // specialized | balanced
})

// Agent spawning (via Task tool + MCP)
// STEP 1: Initialize
mcp__ruv-swarm__swarm_init({ topology: "hierarchical", maxAgents: 8, strategy: "specialized" })

// STEP 2: Spawn agents via Task tool (Claude Code's native concurrency)
// STEP 3: Coordinate via SendMessage tool

// Memory operations
mcp__ruv-memory__store({ namespace: "patterns", key: "success-pattern", value: "..." })
mcp__ruv-memory__search({ namespace: "patterns", query: "authentication" })
mcp__ruv-memory__retrieve({ namespace: "results", key: "findings" })

// Neural learning
mcp__ruv-neural__train({ pattern: "...", success: true })
mcp__ruv-neural__predict({ context: "..." })

// Hooks (17 hooks + 12 background workers)
mcp__ruv-hooks__post-task({ taskId: "...", success: true, trainNeural: true })
```

### CLI Commands (from Hermes terminal)

```bash
# Initialize project with Ruflo
npx ruflo@latest init wizard

# Or quick non-interactive init
npx ruflo@latest init

# Add Ruflo MCP server to Claude Code
claude mcp add ruflo -- npx ruflo@latest mcp start

# Agent management
npx claude-flow@v3alpha agent spawn --type coder --name my-coder
npx claude-flow@v3alpha agent list
npx claude-flow@v3alpha agent status <name>
npx claude-flow@v3alpha agent stop <name>

# Swarm coordination
npx claude-flow@v3alpha swarm init --topology hierarchical --max-agents 8
npx claude-flow@v3alpha swarm start --objective "Build auth API" --strategy specialized
npx claude-flow@v3alpha swarm status

# Memory (HNSW-indexed)
npx claude-flow@v3alpha memory store --namespace patterns --key "auth-pattern" --value "..."
npx claude-flow@v3alpha memory search --namespace patterns --query "OAuth patterns"
npx claude-flow@v3alpha memory list --namespace patterns

# Hooks and self-learning
npx claude-flow@v3alpha hooks post-task --task-id "task-123" --success true --train-neural true
npx claude-flow@v3alpha hooks transfer store --pattern "collab-success"

# Neural patterns
npx claude-flow@v3alpha neural train --pattern "refactor-success" --success true
npx claude-flow@v3alpha neural status

# Security scanning
npx claude-flow@v3alpha security scan --depth full
npx claude-flow@v3alpha security audit --target "./src"

# Performance
npx claude-flow@v3alpha performance benchmark --suite all

# System diagnostics
npx claude-flow@v3alpha doctor --fix

# Federation (cross-machine agent collaboration)
npx claude-flow@v3alpha federation init
npx claude-flow@v3alpha federation join wss://peer.example.com:8443
npx claude-flow@v3alpha federation send --to peer-name --type task-request --message "..."
npx claude-flow@v3alpha federation status

# Daemon (background workers)
npx claude-flow@v3alpha daemon start
npx claude-flow@v3alpha daemon status
```

---

## Agent Types (60+)

| Type | Role |
|------|------|
| `coder` | Writes implementation code |
| `tester` | Writes and runs tests |
| `reviewer` | Reviews code quality, security |
| `architect` | Designs system architecture |
| `security-architect` | Security design and threat modeling |
| `security-auditor` | CVE scanning, vulnerability assessment |
| `performance-engineer` | Optimization, benchmarking |
| `researcher` | Requirement analysis, exploration |
| `memory-specialist` | Memory namespace management |
| `coordinator` | Orchestrates other agents |
| `planner` | GOAP/A* planning, goal decomposition |

---

## Swarm Protocol — How Hermes Spawns Coordinated Work

When a task needs multiple agents (3+ files, complex feature, refactoring):

### Step 1: ClawTeam spawns a worker
```bash
clawteam spawn --name swarm-worker-1 -- gstack
```

### Step 2: Worker initializes swarm via MCP
```javascript
mcp__ruv-swarm__swarm_init({
  topology: "hierarchical",
  maxAgents: 8,
  strategy: "specialized"
})
```

### Step 3: Spawn agents via Claude Code's Task tool (all in ONE message)
```javascript
Task({ name: "architect", subagent_type: "system-architect",
  prompt: "Design the auth API. SendMessage to 'coder' when done.", run_in_background: true })
Task({ name: "coder", subagent_type: "coder",
  prompt: "Wait for design from 'architect'. Implement. SendMessage to 'tester'.", run_in_background: true })
Task({ name: "tester", subagent_type: "tester",
  prompt: "Wait for implementation from 'coder'. Write tests. SendMessage to 'reviewer'.", run_in_background: true })
Task({ name: "reviewer", subagent_type: "reviewer",
  prompt: "Wait for tests from 'tester'. Review quality. Report findings.", run_in_background: true })
```

### Step 4: Start the pipeline
```javascript
SendMessage({ to: "architect", summary: "Start", message: "[task description]" })
```

### Step 5: Memory coordination
```bash
npx claude-flow@v3alpha memory store --namespace collaboration --key "context" --value "[task]"
```

---

## Dual-Mode: Claude Code + Codex Collaboration

Ruflo supports running Claude Code (🔵) and OpenAI Codex (🟢) workers in parallel
with shared memory coordination.

```bash
# Spawn both platforms via CLI
npx claude-flow-codex dual run --worker "claude:architect:Design API" \
  --worker "codex:coder:Implement REST endpoints" \
  --worker "claude:tester:Write integration tests" \
  --worker "codex:reviewer:Review code quality" \
  --namespace "api-feature"

# Or use templates
npx claude-flow-codex dual run feature --task "Add OAuth login"
npx claude-flow-codex dual run security --target "./src"
npx claude-flow-codex dual run refactor --target "./src/legacy"

# Check status
npx claude-flow-codex dual status
npx claude-flow-codex dual templates
```

---

## Model Routing (3-Tier)

Ruflo routes tasks intelligently:

| Tier | Handler | Latency | Cost | Use |
|------|---------|---------|------|-----|
| 1 | Agent Booster (WASM) | <1ms | $0 | Simple transforms (var→const, add types) |
| 2 | Haiku | ~500ms | $0.0002 | Simple tasks, <30% complexity |
| 3 | Sonnet/Opus | 2-5s | $0.003-0.015 | Complex reasoning, architecture, security |

Watch for `[AGENT_BOOSTER_AVAILABLE]` flag — skip LLM for trivial transforms.

---

## 33 Plugins Reference

### Core & Orchestration
| Plugin | Purpose |
|--------|---------|
| `ruflo-core` | Foundation — server, health checks, plugin discovery |
| `ruflo-swarm` | Coordinate multiple agents as a team |
| `ruflo-autopilot` | Let agents run autonomously in a loop |
| `ruflo-loop-workers` | Schedule background tasks on a timer |
| `ruflo-workflows` | Reusable multi-step task templates |
| `ruflo-federation` | Agents on different machines collaborate securely |

### Memory & Knowledge
| Plugin | Purpose |
|--------|---------|
| `ruflo-agentdb` | Fast vector database for agent memory |
| `ruflo-rag-memory` | Smart retrieval — hybrid search, graph hops |
| `ruflo-rvf` | Save and restore agent memory across sessions |
| `ruflo-ruvector` | GPU-accelerated search, Graph RAG, 103 tools |
| `ruflo-knowledge-graph` | Build and traverse entity relationship maps |

### Intelligence & Learning
| Plugin | Purpose |
|--------|---------|
| `ruflo-intelligence` | SONA self-learning from past successes |
| `ruflo-graph-intelligence` | Sublinear graph reasoning (PageRank, A*) |
| `ruflo-daa` | Dynamic agent behavior and cognitive patterns |
| `ruflo-ruvllm` | Run local LLMs (Ollama) with smart routing |
| `ruflo-goals` | Break goals into plans, track progress |

### Code Quality & Testing
| Plugin | Purpose |
|--------|---------|
| `ruflo-testgen` | Find missing tests, auto-generate |
| `ruflo-browser` | Automate browser testing with Playwright |
| `ruflo-jujutsu` | Analyze git diffs, score risk, suggest reviewers |
| `ruflo-docs` | Generate and maintain documentation |

### Security & Compliance
| Plugin | Purpose |
|--------|---------|
| `ruflo-security-audit` | Scan for vulnerabilities and CVEs |
| `ruflo-aidefence` | Block prompt injection, detect PII |

### Architecture & Methodology
| Plugin | Purpose |
|--------|---------|
| `ruflo-adr` | Architecture decision records (living) |
| `ruflo-ddd` | Domain-driven design scaffolding |
| `ruflo-sparc` | 5-phase development methodology |

### DevOps & Observability
| Plugin | Purpose |
|--------|---------|
| `ruflo-migrations` | Database schema change management |
| `ruflo-observability` | Structured logs, traces, metrics |
| `ruflo-cost-tracker` | Token usage tracking, budgets, alerts |

---

## Integration with ClawTeam + gstack

### Pattern: Full-stack multi-agent pipeline

```bash
# 1. Hermes spawns a gstack-enabled worker with Ruflo
clawteam spawn --name pipeline-1 -- gstack

# 2. Worker installs Ruflo MCP (if not already)
# In worker session:
# claude mcp add ruflo -- npx ruflo@latest mcp start

# 3. Initialize swarm
mcp__ruv-swarm__swarm_init({
  topology: "hierarchical",
  maxAgents: 8,
  strategy: "specialized"
})

# 4. Spawn agents (architect → coder → tester → reviewer)
Task({ name: "architect", subagent_type: "system-architect", run_in_background: true, ... })
Task({ name: "coder", subagent_type: "coder", run_in_background: true, ... })
Task({ name: "tester", subagent_type: "tester", run_in_background: true, ... })
Task({ name: "reviewer", subagent_type: "reviewer", run_in_background: true, ... })

# 5. Start pipeline
SendMessage({ to: "architect", message: "[goal description]" })

# 6. Worker uses gstack for QA phase
# /qa https://staging.example.com
# $B snapshot -i
```

### Pattern: Parallel workers with shared memory
```bash
# Spawn 3 workers, each running different specialist
clawteam spawn --name coder-1 -- gstack
clawteam spawn --name qa-1 -- gstack
clawteam spawn --name sec-1 -- gstack

# Each worker:
# - coder-1: implements feature, stores progress in memory
# - qa-1: runs /qa on staging, stores bug reports
# - sec-1: runs /cso security audit, stores findings

# Hermes retrieves all results via shared memory namespace
npx claude-flow@v3alpha memory search --namespace results --query "security findings"
```

---

## Federation (Cross-Machine Agents)

Agents on different machines collaborate with zero-trust security:

```bash
# Team A: initialize federation
npx claude-flow@v3alpha federation init

# Team A: join Team B's endpoint
npx claude-flow@v3alpha federation join wss://team-b.example.com:8443

# Send task — PII stripped automatically
npx claude-flow@v3alpha federation send --to team-b --type task-request \
  --message "Analyze transaction patterns"

# Check trust levels
npx claude-flow@v3alpha federation status
```

Trust scoring: `0.4×success + 0.2×uptime + 0.2×threat + 0.2×integrity`

---

## Key Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Anthropic key for Claude provider |
| `OPENAI_API_KEY` | OpenAI key for Codex |
| `CLAUDE_MCP` | MCP server config for Claude Code |
| `RUFLO_HOME` | Ruflo state root (default: `~/.claude-flow/`) |
| `AGENTDB_PATH` | AgentDB vector database path |
| `HNSW_INDEX` | Enable HNSW indexing (150x-12,500x faster) |

---

## Error Handling

| Error | Resolution |
|-------|-----------|
| `swarm init failed` | Check API keys, retry |
| `agent not responding` | `clawteam mailbox send <name> -- ping` |
| `memory search empty` | Increase HNSW recall, check namespace |
| `federation handshake failed` | Verify mTLS certs, check endpoint URL |

---

## Behavioral Rules (for Claude Code workers with Ruflo)

1. **Do what was asked — nothing more, nothing less**
2. **NEVER create files unless absolutely necessary**
3. **ALWAYS prefer editing existing files over creating new ones**
4. **NEVER proactively create documentation unless requested**
5. **NEVER save working files to root folder** — use `/src`, `/tests`, `/docs`
6. **ALWAYS read a file before editing it**
7. **Batch ALL operations in ONE message** — todos, agent spawns, file reads, terminal commands, memory ops
8. **NEVER commit secrets, credentials, or .env files**
9. **NEVER continuously check status after spawning swarm** — wait for results
10. **Use `claude -p` for headless parallel background work**

---

## Quick Reference Card

| Need | Command |
|------|---------|
| Initialize project | `npx ruflo@latest init wizard` |
| Add MCP to Claude | `claude mcp add ruflo -- npx ruflo@latest mcp start` |
| Spawn agent | `npx claude-flow@v3alpha agent spawn -t coder --name <name>` |
| Init swarm | `npx claude-flow@v3alpha swarm init --topology hierarchical --max-agents 8` |
| Store memory | `npx claude-flow@v3alpha memory store --namespace <ns> --key <k> --value <v>` |
| Search memory | `npx claude-flow@v3alpha memory search --namespace <ns> --query <q>` |
| Run security audit | `npx claude-flow@v3alpha security scan --depth full` |
| Federation init | `npx claude-flow@v3alpha federation init` |
| Check system health | `npx claude-flow@v3alpha doctor --fix` |
| Dual-mode collab | `npx claude-flow-codex dual run feature --task "<task>"` |