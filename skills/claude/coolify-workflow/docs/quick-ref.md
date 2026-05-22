# Coolify Workflow Quick Reference

## Commands

```bash
# Deploy a project
./scripts/deploy.sh <project_name>

# Check status
./scripts/status.sh <project_name>

# Get logs
./scripts/logs.sh <project_name> --tail 100

# List all projects
./scripts/list.sh

# Full git deploy workflow
./workflows/git-deploy.sh <project_name> --poll
```

## Adding New Projects

1. Find project UUID from Coolify:
```bash
./scripts/list.sh
```

2. Add to `config/projects.json`:
```json
{
  "project-name": {
    "uuid": "uuid-from-coolify",
    "git_repo": "org/repo",
    "branch": "main",
    "fqdn": "app.domain.com"
  }
}
```

3. Use project name in commands:
```bash
./scripts/deploy.sh project-name
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /applications | List all apps |
| GET | /applications/{uuid} | App details |
| POST | /applications/{uuid}/deploy | Trigger deploy |
| POST | /applications/{uuid}/stop | Stop app |
| POST | /applications/{uuid}/restart | Restart app |
| GET | /deployments/applications/{uuid} | Deployment history |
| GET | /deployments/{uuid} | Deployment details |
| POST | /deployments/{uuid}/cancel | Cancel deploy |
| GET | /applications/{uuid}/logs | App logs |
| GET | /version | API version |

## Troubleshooting

### "Unauthenticated"
- API key has wrong permissions
- Get new key with deploy permissions from Coolify UI

### Deployment fails
- Check logs: `./logs.sh <project>`
- Fix code locally
- Push again (Coolify auto-redeploys)

### Build fails
- Common: missing files in repo (like .next folder)
- Check Dockerfile copies all needed files
