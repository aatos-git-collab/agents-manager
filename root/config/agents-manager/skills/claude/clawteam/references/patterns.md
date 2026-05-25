# Integration Patterns — ClawTeam + gstack + ruflo

> 4 end-to-end patterns showing how the full stack works together.
> Part of `clawteam/` skill — see `SKILL.md` Part 4 for overview.

---

## Pattern 1: Full-Stack Worker (Browser + Agents + Memory)

**Use when:** Task needs browser automation, multi-agent coordination, AND vector memory.
**Spawns:** 1 worker that does everything.

```
Hermes (leader)
  └── ClawTeam spawn qa-worker --context "
        - gstack $B: headless browser for QA
        - ruflo MCP: agent_spawn, memory_store/search
        - /qa: full QA workflow
        - Store results in HNSW memory
      "
        └── Claude Code worker
              ├── gstack $B → browser automation
              ├── ruflo MCP → spawns sub-agents, stores in vector DB
              └── results → leader via inbox
```

### Step-by-step

```bash
# 1. Create team
clawteam team spawn-team qa-team

# 2. Spawn full-stack worker
clawteam spawn qa-worker \
  --adapter claude \
  --preset agent-loop \
  --team qa-team \
  --context "
    You have access to:
    1. gstack: Use \$B for headless browser automation
       - \$B goto <url>, \$B click <ref>, \$B fill <ref> '<text>'
       - \$B snapshot -i, \$B screenshot
       - Workflow: /qa https://staging.example.com
    2. ruflo: Use MCP tools for agent orchestration
       - agent_spawn: spawn sub-agents for parallel sub-tasks
       - memory_search: recall patterns from HNSW vector DB
       - memory_store: store QA results with embeddings
       - hooks_route: intelligent task routing

    Task: Run QA on https://staging.example.com
    Steps:
    1. Login with test credentials (user: test@example.com, pass: Test123!)
    2. Navigate to /dashboard
    3. Assert key elements are visible (nav, user menu, content area)
    4. Screenshot final state
    5. Store results in memory with embeddings for future QA runs
    6. Report findings to leader via inbox
  "
```

### Worker execution (inside Claude Code)

```javascript
// Start gstack daemon + ruflo MCP
$B goto https://staging.example.com

// Run QA workflow
$B fill @e3 "test@example.com"
$B fill @e4 "Test123!"
$B click @e5  // Login button

$B snapshot -i
$B assert-visible ".dashboard"
$B assert-visible ".user-menu"

$B screenshot /tmp/qa-final.png

// Store in HNSW memory
mcp__memory_store({
  namespace: "qa-results",
  key: "staging-dashboard-$(date +%Y%m%d)",
  value: JSON.stringify({ url: "https://staging.example.com/dashboard", status: "pass", screenshot: "/tmp/qa-final.png" })
})

// Report to leader
clawteam inbox send qa-team leader "QA complete. Dashboard passes all assertions. Screenshot saved."
```

---

## Pattern 2: Swarm + Browser (ruflo swarm workers with gstack)

**Use when:** Complex task requiring multiple coordinated agents with browser capability.
**Spawns:** 1 orchestrator worker that inits ruflo swarm → spawns sub-agents.

```
Hermes (leader)
  ├── ClawTeam spawn orchestrator --context "init ruflo swarm + spawn agents"
  │     └── ruflo swarm_init → Task tool spawns:
  │           ├── architect (no browser needed)
  │           ├── coder (no browser needed)
  │           ├── tester (uses gstack $B for QA)
  │           └── reviewer (uses gstack $B for visual review)
  └── Results collected via ruflo memory
```

### Step-by-step

