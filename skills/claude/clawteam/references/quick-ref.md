# ClawTeam CLI Quick Reference

> Single-page command card. Full reference in `SKILL.md` Part 5.

## Team
```bash
clawteam team spawn-team <name>    # Create team
clawteam team list                  # List all teams
clawteam team attach <team>        # Attach → tiled tmux view
clawteam team status <team>        # Show team + worker status
clawteam team destroy <team>       # Destroy team
```

## Spawn
```bash
clawteam spawn <name> [flags]
  --adapter claude|codex|subprocess
  --preset agent-loop|single-task|inspect-loop|interactive
  --team <team>
  --backend tmux|subprocess
  --model haiku|sonnet|opus
  --context "<instructions>"
  --bg
```

## Task
```bash
clawteam task create <team> <task-id> "<desc>" --assign <worker>
clawteam task list <team>
clawteam task start <team> <task-id>
clawteam task done <team> <task-id>
```

## Mailbox
```bash
clawteam inbox send <team> <worker> "<msg>"
clawteam inbox check <team> <worker>
clawteam inbox read <team> <worker> --all
clawteam inbox broadcast <team> "<msg>"
```

## Lifecycle
```bash
clawteam lifecycle idle <team> <worker>
clawteam lifecycle done <team> <worker>
clawteam lifecycle heartbeat <team> <worker>
```

## Board (tmux)
```bash
clawteam board attach <team>
clawteam board kill <team> <worker>
clawteam board layout <team> tiled|stack
```

## gstack (in workers)
```bash
$B goto <url>                  # Navigate
$B snapshot -i                 # Interactive elements
$B click <ref>                  # Click
$B fill <ref> "<text>"          # Type
$B screenshot [path]            # Screenshot
$B assert-text <sel> "<text>"  # Assert
$B console                      # JS console
```

## ruflo (in workers)
```bash
npx ruflo@latest mcp start
npx ruflo@latest swarm init --topology hierarchical --max-agents 8
npx claude-flow@v3alpha agent spawn -t coder --name <name>
npx claude-flow@v3alpha memory store --namespace <ns> --key <k> --value <v>
npx claude-flow@v3alpha memory search --namespace <ns> --query <q>
npx ruflo@latest hive-mind spawn "<objective>"
npx ruflo@latest hooks intelligence --status
```

## Decision Guide
| Need | Action |
|------|--------|
| Spawn 1–5 workers | `clawteam spawn` |
| Complex pipeline | ruflo swarm protocol |
| Browser QA | gstack `$B` + `/qa` |
| Code review | gstack `/review` |
| Ship ready | gstack `/ship` |
| Self-learning agents | ruflo SONA/EWC++ |
| Vector memory | ruflo `memory_search` |
| Enterprise orchestration | Full stack |