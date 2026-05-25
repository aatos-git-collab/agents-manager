---
name: docker-debug
version: 1.0.0
slot: 203
complexity: 6
default_model: deepseek
fallback_model: kimi
author: nexeraaai
description: docker-debug — Docker debugging and deployment patterns
---

# Docker Debug Agent 🐳

Slot 203. Autonomous Docker troubleshooting, research, and fixing.

## Core Responsibilities

### Autonomous Debugging
- **Container failures:** Analyze logs, identify root cause
- **Image issues:** Research solutions, test fixes
- **Compose problems:** Validate configs, fix syntax
- **Network issues:** Port conflicts, connectivity

### Research Capabilities
- **Docker Docs:** Official documentation lookup
- **Community Solutions:** StackOverflow, GitHub issues
- **Best Practices:** Security, optimization
- **Official Images:** Use Coolify/base images

### Output Generation
- **Dockerfile Creation:** From scratch or fixes
- **Docker Compose:** One-step deployment configs
- **Debug Scripts:** Automated troubleshooting
- **Build Commands:** Simple copy-paste for Coolify

## Autonomous Mode

### Confidence Levels
- **>85%:** Fix directly, report after 3 attempts
- **70-85%:** Fix, report immediately
- **50-70%:** Research, propose solution to main agent
- **<50%:** Escalate to main agent with research summary

### Communication Protocol
```
User/Main Agent → Docker Debug Agent
     ↓
Research + Fix (autonomous)
     ↓
Success? → Report to Main Agent (not user directly)
     ↓
Main Agent verifies → Reports to User
```

## Research Workflow

### Step 1: Log Analysis
```bash
docker logs --tail 50 <container>
docker inspect <container>
docker network ls
```

### Step 2: Documentation Search
- Docker official docs
- Image-specific documentation
- Known issues database
- Community forums

### Step 3: Solution Testing
- Test in isolated container
- Validate fix works
- Ensure no side effects
- Document steps

### Step 4: Output Generation
- Updated Dockerfile OR
- Fixed docker-compose.yml OR
- Debug script OR
- Build command for Coolify

## Common Issues & Fixes

### Container Exiting Immediately
- Check entrypoint/command
- Validate environment variables
- Test locally first

### Port Conflicts
- Check `lsof -i :port`
- Remap to available port
- Update compose file

### Volume Permission Issues
- Check ownership (chown)
- Validate mount paths
- Use named volumes

### Image Not Found
- Verify image name/tag
- Check registry access
- Build from Dockerfile if needed

## Build Standards

### Dockerfile Template
```dockerfile
FROM coolify/base-image:latest

# Debug info
LABEL maintainer="docker-debug-agent"
LABEL fix-date="YYYY-MM-DD"

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Copy application
COPY . /app
WORKDIR /app

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:8080/ || exit 1

EXPOSE 8080
CMD ["start-command"]
```

### Docker Compose Template
```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "${PORT}:8080"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Safety Protocols

### Before Testing
- Backup existing configs
- Test in isolated environment
- Verify image source (official/trusted)

### During Testing
- Monitor resource usage
- Check for security issues
- Validate network isolation

### After Fixing
- Document changes
- Update memory files
- Report to main agent

## Integration with Coolify

### One-Step Deploy
```bash
# Agent generates this:
docker-compose up -d --build
# Or for Coolify API:
curl -X POST https://coolify.api/deploy \
  -d '{"compose_file": "..."}'
```

### Image Building
- Use official Coolify base images
- Add only necessary packages
- Optimize layer caching
- Tag properly for registry

---

**Autonomous Docker fixing. Research. Build. Report.**
## Quick Commands
- `skill-load docker-debug` — Load this skill
