---
name: production-ready
description: Run production readiness checklist - security, performance, testing, deployment validation
trigger: /production-check or before major releases
---

# Production Ready Skill

This skill runs a comprehensive production readiness checklist.

## When to Use

- Running `/production-check` command
- Before major releases
- After significant feature completion
- When CTO requests validation

## Production Readiness Checklist

### 1. Security Validation
- [ ] Run ln-760-security-setup
- [ ] No secrets in code
- [ ] Dependencies are secure
- [ ] Security headers configured
- [ ] Input validation implemented

### 2. Testing Coverage
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] E2E tests pass
- [ ] Test coverage > 80%
- [ ] No critical bugs

### 3. Performance
- [ ] Run ln-810-performance-optimizer
- [ ] API response times < 200ms
- [ ] Page load < 3 seconds
- [ ] No memory leaks
- [ ] Database queries optimized

### 4. Deployment Readiness
- [ ] Run ln-730-devops-setup
- [ ] Docker build succeeds
- [ ] Environment variables configured
- [ ] CI/CD pipeline passes
- [ ] Rollback plan exists

### 5. Documentation
- [ ] API documentation complete
- [ ] README updated
- [ ] ARCHITECTURE.md current
- [ ] Deployment docs ready

### 6. Monitoring & Observability
- [ ] Logging configured
- [ ] Metrics collection ready
- [ ] Alerts configured
- [ ] Dashboards created

## Output

Generate Production Readiness Report:
```
## Production Readiness Report
Generated: [DATE]

### Status: [READY / NOT READY]

### Critical Items:
- [ ] Item 1: STATUS
- [ ] Item 2: STATUS

### Recommendations:
1. ...
2. ...

### Sign-off Required:
- [ ] CTO
- [ ] Security Engineer
- [ ] DevOps
```

## Notes

- Use ln-780-bootstrap-verifier for build validation
- Document all issues in .lessons/ for CTO review
- Get sign-off from all required roles before production
## Quick Commands
- `skill-load production-ready` — Load this skill
