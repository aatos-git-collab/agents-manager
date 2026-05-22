---
name: ai-migrate-tools
description: LLM-powered code migration at scale. Use when migrating codebases (Java→Kotlin, Python→Rust, framework upgrades, etc.) at scale with example pairs, verification scripts, and git worktree support.
---



# AI Migrate Tools

LLM-powered code migration at scale. Installed globally as `ai-migrate`.
Installation and repair are handled by the **workspace-manager** skill (`verify_and_fix_all` + `repair_ai_migrate`).

## Quick Start

```bash
# Initialize a new migration project
ai-migrate init

# Migrate files (interactive)
ai-migrate migrate

# Check status
ai-migrate status
```

## Core Workflow

1. **Initialize project** with source/target language or framework
2. **Add example pairs** showing migration patterns (`.old` → `.new` files)
3. **Generate system prompt** from examples
4. **Create verification script** to validate migrations
5. **Run batch migration** with manifest or per-file

## Key Commands

| Command | Description |
|---------|-------------|
| `ai-migrate init [--pr=<num>] [--description=<desc>]` | Initialize new project (optionally from PR) |
| `ai-migrate migrate <files> [--manifest-file=<f>] [--max-workers=<n>]` | Migrate files |
| `ai-migrate status` | Show pass/fail/pending status |
| `ai-migrate checkout <file>` | Branch for manual fixes on failed migrations |
| `ai-migrate merge-branches` | Merge all successful migrations |
| `ai-migrate logs <run_id>` | Show logs for a run |
| `ai-migrate verify <file>` | Run verification on migrated file |
| `ai-migrate add-examples-from-pr <pr_num>` | Extract examples from PR |

## Project Structure

```
project/
├── system_prompt.md      # Migration instructions for LLM
├── examples/
│   ├── Example.old.py
│   └── Example.new.py
├── verification.sh       # Validation script
├── projects/             # Migration run tracking
└── evals/                # Auto-generated test cases
```

## Configuration

- `AI_MIGRATE_PROJECT_DIR` env var - set default project directory
- `.ai-migrate` file in repo - project-specific settings
- `--local-worktrees` flag - create git worktrees alongside repo

---

## Multi-Agent Orchestration (AatosTeam / Hermes)

When running large migrations, delegate to a team of agents for parallel work.

### Orchestration Prompt

Use this prompt as the basis for spawning a migration team:

```
You are the Migration Orchestrator. Your job is to coordinate a codebase migration.

CONTEXT:
- Source: {source_lang} → Target: {target_lang}
- Project: {project_path}
- Files to migrate: {file_count} files
- Examples: {example_pairs}

WORKFLOW:
1. Spawn {n} migration agents, each responsible for a slice of files
2. Each agent runs: ai-migrate migrate <their_files> --project-dir <project>
3. Collect results, identify failures
4. For failed files: ai-migrate checkout <file> and fix manually or re-delegate
5. Final: ai-migrate merge-branches to consolidate successful migrations

REPORT back with:
- Pass/fail/pending counts
- List of files needing manual review
- Any patterns in failures (syntax, API differences, etc.)
```

### Agent Delegation Pattern

```python
# Example: Spawn 3 parallel migration agents via AatosTeam
tasks = [
    {"goal": f"Migrate files {slice1} using ai-migrate", "context": project_context},
    {"goal": f"Migrate files {slice2} using ai-migrate", "context": project_context},
    {"goal": f"Migrate files {slice3} using ai-migrate", "context": project_context},
]
results = aatosteam.run_tasks(tasks)  # parallel
```

### Hermes Agent Planning

When Hermes receives a migration request, it should:
1. **Assess scope** — how many files, what languages, any existing examples?
2. **Plan the team** — decide how many agents based on file count (1 agent per ~50 files works well)
3. **Delegate** — spawn agents via `delegate_task` or AatosTeam, each with file slices
4. **Collect & review** — check `ai-migrate status` across the project
5. **Handle failures** — `ai-migrate checkout` on failed files, fix or re-delegate
6. **Merge** — `ai-migrate merge-branches` once all agents complete

### Scaling Guidance

| File Count | Agent Count | Strategy |
|-----------|-------------|----------|
| 1-20 | 1 | Single agent, sequential |
| 20-100 | 2-3 | Parallel slices, merge after |
| 100-500 | 3-5 | One agent per directory tree |
| 500+ | 5+ | Hierarchical — orchestrator + per-dir agents |

## Installation & Repair

Managed by **workspace-manager** skill. To install or fix:

```bash
# Self-heal (root)
sudo /root/.hermes/skills/devops/workspace-manager/scripts/_tool-utils.sh

# Or in a workspace:
source /root/.hermes/skills/devops/workspace-manager/scripts/_tool-utils.sh
check_ai_migrate   # 0=ok, 1=broken, 2=missing
repair_ai_migrate   # reinstalls via pipx
```

## Quick Commands
- `skill-load ai-migrate-tools` — Load this skill
