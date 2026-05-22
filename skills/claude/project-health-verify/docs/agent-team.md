# Project Health Verify - Agent Team

## Purpose
This skill provides automated health verification for any project using a multi-agent approach.

## Agent Roles

### Primary Agents
1. **Health Checker** - Scans code for issues, broken imports, missing configs
2. **Build Validator** - Runs production builds, captures errors
3. **Browser Tester** - Uses Playwright for frontend verification
4. **Debugger** - Investigates failures, proposes fixes

## Workflow

```
Health Check → Build → Dev Server → Browser Test → Report
     ↓            ↓          ↓            ↓
   [FAIL]      [FAIL]     [FAIL]       [FAIL]
     ↓            ↓          ↓            ↓
   Debug        Debug      Debug        Debug
```

## Error Handling
- Any failure triggers debugger investigation
- Debugger provides fix suggestions
- Human review for critical issues
- Auto-fix when confidence is high

## Quality Gates
- 0 console errors
- 0 page errors
- HTTP 200 response
- Build completes without warnings
- Dev server starts within 30s