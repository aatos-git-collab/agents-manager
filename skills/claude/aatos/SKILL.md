---
name: aatos
description: aatos skill
  Aatos is the AI operating system — multi-agent orchestration platform combining
  aatosteam (team coordination), hermes-agent (the agent brain), and aatos-skills
  (domain specialist skills). Use this overview when the user asks about the overall
  system, architecture, how pieces fit together, or which skill to load for a given task.
  Load the relevant sub-skill directly (aatosteam, aatos-skills) for specific workflows.
tags: [aatos, multi-agent, orchestration, overview, architecture]
---

# Aatos Operating System

**Purpose:** Autonomous multi-agent orchestration — build, coordinate, and manage teams of AI agents.

## System Architecture

```
aatos
├── aatosteam          ← team coordination CLI + multi-agent orchestration
├── hermes-agent       ← agent brain (spawned by aatosteam)
├── aatos-skills/      ← domain specialist skills for agents
└── hermes-browser/   ← stealth browser tool (anti-detect)
```

## Skills

| Skill | When to Load | What It Does |
|-------|-------------|--------------|
| `aatosteam` | User asks to spawn agents, manage teams, coordinate tasks, board, inbox | Multi-agent CLI, team lifecycle, task management |
| `aatos-skills` | Domain tasks — marketing, coding, research, sales, etc. | Pre-built specialist skill library |

## aatosteam Skill

**Location:** `~/.hermes/tools/AatosTeam/skills/autonomous-ai-agents/aatosteam/SKILL.md`
**Synced from:** tool → skill via `sync_to_skills.py` after each watchdog run

**Trigger phrases:**
- "spawn agents", "create a team", "assign tasks"
- "coordinate multiple agents", "check team status"
- "view kanban board", "send message between agents"
- "manage team tasks", "monitor team progress"
- "aatosteam", "multi-agent coordination", "agent inbox", "task board"

## Self-Healing (Bidirectional Sync)

Two systems keep tool and skills in sync:

### Watchdog: Tool → Skill (every 6h cron)
```
Upstream (HKUDS/ClawTeam)
  → pull → rebrand (clawteam→aatosteam)
  → push → origin (aatos-git-collab/AatosTeam)
  → sync_to_skills.py → agent defs + refs + SKILL.md
  → hermes skills folder (~/.hermes/skills/aatosteam/)
```

### aatosteam Skill: Skill → Tool (before every use)
```
aatosteam skill loaded
  → sync_to_skills.py --repo AatosTeam --check
  → verifies: git clean, deps installed, profiles valid
  → if broken: sync_to_skills.py --repo AatosTeam --fix
  → auto-repairs: git reset, pip install, profile doctor
```

**Manual commands:**
```bash
# Check health before using aatosteam
python ~/.hermes/skills/rebranding-tools/scripts/sync_to_skills.py --repo AatosTeam --check

# Self-heal + repair
python ~/.hermes/skills/rebranding-tools/scripts/sync_to_skills.py --repo AatosTeam --fix

# Force tool → skill sync
python ~/.hermes/skills/rebranding-tools/scripts/sync_to_skills.py --repo AatosTeam
```

## Quick Reference

**Spawn a team:**
```bash
aatosteam team spawn-team my-team -d "Project" -n leader
aatosteam spawn --team my-team --agent-name worker1 --task "..."
aatosteam board attach my-team
```

**Check agent status:**
```bash
aatosteam --json board show my-team
aatosteam --json task list my-team --status pending
```

**Tool locations:**
- CLI binary: `aatosteam` (pip installed)
- Tool source: `~/.hermes/tools/AatosTeam/`
- Agent defs: `~/.hermes/skills/aatosteam/agents/`
- CLI reference: `~/.hermes/skills/aatosteam/references/cli-reference.md`

## Quick Commands
- `skill-load aatos` — Load this skill
