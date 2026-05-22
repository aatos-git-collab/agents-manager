# Thinking Patterns for git-project-manager

## Git Project Management Agent

This skill manages git projects with structure awareness and agent brain backup.

## Learning Loop

```
OBSERVE → ANALYZE → MANAGE → BACKUP → IMPROVE
```

## Git Management Workflow

```
PROJECT REQUEST
     ↓
Analyze project structure
     ↓
Determine git operations
     ↓
Execute git commands
     ↓
Backup to brains repo
     ↓
Learn and improve
```

## Thinking Process

```
<thinking>
1. What type of git operation?
   - Clone repository
   - Create branch
   - Commit changes
   - Push to remote
   - Merge conflicts
   
2. What is the project structure?
   - Single repo
   - Monorepo
   - Multi-repo
   
3. Does this need agent brain backup?
   - New agent created
   - Major configuration change
   - Skill added/removed
</thinking>
```

## Common Git Operations

| Operation | Command | When |
|-----------|---------|------|
| Clone | git clone | New project |
| Branch | git checkout -b | New feature |
| Commit | git commit -m | Changes made |
| Push | git push | Commit ready |
| Pull | git pull | Sync updates |
| Status | git status | Check state |

## Delegation Chain

```
GIT TASK
     ↓
What operation?
     ↓
Simple → Execute directly
     ↓
Complex → Delegate to github skill
     ↓
Backup needed → Delegate to agent-backup-restore
     ↓
Report results
```

## Project Structure Analysis

```
<analysis>
1. What type of project?
   - Application (has main file)
   - Library (has package.json/requirements.txt)
   - Skill (has SKILL.md)
   - Documentation (has docs/)

2. What git operations are safe?
   - Safe: status, log, diff
   - Moderate: add, commit, branch
   - Risky: push, merge, reset

3. What needs backup?
   - Agent configs
   - Skill modifications
   - Project-specific scripts
</analysis>
```

## Self-Learning Commands

```bash
# Learn from git operation
./scripts/learning/learn-project-patterns.sh

# Recall patterns
./scripts/learning/recall-patterns.sh "git"

# Learn from feedback
./scripts/learning/learn-from-feedback.sh "merge conflict" "use rebase"
```

## Brains Backup Integration

```
When: New agent created or major change
Action: Push to git@github.com:aatosai/brains.git
Files:
  - agent-config.json
  - SKILL.md (if new skill)
  - Modified scripts
```

## Files Created

```
git-project-manager/
├── SKILL.md              # Main documentation
├── run.sh               # Entry point
├── thinking-patterns.md  # This file
├── agent-config.json
└── scripts/
    ├── git-manager.py
    ├── agent-brain-backup.py
    └── learning/
        └── learn-project-patterns.sh
```

## Self-Learning Enabled

- Tracks successful git operations
- Learns optimal commit messages
- Improves branch naming
- Adapts to project patterns

## Core Promise

> "Every project is properly versioned, every change is tracked, every agent is backed up."
