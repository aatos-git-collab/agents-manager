# ruflo — Enterprise Multi-Agent Orchestration

> Full reference. Summary available in `../SKILL.md` Part 3.

## What is ruflo?

ruflo is a multi-agent orchestration platform for Claude Code (by ruv.io / Cognitum.One).
One `npx ruflo@latest init` gives you:

- **314 MCP tools** for agents, memory, swarm, hooks, security, providers
- **100+ specialized agents**: coder, tester, reviewer, architect, security-auditor,
  researcher, performance-engineer, memory-specialist, coordinator, planner
- **Swarm coordination**: hierarchical, mesh, adaptive topologies with queen-led
  Raft/Byzantine/Gossip consensus
- **HNSW vector memory**: 150x–12,500x faster search via AgentDB
- **SONA self-learning**: agents learn from successful patterns; EWC++ prevents forgetting
- **Agent federation**: cross-machine collaboration with zero-trust security, PII
  stripping, behavioral trust scoring
- **33 plugins**: core, swarm, RAG, security-audit, testgen, browser, observability,
  cost-tracker, neural-trader, and more
- **Dual-mode**: Claude Code + OpenAI Codex workers running in parallel with shared
  memory coordination

---

## Architecture

```
User (Hermes) --> ClawTeam --> [ Claude Code workers + ruflo MCP ]
                               --> Swarm --> 100+ agents
                               --> Memory (HNSW/AgentDB)
                               --> Federation (cross-machine)
```

---

## Installation Check

```bash
# Check if ruflo is available
npx ruflo@latest --version 2>/dev/null && echo "ruflo ready" || echo "ruflo not installed"

# Or via claude-flow
npx claude-flow@v3alpha --version 2>/dev/null && echo "claude-flow ready" || echo "not installed"
```

---

## MCP Tools (available in Claude Code workers)

ruflo tools are namespaced as `ruflo__<tool_name>`. Start the MCP server inside a worker:

```bash
# In the Claude Code worker's shell:
npx ruflo@latest mcp start

# Or with specific groups enabled:
MCP_GROUP_AGENTS=true MCP_GROUP_MEMORY=true npx ruflo@latest mcp start
```

### MCP Tool Groups

| Group | Tools | Enable env |
|-------|-------|------------|
| `intelligence` | hooks_route, hooks_remember, hooks_recall, hooks_pretrain, hooks_stats | MCP_GROUP_INTELLIGENCE |
| `agents` | agent_spawn, agent_list, agent_stop, swarm_init, swarm_start, task_create, workflow_execute | MCP_GROUP_AGENTS |
| `memory` | memory_store, memory_search, memory_retrieve, memory_list, agentdb_hierarchical-store, agentdb_hierarchical-recall, embeddings_generate | MCP_GROUP_MEMORY |
| `devtools` | analyze_diff, performance_benchmark, performance_bottleneck, github_repo_analyze, github_pr_manage, terminal_execute | MCP_GROUP_DEVTOOLS |
| `security` | aidefence_scan, claims_check, PII detection | MCP_GROUP_SECURITY=true |
| `browser` | browser_navigate, browser_click, browser_snapshot, browser_screenshot | MCP_GROUP_BROWSER=true |
| `neural` | neural_train, neural_predict, sona_trajectory, pattern_learn | MCP_GROUP_NEURAL=true |

### Key MCP Tool Examples

```javascript
// Swarm initialization
mcp__swarm_init({ topology: "hierarchical", maxAgents: 8, strategy: "specialized" })

// Agent spawning
mcp__agent_spawn({ type: "coder", name: "my-coder" })

// Memory operations
mcp__memory_store({ namespace: "patterns", key: "success-pattern", value: "..." })
mcp__memory_search({ namespace: "patterns", query: "authentication" })

// Self-learning
mcp__hooks_post-task({ taskId: "...", success: true, trainNeural: true })
mcp__neural_train({ pattern: "...", success: true })
```

---

## CLI Commands (from Hermes terminal)

