---
name: ai-migrate-tools
description: LLM-powered code migration at scale. Use when migrating codebases (Java→Kotlin, Python→Rust, framework upgrades, etc.) at scale with example pairs, verification scripts, and git worktree support.
category: software-development
---

# AI Migrate Tools

LLM-powered code migration at scale. Installed globally as `ai-migrate`.

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

## Installation Note

Requires Python 3.12+. If you see "externally managed environment" errors, use:
```bash
pipx install /path/to/ai_migrate_tools-0.1.3/
```
## Quick Commands
- `skill-load ai-migrate-tools` — Load this skill
