---
name: onboard
description: Onboard a new project with enterprise standards - creates CLAUDE.md, ARCHITECTURE.md, memory, tasks, and verifies all agents/commands are ready
trigger: /onboard or when project needs onboarding
---

# /onboard Command

Run this command to fully setup a project with enterprise standards. This command does EVERYTHING automatically.

## Usage

```
/onboard
```

## What It Does (Automatic)

1. **Check project status** - Is it already onboarded?
2. **Gather project info** - Auto-detect or ask
3. **Create CLAUDE.md** - With 6 mandatory points
4. **Create ARCHITECTURE.md** - System documentation
5. **Create .lessons/** - Session learnings
6. **Create tasks/** - Task tracking
7. **Create memory/** - Memory bank files
8. **Verify setup** - All commands and agents ready

---

## Docker-First Protocol

**IMPORTANT: All testing MUST be in Docker!**

- ❌ NEVER run tests locally (`npm test`, `npm run build`)
- ✅ ALWAYS run in Docker (`/docker-test`)
- ✅ ALWAYS cleanup after (`/docker-cleanup`)

This prevents local state from contaminating the codebase.

---

## Automatic Workflow

### Phase 1: Check Current Status

```bash
# Check if already onboarded
ls -la CLAUDE.md 2>/dev/null && echo "ALREADY_ONBOARDED" || echo "NEEDS_SETUP"
ls -la ARCHITECTURE.md 2>/dev/null || echo "NEEDS_ARCH"
ls -la tasks/ 2>/dev/null || echo "NEEDS_TASKS"
ls -la .claude/memory/ 2>/dev/null || echo "NEEDS_MEMORY"
```

### Phase 2: Auto-Detect Project Info

Try to auto-detect:
```bash
# Detect project name
cat package.json 2>/dev/null | jq -r '.name' || echo "unknown"

# Detect tech stack
ls package.json 2>/dev/null && echo "Node.js"
ls requirements.txt 2>/dev/null && echo "Python"
ls go.mod 2>/dev/null && echo "Go"
ls pom.xml 2>/dev/null && echo "Java"

# Detect framework
ls next.config.* 2>/dev/null && echo "Next.js"
ls vite.config.* 2>/dev/null && echo "Vite"
ls remix.config.* 2>/dev/null && echo "Remix"
```

### Phase 3: Create Required Files

#### CLAUDE.md
Create with:
- 6 mandatory points
- Task management
- Core principles
- Project info
- Available commands
- Memory file locations

#### ARCHITECTURE.md
Create with:
- Project overview
- Tech stack
- Directory structure
- API routes
- Key components

#### tasks/todo.md
Create template:
```markdown
# Task List

## Current Tasks

- [ ] Task 1
- [ ] Task 2

## Completed

### [Date]
- Completed task summary

## Review

### What worked
-

### What didn't
-

### Next steps
-
```

#### tasks/lessons.md
Create template:
```markdown
# Lessons Learned

## Correction Patterns

### [Date]: [Pattern Name]
- **Issue:** [What went wrong]
- **Root Cause:** [Why it happened]
- **Prevention Rule:** [How to avoid]

## Project-Specific Rules
- [Add rules]

## Workflow Improvements
- [Notes]
```

#### .lessons/session-learnings.md
Create template:
```markdown
# Session Learnings

*Add session learnings here.*

## Current Session

### Tasks Completed
-

### Issues Resolved
-

### New Knowledge
-

### Pending Work
-
```

### Phase 4: Setup Hooks (Optional)

If you want auto-loading of memory on session start, create hooks:

```bash
mkdir -p .claude/hooks
cat > .claude/hooks/session-start.sh << 'EOF'
#!/bin/bash
# Auto-load memory on session start
cat .claude/memory/projectContext.md 2>/dev/null
cat .claude/memory/activeContext.md 2>/dev/null
cat tasks/todo.md 2>/dev/null
EOF
chmod +x .claude/hooks/session-start.sh
```

Note: Hooks are optional. We use `/session-start` manually instead.

### Phase 5: Verify Setup

Check all commands exist:
```bash
ls .claude/commands/boris.md
ls .claude/commands/session-start.md
ls .claude/commands/session-end.md
ls .claude/commands/production-ready.md
ls .claude/commands/frontend-test.md
ls .claude/commands/docs-gen.md
ls .claude/commands/think.md
ls .claude/commands/remember.md
ls .claude/commands/docker-test.md
ls .claude/commands/docker-cleanup.md
```

Check all agents exist:
```bash
ls .claude/agents/boris.md
ls .claude/agents/code-architect.md
ls .claude/agents/verify-app.md
ls .claude/agents/test-writer.md
ls .claude/agents/security-auditor.md
```

### Phase 6: Report Status

---

## Example Output

```
╔══════════════════════════════════════════════════════════╗
║              ONBOARDING COMPLETE                         ║
╚══════════════════════════════════════════════════════════╝

Project: my-awesome-app
Type: Web Application
Tech: React, Node.js, Vite

Files Created:
✓ CLAUDE.md - Project instructions with 6 points
✓ ARCHITECTURE.md - System documentation
✓ tasks/todo.md - Task tracking
✓ tasks/lessons.md - Self-improvement log
✓ .lessons/session-learnings.md - Session learnings

Commands Ready:
✓ /boris - Master orchestrator
✓ /session-start - Load memory
✓ /session-end - Save memory
✓ /production-ready - Production check
✓ /frontend-test - Frontend testing
✓ /docs-gen - Documentation generator
✓ /think - Structured thinking
✓ /remember - Save to memory
✓ /docker-test - Test in Docker
✓ /docker-cleanup - Clean up Docker

Professional Patterns Included:
✓ Tool usage (Cursor)
✓ Think protocol (Devin AI)
✓ Memory protocol (Windsurf)
✓ Concise output (Anthropic)

Agents Ready:
✓ boris - Master orchestrator
✓ code-architect - Architecture
✓ verify-app - Verification
✓ test-writer - Tests
✓ security-auditor - Security

═══════════════════════════════════════════════════════════

QUICK START:
  /boris [task]        - Run any task
  /session-start       - Start session
  /session-end         - End session
  /production-ready   - Check production

READY TO WORK! 🚀
```

---

## Usage for New Project

```bash
# Just run this ONE command:
/onboard

# Done! Now use:
/boris Fix the login bug
/boris Add new feature
/boris Run tests
```

## Notes

- **ONE command does everything**
- Auto-detects project info
- Creates all needed files
- Verifies all commands/agents ready
- Just run `/onboard` and start working!

---

*This command replaces both /onboard and /create-team*
