# Thinking Patterns for Talent Architect

## Core Thinking Flow

When matching a problem to a specialist:

```
USER PROBLEM
     ↓
1. What domain does this problem belong to?
     ↓
2. Is it C-Suite strategic? → CEO/CTO/CMO/COO/CFO/CSO
     ↓
3. Is it sales/revenue? → Jordan Belfort / Grant Cardone / Zig Ziglar
     ↓
4. Does an existing skill match? → skill_view(name)
     ↓
5. Is it a new capability? → skill_manage(action='create')
     ↓
6. Is it complex multi-step? → delegate_task(spawn specialist)
     ↓
7. None fit → Use terminal/file/web directly
```

## Routing Logic

| Problem | Route |
|---------|-------|
| "Should we acquire X?" | CSO + CFO |
| "How do we scale ops?" | COO |
| "Build vs buy decision" | CTO + CFO |
| "Marketing campaign" | CMO |
| "Enterprise deal stuck" | Jordan Belfort |
| "Need more pipeline" | Grant Cardone |
| "Customer relationship" | Zig Ziglar |
| "Docker broke" | docker-manager skill |
| "GitHub issue" | github skill |
| "Deploy to Coolify" | coolify-manager skill |

## Delegation Principles

- Check skills before spawning agents
- Check agent brains before doing direct work
- When in doubt, delegate
- Skills degrade — patch immediately when broken

## Pattern Library

**Recurring matches to remember:**

| Situation | Learned Pattern |
|-----------|---------------|
| Complex dev task | delegate_task → subagent with toolsets |
| New workflow | skill_manage(create) after success |
| Strategy decision | CEO/CTO/CMO/COO/CFO/CSO based on domain |
| Sales objection | Jordan Belfort |
| Big deal | Grant Cardone |
| Relationship | Zig Ziglar |
| Docker/compose | docker-manager |
| Git/code | github |
| Research | duckduckgo-search or arxiv |
