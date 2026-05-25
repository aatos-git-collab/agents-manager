---
name: aatosteam
description: aatosteam skill
  This skill should be used when the user asks to "create a team", "spawn agents",
  "assign tasks", "coordinate multiple agents", "check team status", "view kanban board",
  "send messages between agents", "manage team tasks", "monitor team progress",
  or mentions "aatosteam", legacy "oh", "multi-agent coordination", "team collaboration",
  "agent inbox", "task board", "spawn worker". This skill should also be triggered
  when the current task is complex enough to benefit from splitting into subtasks
  and delegating to multiple agents — for example when the user asks to "build a
  full-stack app", "refactor the entire codebase", "implement multiple features
  in parallel", or when the agent determines that the work scope exceeds what a
  single agent can efficiently handle alone. Provides comprehensive guidance for
  using the aatosteam CLI to orchestrate multi-agent teams with task management,
  messaging, monitoring, runtime profiles, git context, and recovery tooling.
version: 0.3.2
---

# aatosteam Multi-Agent Coordination

aatosteam is a framework-agnostic CLI tool for coordinating multiple AI agents as a team.
It provides team/task management, inter-agent messaging, git worktree isolation, provider-aware
runtime profiles, git context injection, snapshots, and terminal-based monitoring dashboards.

All operations are performed via the `aatosteam` CLI. Data is stored in `~/.aatosteam/` by default.

## Installation

Check whether `aatosteam` is already available:

```bash
aatosteam --version
```

If the command is missing, install it and continue:

```bash
pip install aatosteam
```

Requires Python 3.10+. For P2P transport support: `pip install "aatosteam[p2p]"`.

## Prerequisites

- `tmux` installed (default spawn backend)
- A CLI coding agent such as `claude`, `codex`, `gemini`, `kimi`, `nanobot`, or `openclaw`
- A git repository for worktree isolation and context features
- Default dependencies installed if you want the TUI wizard (`aatosteam profile wizard`)

## Core Concepts

**Teams** — Named groups of agents with one leader and zero or more workers.

**Inbox** — File-based message queue per agent. `receive` is destructive; `peek` is not.

**Tasks** — Shared task board with `pending`, `in_progress`, `completed`, and `blocked`.
Tasks support dependency chains and priorities.

**Profiles** — Reusable client/provider/runtime configs used by `spawn` and `launch`.

**Presets** — Shared provider templates used to generate one or more profiles.

**Context** — Git/worktree-aware context tools for overlap checks, recent changes, and prompt injection.

**Board** — Team dashboard with kanban tasks, inbox counts, and message history views, plus gource activity visualization.

## Quick Start

### Set Up a Team with Tasks

```bash
export aatosteam_AGENT_ID="leader-001"
export aatosteam_AGENT_NAME="leader"
export aatosteam_AGENT_TYPE="leader"

aatosteam team spawn-team my-team -d "Project team" -n leader
aatosteam task create my-team "Design system" -o leader
aatosteam task create my-team "Implement feature" -o worker1
aatosteam task create my-team "Write tests" -o worker2
aatosteam board show my-team
```

### Configure Runtime Profiles

```bash
# Inspect built-in provider templates
aatosteam preset list
aatosteam preset show moonshot-cn

# Generate a reusable profile from a preset
aatosteam preset generate-profile moonshot-cn claude --name claude-kimi

# Or use the interactive TUI
aatosteam profile wizard

# Claude Code on a fresh machine/home may need onboarding repair once
aatosteam profile doctor claude

# Smoke-test the profile before using it in a team
MOONSHOT_API_KEY=... aatosteam profile test claude-kimi
```

### Spawn and Coordinate Agents