```bash
# 1. Create team
clawteam team spawn-team feature-team

# 2. Spawn orchestrator
clawteam spawn orchestrator \
  --adapter claude \
  --preset agent-loop \
  --team feature-team \
  --context "
    Initialize ruflo swarm and spawn coordinated agents.
    1. Start ruflo MCP: npx ruflo@latest mcp start
    2. Initialize swarm:
       mcp__swarm_init({ topology: 'hierarchical', maxAgents: 6, strategy: 'specialized' })
    3. Spawn agents via Task tool (all in ONE message):
       - architect: Design the feature. SendMessage to 'coder' when done.
       - coder: Implement based on design. SendMessage to 'tester' when done.
       - tester: Write tests. Use gstack \$B to run QA on staging URL.
                  Store results via memory_store. SendMessage to 'reviewer'.
       - reviewer: Final review. SendMessage to leader when done.
    4. Start pipeline: SendMessage({ to: 'architect', message: '[task description]' })
    5. Store final results in memory.
  "
```

### Orchestrator execution

```javascript
// Init ruflo MCP server
$B --version  # ensure gstack available

// Initialize swarm
mcp__swarm_init({
  topology: "hierarchical",
  maxAgents: 6,
  strategy: "specialized",
  consensus: "raft"
})

// Spawn ALL agents in ONE message (Claude Code Task tool)
Task({ name: "architect", subagent_type: "system-architect",
  prompt: "Design the auth module. Store design in memory. SendMessage to 'coder'.", run_in_background: true })
Task({ name: "coder", subagent_type: "coder",
  prompt: "Implement auth module. SendMessage to 'tester'.", run_in_background: true })
Task({ name: "tester", subagent_type: "tester",
  prompt: "Write tests. Use gstack \$B to QA staging. Store results. SendMessage to 'reviewer'.", run_in_background: true })
Task({ name: "reviewer", subagent_type: "reviewer",
  prompt: "Review results. Report to leader.", run_in_background: true })

// Start
SendMessage({ to: "architect", message: "Build user authentication API with JWT" })
```

---

## Pattern 3: Multi-Agent Code Review

**Use when:** PR review requiring both static analysis AND browser-based UI testing.
**Spawns:** 2 workers — security-reviewer (inspect-loop) + ui-tester (agent-loop).

```
Hermes (leader)
  ├── ClawTeam spawn security-reviewer (inspect-loop)
  │     └── ruflo hooks + agent_spawn for deep static scan
  ├── ClawTeam spawn ui-tester (agent-loop)
  │     └── gstack $B for visual QA
  └── Both report to leader via inbox
```

### Step-by-step

```bash
# 1. Create review team
clawteam team spawn-team review-team

# 2. Spawn security reviewer (read-only)
clawteam spawn security-reviewer \
  --adapter claude \
  --preset inspect-loop \
  --team review-team \
  --context "
    Static security review of src/auth/
    Check: SQL injection, XSS, hardcoded secrets, insecure deserialization,
    missing auth checks, JWT vulnerabilities.
    Use ruflo hooks and agent_spawn for parallel analysis.
    Report findings to leader. Do NOT modify any files.
  "

# 3. Spawn UI tester (browser-driven)
clawteam spawn ui-tester \
  --adapter claude \
  --preset agent-loop \
  --team review-team \
  --context "
    Use gstack \$B to test auth UI at https://staging.example.com
    - Test login form with valid/invalid credentials
    - Assert error messages appear correctly
    - Test password reset flow
    - Screenshot all key states
    Store results in memory. Report to leader via inbox.
  "

# 4. Monitor results
clawteam inbox read review-team leader --all
```

### Security reviewer execution

```javascript
// Use ruflo for parallel deep scan
mcp__hooks_pre-task({ taskId: "security-scan" })

// Spawn sub-agents for parallel analysis
Task({ name: "sql-reviewer", subagent_type: "security-auditor",
  prompt: "Find SQL injection vectors in src/auth/", run_in_background: true })
Task({ name: "secret-scanner", subagent_type: "security-auditor",
  prompt: "Find hardcoded secrets/API keys in src/auth/", run_in_background: true })
Task({ name: "auth-checker", subagent_type: "security-auditor",
  prompt: "Check missing auth checks in src/api/", run_in_background: true })

// Collect results
mcp__memory_store({ namespace: "security-findings", key: "pr-42", value: "[...]" })

// Report to leader
clawteam inbox send review-team leader "Security review complete. 2 medium, 1 low severity findings."
```

---

## Pattern 4: Enterprise Pipeline (Full Stack)

