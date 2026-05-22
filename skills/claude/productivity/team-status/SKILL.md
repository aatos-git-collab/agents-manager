---
name: team-status
description: Show available enterprise agent team and their status
trigger: /team-status or to see available agents
---

# /team-status Command

Run this command to see available agent team status.

## Usage

```
/team-status
```

## Description

Shows the current agent team and their status:

- Available roles
- Active agents
- Current tasks
- Work distribution

## When to Use

- After onboarding
- To see available agents
- To understand team capabilities
- Before assigning tasks

## Available Agents

### Leadership
| Agent | Role | Skills |
|-------|------|--------|
| CTO | Architecture, standards | senior-fullstack, review |
| VP Engineering | Code quality | review, mentoring |
| Product Manager | Requirements | product, roadmap |

### Technical Specialists
| Agent | Role | Skills |
|-------|------|--------|
| Solutions Architect | System design | senior-fullstack |
| Security Engineer | Security | ln-760-security-setup |
| DevOps Engineer | Deployment | ln-730-devops-setup |
| Performance Engineer | Optimization | ln-810-performance-optimizer |

### Quality & Delivery
| Agent | Role | Skills |
|-------|------|--------|
| QA Lead | Test strategy | qa, test, ln-740-quality-setup |
| Backend Lead | API, DB | senior-backend, api-design |
| Frontend Lead | UI, UX | senior-frontend, react-dev |
| Code Reviewer | Quality | review |

### Specialists
| Agent | Role | Skills |
|-------|------|--------|
| WebApp Tester | QA | qa, webapp-testing |
| Docs Agent | Docs | copywriting |
| UI/UX Designer | Design | ui-ux-pro-max |

## Skills Available

### Production Readiness
- ln-760-security-setup
- ln-730-devops-setup
- ln-740-quality-setup
- ln-780-bootstrap-verifier

### Development
- qa
- test
- review
- systematic-debugging

### Architecture
- senior-backend
- senior-frontend
- senior-fullstack
- api-design

## Example Output

```
/team-status

## Enterprise Agent Team

### Leadership
- CTO: [ACTIVE] Architecture, standards
- VP Engineering: [AVAILABLE] Code quality
- Product Manager: [AVAILABLE] Requirements

### Technical
- Solutions Architect: [AVAILABLE] System design
- Security Engineer: [AVAILABLE] Security review
- DevOps Engineer: [AVAILABLE] Deployment
- Performance Engineer: [AVAILABLE] Optimization

### Quality
- QA Lead: [AVAILABLE] Test strategy
- Backend Lead: [AVAILABLE] API design
- Frontend Lead: [AVAILABLE] UI/UX
- Code Reviewer: [AVAILABLE] Reviews
```

## Notes

- Use PROMPT.md for full role descriptions
- CTO assigns tasks to appropriate agents
- Skills can be invoked directly via /skill-name
