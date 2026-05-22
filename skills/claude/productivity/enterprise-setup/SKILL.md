---
name: enterprise-setup
description: Set up new project with enterprise standards - creates CLAUDE.md, ARCHITECTURE.md, .lessons directory
trigger: /enterprise-setup or when project needs onboarding
---

# Enterprise Setup Skill

This skill sets up a new project with enterprise standards.

## When to Use

- Project has no CLAUDE.md at root
- Running `/onboard` command
- Setting up new project for enterprise development

## Steps

### 1. Check Project Status
- Check if CLAUDE.md exists at project root
- Check if ARCHITECTURE.md exists
- Check if .lessons/ directory exists

### 2. Gather Project Information
Ask user for:
- Project name
- Tech stack (frontend, backend, database)
- Deployment target (cloud, container, etc.)
- Team size
- Security requirements

### 3. Create CLAUDE.md
Create project-specific CLAUDE.md with:
- Project overview
- Tech stack
- Key commands
- Project structure
- Security requirements
- Quality standards
- Reference to PROMPT.md

### 4. Create ARCHITECTURE.md
Create architecture document with:
- System architecture diagram (text)
- Component overview
- Data flows
- API endpoints
- Security considerations

### 5. Create .lessons/ Directory
- Create .lessons/ directory
- Add TEMPLATE.md for session learnings
- Add initial session tracking

### 6. Copy .claude from template
- Copy .claude directory to project root
- Validate settings.json is valid

### 7. Validate Setup
- Verify CLAUDE.md loads correctly
- Verify ARCHITECTURE.md is complete
- Verify .lessons/ is writable

## Output

After setup:
- Project has CLAUDE.md at root
- Project has ARCHITECTURE.md at root
- Project has .lessons/ directory
- Project has .claude/ directory with enterprise settings

## Notes

- This skill is typically run once per project
- After setup, use PROMPT.md for ongoing agent team workflow
- CTO role will manage ongoing development
## Quick Commands
- `skill-load enterprise-setup` — Load this skill
