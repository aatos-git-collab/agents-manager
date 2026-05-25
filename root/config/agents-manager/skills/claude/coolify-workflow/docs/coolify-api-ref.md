# Coolify Skill Reference

## Project Info
- COOLIFY_URL: https://control.agent.nexeraa.io
- COOLIFY_API_KEY: In /root/.env → COOLIFY_API_KEY
- Current Project UUID: pyzfz7lqd7s6t2shn4g7iugf
- Environment UUID: ndrube09ibbzum4rfrgll3h9
- Default Server: localhost (jimtir4bqnmwm82g2go2e9uf)

## Base API
All calls: `curl -H "Authorization: Bearer $COOLIFY_API_KEY" https://control.agent.nexeraa.io/api/v1/...`

---

## Application Commands

### List applications
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/applications" | python3 -c "..."
```

### Get application
```bash
# Replace with actual UUID and use python to extract fields
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/applications/{uuid}"
```

### Deploy application
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" -X POST \
  "https://control.agent.nexeraa.io/api/v1/deploy" \
  -H "Content-Type: application/json" \
  -d '{"application_uuid":"uuid","environment_uuid":"env-uuid"}'
```

### Restart application
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/applications/{uuid}/restart"
```

### Stop application
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/applications/{uuid}/stop"
```

### Get deployments
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/deployments/applications/{uuid}" | python3 -c "..."
```

### Get single deployment logs
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/deployments/{uuid}" | python3 -c "
import json,sys
d=json.load(sys.stdin)
logs_str = d.get('logs','')
if logs_str:
    logs = json.loads(logs_str)
    for e in logs:
        if not e.get('hidden'): print(f\"{e.get('timestamp','')[:19]} | {e.get('output','')[:300]}\")"
```

### Update application (if allowed)
PATCH `/api/v1/applications/{uuid}` - only some fields allowed

---

## Database Commands

### List databases
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/databases"
```

### Get database details
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/databases/{uuid}"
```

### Start database
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" -X POST \
  "https://control.agent.nexeraa.io/api/v1/databases/{uuid}/start"
```

### Stop database
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" -X POST \
  "https://control.agent.nexeraa.io/api/v1/databases/{uuid}/stop"
```

### Get DB backups
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/databases/{uuid}/backups"
```

### Create DB backup
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" -X POST \
  "https://control.agent.nexeraa.io/api/v1/databases/{uuid}/backups" \
  -H "Content-Type: application/json" \
  -d '{"databases_to_backup":"default","frequency":"daily","save_s3":false,"keep_all":true}'
```

### Get DB logs
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" \
  "https://control.agent.nexeraa.io/api/v1/databases/{uuid}/logs"
```

### Bulk update DB env vars
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" -X PATCH \
  "https://control.agent.nexeraa.io/api/v1/databases/{uuid}/envs/bulk" \
  -H "Content-Type: application/json" \
  -d '{"39f9a72d-...":"value","...":"..."}'  # key=value pairs
```

### Bulk update app env vars
```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_KEY" -X PATCH \
  "https://control.agent.nexeraa.io/api/v1/applications/{uuid}/envs/bulk" \
  -H "Content-Type: application/json" \
  -d '{"APP_ENV":"production","DB_HOST":"...","...":"..."}'
```

---

## Key Fields Reference

### Database internal URL
```json
{
  "internal_db_url": "mysql://mysql:password@db-uuid:3306/default",
  "mysql_user": "mysql",
  "mysql_password": "...",
  "mysql_database": "default",
  "status": "running:healthy"
}
```

### App fields
```json
{
  "build_pack": "dockercompose|dockerfile|nixpacks",
  "status": "running:healthy",
  "fqdn": "app.domain.com",
  "ports_exposes": "3000",
  "uuid": "..."
}
```

---

## Troubleshooting

### App unhealthy
1. Check `ports_exposes` matches app port (not Coolify setting - actual exposed port)
2. Check `fqdn` is set (required for traefik routing)
3. Check `health_check_port` if set
4. Use restart: `POST /applications/{uuid}/restart`

### Dockercompose build pack can't find compose file
- Default compose path at `/`
- Coolify injects env_file: .env to all services
- Health check via traefik may fail without proper FQDN

### App shows as failed but build succeeds
- Usually traefik routing issue (no FQDN set)
- Or port mismatch (app listens on different port than exposed)

### DB unhealthy/exited
- Check logs via GET /databases/{uuid}/logs
- Restart via POST /databases/{uuid}/start
- Delete and recreate if persistent