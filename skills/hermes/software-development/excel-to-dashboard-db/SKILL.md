---
name: excel-to-dashboard-db
description: "Converts Excel data to dashboard visualizations with database storage - learns from every session"
metadata: {}
---
# 📊 Excel to Dashboard DB

Converts Excel files to database-backed dashboards with **self-learning**.

## What This Skill Does

1. **Excel to Database** - Import Excel/CSV into SQLite
2. **Database to Dashboard** - Export dashboard-ready JSON
3. **Statistics** - Generate summary data for visualizations
4. **Self-Learning** - Improves from every session

## 🎯 Self-Learning

This skill **learns from every task** to become better:

### Learning Loop

```
TASK COMPLETE
     ↓
learn-from-session.sh (extract patterns)
     ↓
Patterns stored in /memory/patterns/
     ↓
NEXT SIMILAR TASK
     ↓
recall-patterns.sh (recall what worked)
     ↓
Apply learned patterns
     ↓
Better results over time!
```

### Learning Commands

| Command | Purpose |
|---------|---------|
| `./scripts/learning/learn-from-session.sh` | Extract patterns from task |
| `./scripts/learning/recall-patterns.sh "query"` | Recall relevant patterns |
| `./scripts/learning/learn-from-feedback.sh "issue" "fix"` | Learn from correction |

## Quick Start

```bash
# Import Excel to database
./scripts/excel-to-db.py data.xlsx --db data/dashboard.db --table sales

# Export dashboard data
./scripts/db-to-dashboard.py --db data/dashboard.db --summary

# After task - learn from it
./scripts/learning/learn-from-session.sh

# Before similar task - recall patterns
./scripts/learning/recall-patterns.sh "sales data"
```

## Scripts

| Script | Purpose |
|--------|---------|
| `excel-to-db.py` | Import Excel/CSV to SQLite |
| `db-to-dashboard.py` | Generate dashboard data |

## Usage Examples

### Import Excel

```bash
./scripts/excel-to-db.py monthly-report.xlsx --table monthly --db reports.db
```

### Generate Summary

```bash
./scripts/db-to-dashboard.py --db reports.db --summary
```

### Export Dashboard JSON

```bash
./scripts/db-to-dashboard.py --db reports.db --export dashboard.json
```

## Learning Workflow

### 1. Complete Task
```bash
./scripts/excel-to-db.py data.xlsx --db mydb.db --table sales
./scripts/db-to-dashboard.py --db mydb.db --export dashboard.json
```

### 2. Learn from Session
```bash
./scripts/learning/learn-from-session.sh
```
Extracts patterns from what worked.

### 3. Before Similar Task
```bash
./scripts/learning/recall-patterns.sh "sales"
```
Recalls what worked before.

### 4. Apply Feedback
```bash
./scripts/learning/learn-from-feedback.sh "too slow" "use chunking"
```
Records correction for future tasks.

## Delegation

This skill delegates visualization tasks:

- **Charts** → visualization skill
- **PDF Reports** → report skill
- **API Integration** → api skill

## Files

```
excel-to-dashboard-db/
├── SKILL.md
├── run.sh
├── thinking-patterns.md           # Delegation + learning
├── agent-config.json             # selfLearning: true
└── scripts/
    ├── excel-to-db.py
    ├── db-to-dashboard.py
    └── learning/
        ├── learn-from-session.sh
        ├── recall-patterns.sh
        ├── learn-from-feedback.sh
        └── README.md
```

## Requirements

- Python 3
- pandas

## 🎓 Self-Learning

This skill gets smarter over time:

- ✅ Learns from every session
- ✅ Recalls what worked before
- ✅ Applies user feedback
- ✅ Improves performance
- ✅ Builds pattern library

---

*📊 Smart data conversion that learns from every interaction.*