```bash
# Default path: tmux backend, claude command, git worktree isolation, skip-permissions on
aatosteam spawn --team my-team --agent-name worker1 --task "Implement the auth module"
aatosteam spawn --team my-team --agent-name worker2 --task "Write unit tests"

# Explicit backend and command
aatosteam spawn tmux claude --team my-team --agent-name worker3 --task "Build API endpoints"
aatosteam spawn subprocess claude --team my-team --agent-name worker4 --task "Run linting"

# Recommended for non-default providers/models
aatosteam spawn tmux --profile claude-kimi --team my-team --agent-name worker5 --task "Build API endpoints"
aatosteam spawn subprocess --profile gemini-vertex --team my-team --agent-name worker6 --task "Run linting"

aatosteam board attach my-team
aatosteam inbox send my-team worker1 "Start implementing the auth module"
aatosteam board live my-team --interval 3
```

### Spawn Defaults

| Setting | Default | Override |
|---------|---------|----------|
| Backend | `tmux` | `aatosteam spawn subprocess ...` |
| Command | `claude` | `aatosteam spawn tmux my-cmd ...` |
| Workspace | `auto` (git worktree) | `--no-workspace` or config `workspace=never` |
| Permissions | skip | `--no-skip-permissions` or config `skip_permissions=false` |
| Runtime profile | none | `--profile <name>` |

Use `--profile` whenever you need a non-default provider, model, endpoint, or auth mapping.

### Task Lifecycle

```bash
# Create with dependencies
aatosteam task create my-team "Deploy" --blocked-by <impl-task-id>,<test-task-id>

# Create with priority
aatosteam task create my-team "Hotfix prod issue" --priority high

# Update status
aatosteam task update my-team <task-id> --status in_progress
aatosteam task update my-team <task-id> --status completed

# Filter tasks
aatosteam task list my-team --status blocked
aatosteam task list my-team --owner worker1
aatosteam task list my-team --priority high
```

### Waiting for Sub-Agents

```bash
aatosteam task wait my-team
aatosteam task wait my-team --timeout 300 --poll-interval 10
aatosteam task wait my-team --agent coordinator
aatosteam --json task wait my-team --timeout 600
```

### Worker Loop Protocol

Workers should not stop after completing the initial `--task`. The expected loop is:

```bash
# 1. Check tasks assigned to you
aatosteam task list my-team --owner worker1

# 2. Finish any pending work, then check for new instructions
aatosteam inbox receive my-team --agent worker1

# 3. If idle, notify the leader and keep monitoring for follow-ups
aatosteam lifecycle idle my-team
```

Repeat the loop until the leader explicitly shuts the worker down.

### Git Context and Conflict Checks

```bash
aatosteam context log my-team
aatosteam context conflicts my-team
aatosteam context inject my-team --agent worker1
```

Use these before reassigning work, continuing another worker's task, or merging overlapping changes.

### Snapshots and Recovery

```bash
aatosteam team snapshot my-team --tag before-refactor
aatosteam team snapshots my-team
aatosteam team restore my-team --snapshot before-refactor
```

### Activity Visualization

```bash
aatosteam board gource my-team --log-only
aatosteam board gource my-team --live
```

Prefer `--log-only` in headless environments.

## Supported CLI Agents

Common validated CLIs include:
- `claude`
- `codex`
- `gemini`
- `kimi`
- `nanobot`
- `openclaw`

OpenClaw worker spawns are normalized automatically. Bare `openclaw` commands are promoted to
the agent entrypoint and wired with `--local`, `--session-id`, and `--message` as needed.

Configure non-default providers through `profile` + `preset` instead of hardcoding env vars into prompts.

## Command Groups

