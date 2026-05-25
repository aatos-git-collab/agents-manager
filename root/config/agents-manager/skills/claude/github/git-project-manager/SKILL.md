---
name: git-project-manager
description: "Manages git projects with structure awareness and agent brain backups to brains repository"
metadata: {}
---
# 🧠 Git Project Manager

Manages git projects with structure awareness and backs up agent brains to git repository.

## What This Skill Does

1. **Analyze Projects** - Detect structure, language, and health
2. **Manage Git** - Branches, commits, remotes
3. **Backup Brains** - Agent memories, skills, configurations
4. **Self-Learning** - Improves from every project interaction

## Quick Start

```bash
# Analyze current project
./run.sh analyze

# Generate project profile
./run.sh profile

# Backup all agents to brains repo
./run.sh backup

# Push brains to repository
./run.sh backup --push
```

## Scripts

| Script | Purpose |
|---------|---------|
| `git-manager.py` | Project structure analysis |
| `agent-brain-backup.py` | Agent brain backup |

## Commands

```bash
# Project Analysis
./run.sh analyze                    # Analyze current project
./run.sh profile                   # Generate project profile

# Brain Backup
./run.sh backup                    # Backup agents
./run.sh backup --push           # Backup and push to brains repo

# Learning
./run.sh learn                   # Learn from session
./run.sh recall "git"           # Recall patterns
./run.sh feedback "slow" "fix"  # Learn from feedback
```

## Brain Backup Workflow

```
1. ./run.sh backup
   → Creates backup in /tmp/brains-backup/

2. ./run.sh backup --push
   → Pushes to git@github.com:aatosai/brains.git

3. ./run.sh learn
   → Stores patterns in /memory/patterns/projects/
```

## Delegation

This skill delegates visualization and deployment:

- **Charts/Graphs** → visualization skill
- **Documentation** → docs skill
- **Deployment** → controller skill

## Files

```
git-project-manager/
├── SKILL.md
├── run.sh
├── thinking-patterns.md
├── agent-config.json
└── scripts/
    ├── git-manager.py
    ├── agent-brain-backup.py
    └── learning/
        ├── learn-project-patterns.sh
        ├── recall-patterns.sh
        └── learn-from-feedback.sh
```

## Self-Learning

This skill learns from every project interaction:

- ✅ Tracks project structures
- ✅ Learns git workflows
- ✅ Improves backup strategies
- ✅ Adapts to team patterns

---

*🧠 Smart project management with agent brain backup.*
