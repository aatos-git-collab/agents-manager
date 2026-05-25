# ClawTeam Spawn Presets

> When to use which preset and how to configure it.
> Part of `clawteam/` skill — see `SKILL.md` Part 1 for context.

## Preset Overview

| Preset | Behaviour | Exit trigger | Best for |
|--------|-----------|--------------|----------|
| `agent-loop` | Runs until task complete | Worker sends done signal | Long-running tasks, multi-step work |
| `single-task` | One task then exits | Task assigned, result returned | One-shot jobs, discrete deliverables |
| `inspect-loop` | Reads, analyzes, reports | No file writes, no edits | Code review, research, auditing |
| `interactive` | Asks leader for guidance | Leader response | Complex decisions, ambiguous tasks |

---

## agent-loop (Default for most work)

The worker keeps running until it signals completion. Ideal for features,
refactoring, QA runs, and any task that spans multiple steps.

```bash
clawteam spawn coder-1 \
  --adapter claude \
  --preset agent-loop \
  --team myteam \
  --context "Implement the auth module. Report to leader when done."

# With tmux backend (visible windows)
clawteam spawn coder-1 \
  --adapter claude \
  --preset agent-loop \
  --backend tmux \
  --team myteam
```

**Leader monitors via:**
```bash
clawteam board attach myteam        # Watch all workers tiled
clawteam team status myteam          # Show status
clawteam inbox check myteam worker-1  # Check messages
```

**Worker signals completion:**
```bash
clawteam lifecycle done <team> <worker>   # Normal completion
clawteam lifecycle idle <team> <worker>    # Idle, awaiting task
```

---

## single-task

Worker takes one task and exits immediately. Use for discrete, independent
jobs that don't need ongoing coordination.

```bash
clawteam spawn security-scan-1 \
  --adapter claude \
  --preset single-task \
  --team myteam \
  --context "Scan src/auth/ for SQL injection. Return findings as JSON."

# Result comes back via mailbox
clawteam inbox read myteam leader --all
```

**Good for:**
- Quick one-shot analyses
- Independent parallel tasks that don't need coordination
- Fire-and-forget operations
- Bulk operations (spawn multiple single-task workers for parallel work)

**Not for:**
- Multi-step workflows (use `agent-loop`)
- Tasks requiring mid-process clarification (use `interactive`)
- Ongoing monitoring (worker exits after first task)

---

## inspect-loop

Worker reads and analyzes but never writes or edits. Ideal for review-only
tasks where you want observations without changes.

```bash
clawteam spawn security-reviewer \
  --adapter claude \
  --preset inspect-loop \
  --team myteam \
  --context "
    Review src/auth/ for security issues.
    - SQL injection vectors
    - Hardcoded secrets or API keys
    - Insecure deserialization
    - Missing auth checks
    - XSS vulnerabilities
    Report findings to leader via inbox. Do NOT make any edits.
  "

clawteam spawn code-reviewer \
  --adapter claude \
  --preset inspect-loop \
  --team myteam \
  --context "Review PR #42. Check: logic errors, edge cases, performance issues, \
    readability. Send summary to leader. No file modifications."
```

**What it can do:**
- Read files
- Run read-only commands (grep, find, stat)
- Analyze code structure
- Send messages to leader
- Take screenshots via gstack

**What it cannot do:**
- Write/edit files
- Run destructive commands
- Create new files
- Commit changes

---

## interactive

Worker pauses for leader guidance on ambiguous decisions. Use for tasks
with non-obvious paths or where human/leader judgment is needed mid-process.

```bash
clawteam spawn planner \
  --adapter claude \
  --preset interactive \
  --team myteam \
  --context "
    Analyze the legacy codebase and propose a refactoring plan.
    When you encounter architectural decisions, ask the leader:
    - Which approach to prioritise (speed vs correctness vs maintainability)
    - Whether to break backward compatibility
    - Priority of which subsystems to migrate first
    Use SendMessage to ask. Wait for response before proceeding.
  "
```

**Leader interaction pattern:**
```bash
# Worker sends question
clawteam inbox check myteam planner

# Leader responds
clawteam inbox send myteam planner "Prioritise maintainability. Keep v1 API compatible."

# Worker continues with that guidance
```

**Anti-pattern — don't use `interactive` for:**
- Simple linear tasks (use `agent-loop`)
- Tasks requiring fast parallel execution (worker blocks)
- Well-defined tasks with clear success criteria

---

## Spawn Flags Reference

```bash
clawteam spawn <name> [flags]

  --adapter <claude|codex|subprocess>   # Agent adapter (default: claude)
  --preset <preset>                       # One of the four above (default: agent-loop)
  --team <team>                          # Team to join (required)
  --backend <tmux|subprocess>            # Backend (default: tmux)
  --model <haiku|sonnet|opus>           # Model override for claude adapter
  --context "<instructions>"             # Worker instructions (use quotes for multi-line)
  --bg                                   # Run in background, non-blocking leader
  --no-env                               # Don't inherit parent environment variables
```

---

## Preset × Backend Matrix

| Preset | tmux backend | subprocess backend |
|--------|-------------|---------------------|
| `agent-loop` | ✅ Windows persist, visible | ✅ Background, invisible |
| `single-task` | ✅ Window closes on exit | ✅ Process exits |
| `inspect-loop` | ✅ Read-only monitoring | ✅ Safe sandbox |
| `interactive` | ✅ Leader can attach to window | ✅ Leader can pipe input |