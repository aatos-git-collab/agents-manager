---
name: hermmes-workspace-orchestrator
description: hermmes-workspace-orchestrator skill
  Multi-agent orchestration for Hermes — coordinates AatosTeam (agent teams in tmux)
  and Claude Code (coding agents) from within Hermes. This is Hermes's native orchestration
  layer: it decides whether to spawn a full AatosTeam swarm or delegate to a single
  Claude Code instance based on task complexity.
triggers:
  - "build a team"
  - "create agents"
  - "orchestrate multi-agent"
  - "spawn workers"
  - "delegate to team"
  - "launch agent team"
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [orchestration, multi-agent, tmux, aatosteam, claude-code]
    related_skills: [aatosteam, claude-code, hermes-agent-spawning]
---

# Hermes Workspace Orchestrator

Hermes's native orchestration layer. Coordinates two modes of multi-agent work:
1. **AatosTeam** — full agent swarms with task boards, inbox messaging, and kanban
2. **Claude Code** — single focused coding agent for targeted tasks

Hermes (root) is always the orchestrator. Workers run in tmux windows, isolated per workspace.

## Architecture

```
HERMES (Root — Orchestrator)
    │
    ├──► AATOSTEAM (Swarm Mode)
    │        │      tmux session: aatosteam-<team>
    │        ├──► Agent: backend-dev     (window 1)
    │        ├──► Agent: frontend-dev   (window 2)
    │        └──► Agent: qa-dev         (window 3)
    │                └─── Task Board ─── Inbox Messaging
    │
    ├──► CLAUDE CODE (Single Agent Mode)
    │        └──► claude 'implement feature X'
    │
    └──► WORKSPACE (Isolated Execution)
             └──► /home/<workspace>/.hermes/skills → /root/.hermes/skills/global
```

## Decision Tree: Which Mode?

| Task Type | Use |
|-----------|-----|
| "build me a full SaaS", "create a team", "launch research" | AatosTeam swarm |
| "fix this bug", "add feature", "review PR" | Claude Code |
| "work on X in parallel with Y" | AatosTeam (multiple workers) |
| "setup CI/CD", "write tests" | Claude Code |
| Complex multi-step with coordination | AatosTeam + Claude Code |

## Swarm Mode: AatosTeam

### Quick Start

```bash
# Launch a software-dev team from template
aatosteam launch software-dev --goal "Build a REST API for task management" --team-name mybuild

# Launch a research team
aatosteam launch research-paper --goal "Survey on KV cache compression" --team-name research

# View the kanban board
aatosteam board show mybuild

# Watch all agents work in tmux tiles
aatosteam board attach mybuild
```

### Manual Team Setup

```bash
# 1. Spawn a team
aatosteam team spawn-team myteam -d "Build backend API" -n leader

# 2. Spawn worker agents
aatosteam spawn --team myteam --agent-name backend-dev --task "Implement auth endpoints" --skip-permissions
aatosteam spawn --team myteam --agent-name frontend-dev --task "Build login UI" --skip-permissions

# 3. Create tasks
aatosteam task create myteam "Implement user CRUD" -o backend-dev
aatosteam task create myteam "Build login form" -o frontend-dev

# 4. Monitor
aatosteam board live myteam --interval 3

# 5. Message a worker
aatosteam inbox send myteam backend-dev "Updated: use JWT RS256"

# 6. Shutdown
aatosteam lifecycle request-shutdown myteam
aatosteam team cleanup myteam
```

### Templates Available

| Template | Workers | Best For |
|----------|---------|----------|
| `software-dev` | leader, backend-dev, frontend-dev | Full-stack apps |
| `code-review` | leader, reviewer, security | PR audits |
| `research-paper` | leader, researcher, writer | Literature surveys |
| `hedge-fund` | leader, quant, analyst | Finance research |
| `strategy-room` | leader, strategist, analyst | Business planning |

## Single Agent Mode: Claude Code

```bash
# One-shot task
claude 'Fix the login bug in src/auth.py'

# With background + PTY for monitoring
terminal(command="claude 'Refactor the auth module'", workdir="~/project", background=true, pty=true)
```

## Workspace Isolation

Workers execute in isolated Linux user workspaces. Each workspace has:
- Its own `$HOME` and git repos
- Access to global skills via symlink: `~/.hermes/skills → /root/.hermes/skills/global`
- No sudo, no access to other workspaces
- All tools (hermes, claude, aatosteam) in PATH

## Orchestration Pattern (Hermes as Leader)

```
User → Hermes (Root)
    │
    ├► Phase 1: Planning
    │      Think through approach, decide: AatosTeam or Claude Code?
    │
    ├► Phase 2: Delegate
    │      If complex → aatosteam launch software-dev ...
    │      If targeted → claude 'fix bug X'
    │
    ├► Phase 3: Monitor
    │      aatosteam board show <team>
    │      process(action="log", session_id=<id>)
    │
    └► Phase 4: Synthesize
           Collect results, report to user
```

## Scripts

This skill has no separate scripts — it delegates entirely to:
- `aatosteam` CLI — team orchestration
- `claude` CLI — single agent coding
- `tmux` — process management and monitoring

All required tools are pre-installed globally by the `global-install` skill.

## Relationship to Other Skills

| Skill | Role |
|-------|------|
| `aatosteam` | Handles swarm orchestration, task boards, inbox |
| `claude-code` | Handles single coding agent tasks |
| `hermes-agent-spawning` | Spawns additional Hermes instances (different from AatosTeam) |
| `devops/workspace-manager` | Sets up isolated workspaces for agents |
| `devops/global-install` | Installs all tools globally |

## Key Principles

1. **Hermes is always the leader** — users talk to Hermes, Hermes coordinates workers
2. **AatosTeam for multi-agent coordination** — when you need parallel workers + task tracking
3. **Claude Code for targeted tasks** — single agent, focused work
4. **Workspaces are isolated** — workers can't access each other's files
5. **Hermes retains orchestration memory** — not workspace data
## Quick Commands
- `skill-load hermmes-workspace-orchestrator` — Load this skill