| Group | Purpose | Key Commands |
|-------|---------|-------------|
| `preset` | Shared provider templates | `list`, `show`, `generate-profile`, `bootstrap` |
| `profile` | Reusable client/provider configs | `list`, `show`, `set`, `test`, `wizard`, `doctor` |
| `team` | Team lifecycle | `spawn-team`, `discover`, `status`, `request-join`, `approve-join`, `cleanup`, `snapshot`, `restore` |
| `inbox` | Messaging | `send`, `broadcast`, `receive`, `peek`, `watch` |
| `task` | Task management | `create`, `get`, `update`, `list`, `wait` |
| `board` | Monitoring and visualization | `show`, `overview`, `live`, `attach`, `serve`, `gource` |
| `context` | Git/worktree context | `diff`, `files`, `conflicts`, `log`, `inject` |
| `plan` | Plan approval | `submit`, `approve`, `reject` |
| `lifecycle` | Agent lifecycle | `request-shutdown`, `approve-shutdown`, `idle` |
| `spawn` | Process spawning | `spawn [backend] [command]` |
| `identity` | Identity management | `show`, `set` |

## JSON Output

All commands support `--json` for machine-readable output. Put the flag before the subcommand:

```bash
aatosteam --json team discover
aatosteam --json board show my-team
aatosteam --json task list my-team --status pending
```

## Anti-Patterns (learned by trial — DO NOT repeat)

### CRITICAL: Task string colons break in shell
**Problem:** YAML multiline strings with `key: value` pairs (like docker-compose or task descriptions) get parsed as shell commands because colons after newlines are interpreted as label statements.

**Broken pattern:**
```bash
# ✗ Task YAML leaks as shell commands — "image:" "ports:" "build:" become errors
aatosteam spawn tmux claude --team my-team --agent-name worker1 \
  --task "Create docker-compose.yml:
services:
  postgres:
    image: postgres:16-alpine
    ports:
      - '5432:5432'"
# ✗ shell: image:: command not found
# ✗ shell: ports:: command not found
```

**Fix:** Write the task content to a temp file, then pass it with `bash -c 'cat $(realpath /tmp/task.txt)'`. ALSO include forced action sequence in the task brief so agent acts IMMEDIATELY on join:

```bash
# ✓ Write task to file first
cat > /tmp/task.txt << 'TASKEOF'
After joining:
1. Run: aatosteam task list saas-build --owner <your-name>
2. IMMEDIATELY mark your task in_progress: aatosteam task update saas-build <task-id> --status in_progress
3. THEN do the actual work
4. When done: aatosteam task update saas-build <task-id> --status completed

[TASK CONTENT HERE — be specific about files, paths, constraints]
TASKEOF

# ✓ Pass file content safely to agent
aatosteam spawn tmux claude --team my-team --agent-name worker1 \
  --agent-type general-purpose \
  --task "$(cat /tmp/task.txt)" \
  --skip-permissions
```

**CTO enforcement rule:** If agent has not moved task to `in_progress` within 20 seconds of joining, the leader should:
1. `aatosteam task update <task-id> --status in_progress` (force claim)
2. `aatosteam inbox send <team> <agent> "Start now. Do not wait for further instructions."`

### CRITICAL: Missing --skip-permissions stalls agents
**Problem:** Without `--skip-permissions`, agents spawned in tmux stall waiting for interactive approval prompts that never get answered in a headless background process.

**Broken pattern:**
```bash
# ✗ No skip-permissions → agent hangs forever on approval prompt
aatosteam spawn tmux claude --team my-team --agent-name worker1 --task "Build API"
# → Agent waits for: "approve? [y/N]"
```

**Fix:** ALWAYS include `--skip-permissions`:
```bash
# ✓
aatosteam spawn tmux claude --team my-team --agent-name worker1 \
  --task "Build API" \
  --skip-permissions
```

### CRITICAL: tmux socket path is NOT default
**Problem:** `tmux list-sessions` fails with "no server running on /tmp/tmux-0/default" even when tmux processes are alive. aatosteam uses a custom socket path at `/tmp/tmux-0/aatosteam`.

**Broken pattern:**
```bash
# ✗ Wrong socket — always empty
tmux list-sessions
# → error connecting to /tmp/tmux-0/default (No such file or directory)
```

