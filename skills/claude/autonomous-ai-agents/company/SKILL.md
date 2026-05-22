---
name: company
description: company skill
  Specialist worker agents for aatosteam teams. These are executor agents
  spawned as workers by the team leader (a C-Suite agent from agent-brains).
  Use these when building a team that needs domain expertise — product management,
  legal review, marketing, sales, engineering, operations, etc.
version: 1.0.0
metadata:
  for_framework: aatosteam
  agent_type: specialist-worker
  leader_source: agent-brains
---

# Company — Specialist Worker Agents

These agents are spawned as **workers** by an aatosteam leader agent.
They bring deep domain expertise to the team without needing to think strategically —
that job belongs to the C-Suite leader (CTO, CFO, etc.).

## Usage

```bash
# Spawn a specialist worker with its skill injected
aatosteam spawn --team my-team --agent-name pm --skill company/product-manager --task "Define requirements for feature X"

# Spawn multiple specialists
aatosteam spawn --team my-team --agent-name dev --skill company/frontend-developer --task "Build the UI"
aatosteam spawn --team my-team --agent-name legal --skill company/contract-reviewer --task "Review MSA"
```

## Departments

# Company — Specialist Worker Agents
These are specialist executor agents that get spawned by aatosteam as workers.
## Departments

### Client Management
| Skill | Description ||-------|-------------|| `client-manager` | *See SKILL.md* || `scope-change-handler` | *See SKILL.md* |
### Design
| Skill | Description ||-------|-------------|| `design-system-manager` | *See SKILL.md* || `ui-designer` | *See SKILL.md* || `ux-researcher` | *See SKILL.md* |
### Engineering
| Skill | Description ||-------|-------------|| `backend-architect` | *See SKILL.md* || `code-reviewer` | *See SKILL.md* || `estimator` | *See SKILL.md* || `frontend-developer` | *See SKILL.md* || `infrastructure-maintainer` | *See SKILL.md* |
### Legal
| Skill | Description ||-------|-------------|| `contract-reviewer` | *See SKILL.md* || `ip-protector` | *See SKILL.md* || `nda-manager` | *See SKILL.md* |
### Marketing
| Skill | Description ||-------|-------------|| `analytics-reporter` | *See SKILL.md* || `content-creator` | *See SKILL.md* || `distribution-manager` | *See SKILL.md* || `experiment-tracker` | *See SKILL.md* || `launch-strategist` | *See SKILL.md* || `test-results-analyzer` | *See SKILL.md* || `tiktok-strategist` | *See SKILL.md* |
### Operations
| Skill | Description ||-------|-------------|| `finance-tracker` | *See SKILL.md* || `knowledge-manager` | *See SKILL.md* || `onboarding-coordinator` | *See SKILL.md* || `support-responder` | *See SKILL.md* || `vision-keeper` | *See SKILL.md* |
### Product
| Skill | Description ||-------|-------------|| `feedback-synthesizer` | *See SKILL.md* || `opportunity-evaluator` | *See SKILL.md* || `product-manager` | *See SKILL.md* || `sprint-planner` | *See SKILL.md* |
### Project Management
| Skill | Description ||-------|-------------|| `delivery-manager` | *See SKILL.md* || `priority-arbiter` | *See SKILL.md* || `release-retrospective-owner` | *See SKILL.md* |
### Sales
| Skill | Description ||-------|-------------|| `account-executive` | *See SKILL.md* || `proposal-writer` | *See SKILL.md* || `sales-developer` | *See SKILL.md* |
### Security
| Skill | Description ||-------|-------------|| `access-controller` | *See SKILL.md* || `compliance-monitor` | *See SKILL.md* || `incident-responder` | *See SKILL.md* || `security-auditor` | *See SKILL.md* |
### Testing
| Skill | Description ||-------|-------------|| `automation-engineer` | *See SKILL.md* || `bug-triager` | *See SKILL.md* || `qa-tester` | *See SKILL.md* |
