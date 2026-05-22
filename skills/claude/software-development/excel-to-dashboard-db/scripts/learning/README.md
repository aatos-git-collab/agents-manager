# Learning Scripts for excel-to-dashboard-db

This skill learns from every session to improve over time.

## Scripts

| Script | Purpose |
|--------|---------|
| `learn-from-session.sh` | Extract patterns from completed tasks |
| `recall-patterns.sh` | Recall relevant patterns before tasks |
| `learn-from-feedback.sh` | Learn from corrections |

## Usage

### After Completing a Task

```bash
./scripts/learning/learn-from-session.sh
```

This extracts:
- What worked
- What didn't work
- Excel patterns observed
- Dashboard output patterns
- User preferences

### Before Similar Task

```bash
./scripts/recall-patterns.sh "excel import"
```

This recalls:
- Previous successful approaches
- Common pitfalls
- User preferences

### After Feedback

```bash
./scripts/learning/learn-from-feedback.sh "too slow" "chunk the data"
```

This records:
- What went wrong
- How to fix it
- Applies to future tasks

## Pattern Storage

Patterns are stored in: `/memory/patterns/excel-dashboard/`

```
memory/
└── patterns/
    └── excel-dashboard/
        ├── session-20260214.txt
        ├── session-20260215.txt
        ├── feedback-20260214-143000.txt
        └── common-patterns.txt
```

## Learning Loop

```
TASK COMPLETE
     ↓
Run learn-from-session.sh
     ↓
Patterns extracted & stored
     ↓
NEXT SIMILAR TASK
     ↓
Run recall-patterns.sh
     ↓
Apply learned patterns
     ↓
If feedback → learn-from-feedback.sh
     ↓
Skill improves over time!
```

## Best Practices

1. **Run after every task** - Build pattern library
2. **Be specific** - Note exact what worked/didn't
3. **Recall before similar tasks** - Apply prior learning
4. **Learn from feedback immediately** - Don't repeat mistakes