**Fix — use aatosteam board commands instead:**
```bash
# ✓ Use aatosteam board to monitor (works regardless of socket)
aatosteam board show my-team
aatosteam --json board show my-team

# ✓ Check tmux via correct socket
tmux -L aatosteam list-sessions

# ✓ List background processes spawned
process(action="list")

# ✓ Check specific tmux session via TMUX_TMPDIR
TMUX_TMPDIR=/tmp/tmux-0 tmux -L aatosteam list-sessions
```

### CRITICAL: Interrupting agents then doing work yourself
**Problem:** When an agent fails or hits an error, CTO should fix the briefing — never take over the work yourself. Taking over breaks the delegation chain and the agent never learns.

**Broken pattern:**
```
Agent fails → CTO does the work → CTO reports → User confused who did what
```

**Fix — diagnose and re-delegate:**
```bash
# 1. Check what error the agent hit
aatosteam board show my-team
aatosteam inbox peek my-team --agent <agent-name>

# 2. Fix the briefing (more context, exact paths, constraints)
# 3. Re-spawn with corrected task
aatosteam spawn tmux claude --team my-team --agent-name <same-or-new> \
  --task "Fixed task with correct paths and constraints" \
  --skip-permissions
```

## Operational Pitfalls (learned by trial)

### delegate_task limits
- **Max 3 concurrent tasks per call** — `max_concurrent_children=3` is hard-coded. Batch larger teams into groups of 3.
- **300s hard timeout per subagent** — subagents that run long tasks (copying codebases, installing deps, Docker builds) will timeout at 5 minutes. For tasks expected to exceed 5 min, use the **CLI spawn** approach instead (see below).

### CLI spawn (not delegate_task) for long-running work
Use `terminal(background=true)` with `aatosteam spawn` for tasks that exceed 5 minutes:
```bash
# Foreground spawn → always fails with "long-lived process" error
aatosteam spawn tmux claude --team my-team --agent-name worker1 --task "..."
# ✗ Error: foreground command appears to start a long-lived server/watch process

# Background spawn → correct
terminal(background=true, command='aatosteam spawn tmux claude --team my-team --agent-name worker1 --task "..." --skip-permissions')
```

Monitor with `process(action="list")` — NOT `tmux list-sessions`.

### Best pattern for 5+ agents
1. `aatosteam team spawn-team` (once)
2. `aatosteam task create` for each task (can batch in parallel)
3. Spawn in batches of 3 via `delegate_task`, respawning timed-out ones via `terminal(background=true, command='aatosteam spawn tmux claude --team ... --skip-permissions')`
4. Monitor via `aatosteam board show my-team`

### Always use background=true for spawn
Every `aatosteam spawn tmux` is a long-lived process — always use `background=true` in terminal() calls.

## Important Notes

- **Always use `background=true`** for spawns — `terminal(background=true, command='aatosteam spawn tmux claude ... --skip-permissions')`
- **Monitor with `process(action="list")`** — NOT `tmux list-sessions` (wrong socket path)
- **Use `aatosteam board show`** for team status — works regardless of tmux socket location
- **Write multi-line tasks to `/tmp/task.txt`** first, pass with `--task "$(cat /tmp/task.txt)"` — prevents colon-leak errors
- **Always include `--skip-permissions`** on spawns — prevents agent stalling on approval prompts
- **CTO delegates, never takes over** — if agent fails, fix the briefing, don't do the work yourself
- **Force task claim immediately** — if agent hasn't set task to `in_progress` within 20s of joining, force it: `aatosteam task update <task-id> --status in_progress` + inbox nudge. No idle agents.
- **Spawn brief must include action sequence** — every spawn brief must tell agent to claim task FIRST, then work, then mark complete. No "read and understand" steps — only act.

## Additional Resources

- **`references/cli-reference.md`** — Complete CLI reference with commands, options, and data models
- **`references/workflows.md`** — Multi-agent workflows: setup, spawn coordination, join protocol, plan approval, graceful shutdown, monitoring patterns
## Quick Commands
- `skill-load aatosteam` — Load this skill