```bash
# Initialize project with ruflo
npx ruflo@latest init wizard
npx ruflo@latest init                    # quick non-interactive

# Add ruflo MCP server to Claude Code
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
npx claude-flow@v3alpha memory stats

# Hooks and self-learning
npx claude-flow@v3alpha hooks post-task --task-id "task-123" --success true --train-neural true
npx claude-flow@v3alpha hooks transfer store --pattern "collab-success"
npx claude-flow@v3alpha hooks intelligence --status

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

## 100+ Agent Types

### Core Development (5)
`coder` · `tester` · `reviewer` · `planner` · `researcher`

### V3 Specialized (10)
`security-architect` · `security-auditor` · `memory-specialist` · `performance-engineer`
`queen-coordinator` · `hierarchical-coordinator` · `mesh-coordinator` · `adaptive-coordinator`
`byzantine-coordinator` · `raft-manager`

### Swarm Coordination (5)
`hierarchical-coordinator` · `mesh-coordinator` · `adaptive-coordinator` · `gossip-coordinator`

### Consensus & Distributed (7)
`byzantine-coordinator` · `raft-manager` · `gossip-coordinator` · `weighted-coordinator`

### Performance (5)
`perf-analyzer` · `performance-benchmarker` · `task-orchestrator`

### GitHub & Repository (9)
`pr-manager` · `code-review-swarm` · `issue-tracker` · `release-manager`

### SPARC Methodology (6)
`sparc-coord` · `specification` · `pseudocode` · `architecture`

### Specialized Dev (8)
`backend-dev` · `mobile-dev` · `ml-developer` · `cicd-engineer`

---

## Swarm Protocol — How Hermes Spawns Coordinated Work

For complex tasks (3+ files, multi-step feature, refactoring):

### Step 1: ClawTeam spawns a worker
```bash
clawteam spawn swarm-worker-1 --adapter claude --team myteam --bg
```

### Step 2: Worker initializes swarm via MCP
```javascript
mcp__swarm_init({
  topology: "hierarchical",    // hierarchical | mesh | ring | star | adaptive
  maxAgents: 8,               // smaller = less drift surface
  strategy: "specialized"     // specialized | balanced
})
```

### Step 3: Spawn agents via Claude Code Task tool (ALL IN ONE MESSAGE)
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

### Anti-Drift Configuration (ALWAYS use for coding)
```javascript
swarm_init({
  topology: "hierarchical",   // Single coordinator enforces alignment
  maxAgents: 8,              // Smaller team = less drift surface
  strategy: "specialized",   // Clear roles reduce ambiguity
  consensus: "raft"           // Leader maintains authoritative state
})
```

### Task → Agent Routing (Anti-Drift)
| Code | Task | Agents |
|------|------|--------|
| 1 | Bug Fix | coordinator, researcher, coder, tester |
| 3 | Feature | coordinator, architect, coder, tester, reviewer |
| 5 | Refactor | coordinator, architect, coder, reviewer |
| 7 | Performance | coordinator, perf-engineer, coder |
| 9 | Security | coordinator, security-architect, auditor |
| 11 | Memory | coordinator, memory-specialist, perf-engineer |

---

## Dual-Mode: Claude Code + Codex Collaboration

ruflo supports running Claude Code (🔵) and OpenAI Codex (🟢) workers in parallel
with shared memory coordination.

```bash
# Spawn both platforms via CLI
npx claude-flow-codex dual run \
  --worker "claude:architect:Design API" \
  --worker "codex:coder:Implement REST endpoints" \
  --worker "claude:tester:Write integration tests" \
  --worker "codex:reviewer:Review code quality" \
  --namespace "api-feature"

# Use templates
npx claude-flow-codex dual run feature --task "Add OAuth login"
npx claude-flow-codex dual run security --target "./src"
npx claude-flow-codex dual run refactor --target "./src/legacy"

# Check status
npx claude-flow-codex dual status
npx claude-flow-codex dual templates
```

### Platform Strengths
| Task Type | Preferred | Reason |
|-----------|-----------|--------|
| Architecture & Design | 🔵 Claude | Strong reasoning, system thinking |
| Implementation | 🟢 Codex | Fast code generation |
| Security Review | 🔵 Claude | Careful analysis, threat modeling |
| Performance Optimization | 🟢 Codex | Code-level optimizations |
| Testing Strategy | 🔵 Claude | Coverage analysis, edge cases |
| Refactoring | 🟢 Codex | Bulk code transformations |

---

## 3-Tier Model Routing (ADR-026)

ruflo routes tasks intelligently — skip expensive LLM calls for simple tasks:

| Tier | Handler | Latency | Cost | Use |
|------|---------|---------|------|-----|
| 1 | Agent Booster (WASM) | <1ms | $0 | Simple transforms: var→const, add types, async-await, add logging |
| 2 | Haiku | ~500ms | $0.0002 | Simple tasks, <30% complexity |
| 3 | Sonnet/Opus | 2-5s | $0.003-0.015 | Architecture, security, complex reasoning |

Watch for `[AGENT_BOOSTER_AVAILABLE]` — skip LLM for trivial transforms.
Watch for `[TASK_MODEL_RECOMMENDATION] Use model="haiku"` — pass model to Task tool.

---

## 33 Plugins Reference

### Core & Orchestration
`ruflo-core` · `ruflo-swarm` · `ruflo-autopilot` · `ruflo-loop-workers` · `ruflo-workflows` · `ruflo-federation`

### Memory & Knowledge
`ruflo-agentdb` · `ruflo-rag-memory` · `ruflo-rvf` · `ruflo-ruvector` · `ruflo-knowledge-graph`

### Intelligence & Learning
`ruflo-intelligence` · `ruflo-graph-intelligence` · `ruflo-daa` · `ruflo-ruvllm` · `ruflo-goals`

### Code Quality & Testing
`ruflo-testgen` · `ruflo-browser` · `ruflo-jujutsu` · `ruflo-docs`

### Security & Compliance
`ruflo-security-audit` · `ruflo-aidefence`

### Architecture & Methodology
`ruflo-adr` · `ruflo-ddd` · `ruflo-sparc`

### DevOps & Observability
`ruflo-migrations` · `ruflo-observability` · `ruflo-cost-tracker`

---

## Federation (Cross-Machine Agents)

Agents on different machines collaborate with zero-trust security:

```bash
# Initialize federation
npx claude-flow@v3alpha federation init

