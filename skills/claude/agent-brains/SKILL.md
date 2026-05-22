---
name: agent-brains
description: Specialized agents for different business domains — CEO, CTO, CMO, COO, CFO, CSO playbooks. Use when making strategic, operational, or domain-specific decisions.
---

# Agent Brains

**Category:** agent-brains

## Overview

Agent brain skills — the core AI personas that think and decide. Each has its own identity, operating philosophy, decision frameworks, and response formats. Load one to activate that mindset.

## Sub-Skills

### C-Suite (Strategic Decision Makers)

| Skill | Role | Slot |
|-------|------|------|
| `ceo` | Chief Executive — vision, bets, capital allocation | 100 |
| `cto` | Chief Technology — architecture, engineering, AI | 102 |
| `cmo` | Chief Marketing — growth, brand, demand gen | 101 |
| `coo` | Chief Operating — ops, execution, scale | 103 |
| `cfo` | Chief Financial — unit economics, capital | 104 |
| `cso` | Chief Strategy — competitive, M&A, positioning | 105 |

### Sales (Revenue & Deals)

| Skill | Role | Best For |
|-------|------|---------|
| `jordan-belfort` | Straight Line Selling | High-urgency, complex deals |
| `grant-cardone` | 10x Sales | Big deals, revenue targets |
| `zig-ziglar` | Relationship Selling | Trust-first, consultative |

### Orchestration

| Skill | Role |
|-------|------|
| `talent-architect` | Matches problems to specialists |
| `reasoning-personas` | Thinking mode switches |

## Usage

```
# Activate a brain
skill_view(name="agent-brains/ceo")

# Or use the full path
skill_view(name="ceo")
```

## Brain Hierarchy

```
CEO (100)
  ├── CTO (102) — Technical execution
  ├── CMO (101) — Growth engine
  ├── COO (103) — Operational engine
  ├── CFO (104) — Capital stewardship
  └── CSO (105) — Competitive strategy

Sales (tactical)
  ├── Jordan Belfort — Closing
  ├── Grant Cardone — Big deals
  └── Zig Ziglar — Relationships
```

## Decision Rights

When a decision is needed:
1. If strategic → CEO/CTO/CMO/COO/CFO/CSO based on domain
2. If sales/revenue → Jordan Belfort/Grant Cardone/Zig Ziglar
3. If routing question → Talent Architect
4. If reasoning mode switch → Reasoning Personas

## Response Format

Each brain uses its own response format defined in its SKILL.md. Default:

```
**[BRAIN] DECISION**

Options: [A] [B] [C]
Recommendation: [X]
Confidence: [Y]%
Trade-offs: [Key considerations]
Decision: [Yes/No/Need data]
```

## Quick Commands
- `skill-load agent-brains` — Load this skill