**Use when:** Complete feature delivery — design through deployment with QA and memory.
**Spawns:** 1 orchestrator + 4 specialized agents.

```
Hermes (leader)
  └── ClawTeam team spawn-team pipeline-team
        └── ClawTeam spawn orchestrator (ruflo MCP active)
              ├── ruflo swarm_init (hierarchical, specialized, raft)
              │     └── Task tool spawns:
              │           ├── architect
              │           ├── coder
              │           ├── tester (gstack $B for QA)
              │           └── reviewer
              ├── ruflo memory_store (HNSW, 150x faster recall)
              ├── gstack /qa (staging verification)
              ├── gstack /ship (PR + CI)
              └── results → leader via mailbox
```

### Step-by-step

```bash
# 1. Create pipeline team
clawteam team spawn-team pipeline-team

# 2. Spawn orchestrator with full-stack context
clawteam spawn orchestrator \
  --adapter claude \
  --preset agent-loop \
  --team pipeline-team \
  --context "
    You are running the enterprise feature pipeline.
    Stack: ClawTeam + gstack + ruflo

    STEP 1 — SWARM INIT
    Start ruflo MCP: npx ruflo@latest mcp start
    Initialize swarm:
      mcp__swarm_init({ topology: 'hierarchical', maxAgents: 8, strategy: 'specialized', consensus: 'raft' })

    STEP 2 — SPAWN AGENTS (via Task tool, all in ONE message)
    - architect: Design feature architecture. Store in memory. SendMessage to 'coder'.
    - coder: Implement based on design. SendMessage to 'tester'.
    - tester: Write tests AND run gstack QA on staging.
              Use: \$B goto <staging-url>, \$B snapshot -i, \$B assert-*
              Store results in memory. SendMessage to 'reviewer'.
    - reviewer: Code quality + security review. Report to leader.

    STEP 3 — START PIPELINE
    SendMessage({ to: 'architect', message: '[feature description]' })

    STEP 4 — SHIP
    After all agents complete:
    - Run gstack /ship to sync, test, push, open PR
    - Store final artifacts in memory with embeddings

    STEP 5 — REPORT
    Send final summary to leader via inbox.
  "
```

### Orchestrator pipeline execution

```javascript
// 1. Init
await $B --version  // verify gstack
npx ruflo@latest mcp start

// 2. Init swarm
mcp__swarm_init({
  topology: "hierarchical",
  maxAgents: 8,
  strategy: "specialized",
  consensus: "raft",
  checkpointInterval: 300  // 5min checkpoints for anti-drift
})

// 3. Spawn all agents (ALL IN ONE MESSAGE)
Task({ name: "architect", subagent_type: "system-architect",
  prompt: "Design the feature. Store design in memory namespace 'pipeline'. SendMessage to 'coder'.", run_in_background: true })
Task({ name: "coder", subagent_type: "coder",
  prompt: "Implement feature from architect's design. SendMessage to 'tester'.", run_in_background: true })
Task({ name: "tester", subagent_type: "tester",
  prompt: "Write tests AND run gstack QA on staging. \$B goto https://staging.example.com. Assert all elements. Store results. SendMessage to 'reviewer'.", run_in_background: true })
Task({ name: "reviewer", subagent_type: "reviewer",
  prompt: "Final review. Store summary. Report to leader.", run_in_background: true })

// 4. Start
SendMessage({ to: "architect", message: "Build user auth with OAuth2 + JWT refresh tokens" })

// 5. Ship (run after agents complete)
// /ship  -- in worker context
```

---

## Anti-Drift Checklist (apply to all patterns)

- [ ] `topology: "hierarchical"` — single coordinator enforces alignment
- [ ] `maxAgents: 8` or fewer — smaller team = less drift surface
- [ ] `strategy: "specialized"` — clear roles, no ambiguity
- [ ] `consensus: "raft"` — leader maintains authoritative state
- [ ] Checkpoints via `post-task` hooks
- [ ] Shared memory namespace for all agents
- [ ] Short task cycles with verification gates
- [ ] `[AGENT_BOOSTER_AVAILABLE]` checked before spawning agents