# Join another team's endpoint
npx claude-flow@v3alpha federation join wss://team-b.example.com:8443

# Send task — PII stripped automatically
npx claude-flow@v3alpha federation send --to team-b --type task-request \
  --message "Analyze transaction patterns"

# Check trust levels
npx claude-flow@v3alpha federation status
```

Trust scoring: `0.4×success + 0.2×uptime + 0.2×threat + 0.2×integrity`

---

## Hive-Mind (Queen-Led Collective Intelligence)

```bash
# Start hive-mind with queen coordination
npx ruflo@latest hive-mind spawn "Implement user authentication"

# Queen types: strategic | tactical | adaptive
# Worker types: researcher, coder, analyst, tester, architect, reviewer, optimizer, documenter
# Consensus: majority | weighted (queen 3x) | byzantine (f < n/3)
```

### Collective Memory Types
`knowledge` (permanent) · `context` (1h TTL) · `task` (30min TTL) · `result` (permanent)
`error` (24h TTL) · `metric` (1h TTL) · `consensus` (permanent) · `system` (permanent)

---

## Integration with ClawTeam + gstack

### Pattern: Full-stack multi-agent pipeline
```bash
# 1. Hermes spawns a gstack-enabled worker with ruflo
clawteam spawn pipeline-1 --adapter claude --team myteam

# 2. Worker installs ruflo MCP (if not already)
# In worker session:
claude mcp add ruflo -- npx ruflo@latest mcp start

# 3. Initialize swarm
mcp__swarm_init({ topology: "hierarchical", maxAgents: 8, strategy: "specialized" })

# 4. Spawn agents (architect → coder → tester → reviewer)
Task({ name: "architect", subagent_type: "system-architect", run_in_background: true, ... })
Task({ name: "coder", subagent_type: "coder", run_in_background: true, ... })
Task({ name: "tester", subagent_type: "tester", run_in_background: true, ... })
Task({ name: "reviewer", subagent_type: "reviewer", run_in_background: true, ... })

# 5. Start pipeline
SendMessage({ to: "architect", message: "[goal]" })

# 6. Worker uses gstack for QA phase
# /qa https://staging.example.com
```

### Pattern: Parallel workers with shared memory
```bash
# Spawn 3 workers, each running a different specialist
clawteam spawn coder-1 --adapter claude --team myteam --bg
clawteam spawn qa-1 --adapter claude --team myteam --bg
clawteam spawn sec-1 --adapter claude --team myteam --bg

# coder-1: implements feature, stores progress in memory
# qa-1: runs /qa on staging, stores bug reports
# sec-1: runs security audit, stores findings

# Hermes retrieves all results via shared memory
npx claude-flow@v3alpha memory search --namespace results --query "security findings"
```

---

## Behavioral Rules (for Claude Code workers with ruflo)

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

## Error Handling

| Error | Resolution |
|-------|-----------|
| `swarm init failed` | Check API keys, retry |
| `agent not responding` | `clawteam inbox send <name> -- ping` |
| `memory search empty` | Increase HNSW recall, check namespace |
| `federation handshake failed` | Verify mTLS certs, check endpoint URL |

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Anthropic key for Claude provider |
| `OPENAI_API_KEY` | OpenAI key for Codex |
| `CLAUDE_MCP` | MCP server config for Claude Code |
| `RUFLO_HOME` | ruflo state root (default: `~/.claude-flow/`) |
| `AGENTDB_PATH` | AgentDB vector database path |
| `HNSW_INDEX` | Enable HNSW indexing (150x–12,500x faster) |