---
name: hermes-agent-observatory
description: hermes-agent-observatory skill
  DESIGN DOC / ASPIRATIONAL — Not yet implemented.
  Hermes reads agent inboxes, learns patterns, and
  auto-improves skills based on agent performance.
status: aspirational
warning: This skill describes a future self-improvement system. No implementation exists yet.
triggers:
  - "monitor agents"
  - "learn from agents"
  - "improve orchestration"
  - "agent performance"
  - "observatory"
triggers:
  - "monitor agents"
  - "learn from agents"
  - "improve orchestration"
  - "agent performance"
  - "observatory"
---

# Hermes Agent Observatory

Self-improvement loop: Hermes monitors agent inboxes, learns patterns, and auto-generates/updates skills.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    HERMES OBSERVATORY                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Inbox       │  │  Pattern     │  │  Skill       │       │
│  │  Monitor     │──│  Analyzer    │──│  Generator   │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                 │                 │               │
│         ▼                 ▼                 ▼               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Agent        │  │ Success/     │  │ Auto-create  │       │
│  │ Inbox        │  │ Failure      │  │ or patch     │       │
│  └──────────────┘  │ Patterns     │  │ skills       │       │
│         │          └──────────────┘  └──────────────┘       │
│         │                 │                 │               │
│         ▼                 ▼                 ▼               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              SKILL LIBRARY (Improved)                │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────┐
│              BETTER ORCHESTRATION                            │
│  Claude Code + AatosTeam                                       │
└──────────────────────────────────────────────────────────────┘
```

## Inbox Structure

Each agent exposes an inbox directory:

```
~/.hermes/agent-inboxes/
├── hermes/
│   ├── inbox/           # Pending messages
│   ├── outbox/          # Sent responses
│   ├── logs/            # Execution logs
│   └── metrics/         # Performance data
└── claude-code/
    ├── inbox/
    ├── outbox/
    ├── logs/
    └── metrics/
```

## Observable Metrics

| Metric | What it tells us |
|--------|------------------|
| `task_success_rate` | Which skill patterns work |
| `avg_completion_time` | Efficiency benchmarks |
| `error_types` | Common failure modes |
| `retry_count` | Fragile steps needing hardening |
| `command_patterns` | Most useful commands |
| `context_window_usage` | Optimization opportunities |

## Learning Pipeline

### 1. Inbox Monitor (Continuous)

```python
# Pseudocode for monitoring loop
def monitor_agents():
    while running:
        for agent in ['hermes', 'claude-code']:
            inbox_path = f"~/.hermes/agent-inboxes/{agent}/inbox"
            for message in read_new_messages(inbox_path):
                analyze_and_store(message)
        sleep(30)  # Poll every 30s
```

### 2. Pattern Analyzer (Batch, runs hourly)

```python
def analyze_patterns():
    # Cluster successful tasks → extract common patterns
    # Cluster failed tasks → identify failure signatures
    # Compare timing → find bottlenecks
    # Cross-reference → which skills help vs hurt
    
    patterns = {
        "success_patterns": [...],
        "failure_signatures": [...],
        "bottlenecks": [...],
        "suggested_skill_improvements": [...]
    }
    return patterns
```

### 3. Skill Generator (Triggered on significant findings)

```python
def generate_skills(patterns):
    for suggestion in patterns.suggested_skill_improvements:
        if suggestion.confidence > 0.8:
            if suggestion.type == "new_skill":
                create_skill(suggestion)
            elif suggestion.type == "patch":
                patch_skill(suggestion)
            elif suggestion.type == "remove":
                mark_skill_deprecated(suggestion)
```

## What Hermes Learns

### Success Patterns
- "When the agent uses strategist+architect+analyst, plans are 40% more complete"
- "Tasks with explicit rollback plans succeed 3x more often"
- "Breaking tasks into <10 step chunks reduces failure by 60%"

### Failure Signatures  
- "Commands with `--force` flag fail 80% of the time in workspace"
- "Plans without test checks cause 90% of post-deploy bugs"
- "Dependencies not checked upfront cause cascade failures"

### Improvement Triggers

| Trigger | Action |
|---------|--------|
| Same error 5+ times | Auto-patch skill with warning |
| New success pattern 10+ occurrences | Create skill variant |
| Metric degradation | Alert + suggest fix |
| Skill unused >30 days | Deprecate or merge |

## Implementation

```bash
# Start observatory (background daemon)
hermes-observatory start

# Check status
hermes-observatory status

# View learned patterns
hermes-observatory patterns

# Force a learning cycle
hermes-observatory analyze --now

# Disable auto-improvement
hermes-observatory pause
```

## Configuration

```yaml
observatory:
  enabled: true
  poll_interval: 30  # seconds
  analyze_interval: 3600  # hourly
  confidence_threshold: 0.8
  auto_patch: true
  auto_create: false  # manual approval for new skills
  log_retention: 7d
```

## Safety

- Auto-patching is conservative (never removes core logic)
- New skill creation requires manual approval by default
- All changes logged for rollback
- Observatory never reads workspace data (only agent metadata)
## Quick Commands
- `skill-load hermes-agent-observatory` — Load this skill
