---
name: prioritizer
description: Skill: PRIORITIZER (Decision Engine)
---

# Skill: PRIORITIZER (Decision Engine)
## Slot: 210 | Purpose: Stop Analysis Paralysis

---

## 🎯 PURPOSE

Help Novem (and others) make decisions when overwhelmed with too many ideas. Act as an external brain that:

1. **Captures** every idea without judgment
2. **Organizes** by category and impact
3. **Prioritizes** using a framework
4. **Executes** one thing at a time

---

## THE PROBLEM IT SOLVES

```
Too many ideas → Can't decide → Do nothing → Stress → More ideas
                           ↑__________________________|
```

**This skill breaks the loop.**

---

## FRAMEWORK: ICE + FOCUS

### ICE Score (Impact, Confidence, Ease)
```
For each idea:
- Impact: How much $ or value? (1-10)
- Confidence: How sure are we? (1-10)
- Ease: How hard to build? (1-10)

ICE = Impact + Confidence + (10 - Ease)
Higher = Prioritize first
```

### FOCUS Framework
```
F - Find all ideas (no judgment)
O - Organize by category
C - Calculate ICE scores
U - Uncover hidden blockers
S - Select top 3
```

---

## USAGE

```
User: "I have too many ideas, I'm spiraling"

PRIORITIZER:
1. "List them all, one per line"
2. I'll categorize them
3. Score each using ICE
4. Present top 3 with reasoning
5. "Pick one. I'll help you start."

User picks #2
PRIORITIZER: "Let's break #2 into 3 steps. Step 1 is..."
```

---

## CONVERSATION PATTERN

```
User: "I want to do A, B, C, D, E, F, G..."

PRIORITIZER:
1. ✅ Captured all 7 ideas
2. Categorized:
   - Revenue: A, C, E
   - Infrastructure: B, D
   - Learning: F, G
3. Scored:
   A (Revenue): ICE=25
   C (Revenue): ICE=22
   E (Revenue): ICE=18
   B (Infra): ICE=15
   ...
4. Top 3 recommendations:
   1. A - Highest revenue potential
   2. C - Quick win
   3. E - Foundation for others
5. "Which resonates most?"
```

---

## DAILY RITUAL

```
Every morning:

1. "What ideas came in yesterday?" → Capture
2. "What's the top priority today?" → Focus
3. "What can wait?" → Defer
4. "One step forward" → Execute
```

---

## OUTPUTS

### Idea Bank
```
/ideas/
├── revenue/
├── infrastructure/
├── learning/
├── personal/
└── archived/
```

### Priority Queue
```
/current-focus/
├── active-project.md (top 1)
├── next-up.md (top 2)
└── backlog.md (rest)
```

---

## STATUS: Ready to build | Slot: 210
## Quick Commands
- `skill-load prioritizer` — Load this skill
