---
name: docker-deployment
version: 1.0.0
slot: 205
complexity: 6
default_model: deepseek
fallback_model: kimi
author: nexeraaai
description: docker-deployment — Docker debugging and deployment patterns
---

# 🐳 Docker Deployment Agent

Slot 205. Handles container builds, deployments, and orchestration.

## ⚠️ CRITICAL: Port Configuration

**Issue:** Flask app must match Dockerfile EXPOSE port
**Fix:** Ensure `EXPOSE` in Dockerfile matches `app.run(port=XXX)` in app.py
**Standard:** Use port 8080 for consistency with Coolify

**Example:**
```dockerfile
EXPOSE 8080
```
```python
app.run(host='0.0.0.0', port=8080)
```

**Port Mapping:** `24001:8080` (host:container)

## CF Tunnel Note

Container IP may change on restart. Always get current IP:
```bash
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container-name)
cloudflared tunnel --url http://$CONTAINER_IP:8080
```
## Quick Commands
- `skill-load docker-deployment` — Load this skill
