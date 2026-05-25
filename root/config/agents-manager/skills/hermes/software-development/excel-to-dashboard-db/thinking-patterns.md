# Thinking Patterns for excel-to-dashboard-db

## Self-Learning Agent

This skill improves over time by learning from every session.

## Learning Loop

```
OBSERVE → EXTRACT → STORE → RECALL → APPLY
```

### 1. Observe & Capture
- What Excel format was processed?
- What transformations were applied?
- What dashboard output was generated?
- User satisfaction level?

### 2. Extract Patterns
- Common column naming conventions
- Preferred aggregation methods
- Visualization styles that work
- Performance bottlenecks

### 3. Store & Index
- Save to `/memory/patterns/excel-dashboard/`
- Tag for retrieval
- Cross-reference existing patterns

### 4. Recall & Apply
- Before similar tasks, recall patterns
- Apply learned preferences
- Avoid previous mistakes

## Learning Commands

### After Task Completion

```bash
./scripts/learning/learn-from-session.sh
```

### Before Similar Task

```bash
./scripts/recall-patterns.sh "sales data"
```

### After Feedback

```bash
./scripts/learning/learn-from-feedback.sh "too slow" "use chunking"
```

## Delegation Philosophy

**Never do the work yourself. Delegate to specialist skills.**

This agent specializes in Excel→Dashboard conversions, but delegates to other specialists:

### Delegation Chain

```
EXCEL INPUT
     ↓
1. Identify transformation needed
     ↓
2. Use appropriate script:
     - excel-to-db.py for storage
     - db-to-dashboard.py for export
     ↓
3. If visualization needed → Delegate to visualization skill
4. If reporting needed → Delegate to report skill
     ↓
5. Return results
```

## Thinking Process

Before processing:

```
<thinking>
1. What format is the input? (Excel, CSV, existing DB)
2. What output is needed? (Dashboard data, visualization, report)
3. Which script handles this?
   - excel-to-db.py for storage
   - db-to-dashboard.py for export
4. Do I need to delegate?
   - Charts/graphs → visualization skill
   - PDF reports → report skill
5. Execute and return results
6. Learn from this task for future improvements
</thinking>
```

## Common Tasks & Approaches

| Task | Script | Delegate To |
|------|--------|-------------|
| Import Excel | excel-to-db.py | - |
| Export dashboard JSON | db-to-dashboard.py | - |
| Create charts | - | visualization skill |
| Generate PDF report | - | report skill |
| API integration | - | api skill |

## Performance Optimization

Learn from experience:

- Large files → Use chunking
- Complex formulas → Pre-compute in DB
- Real-time → Use lightweight queries
- Historical → Use aggregations

## Quality Metrics

Track for learning:

- Import speed
- Query performance
- User satisfaction
- Common errors

## Handoff Protocol

**Receive:** Excel/CSV file path or database connection info  
**Send:** Dashboard-ready JSON/HTML, database populated, learned patterns stored

---

*This skill learns from every interaction to become better over time.*
