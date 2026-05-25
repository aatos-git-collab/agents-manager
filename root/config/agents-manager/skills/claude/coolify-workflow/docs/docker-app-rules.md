# Coolify Docker App Deployment Rules

## Build Packs
- `nixpacks` - Auto build detection (no Dockerfile)
- `static` - Static site with Nginx
- `dockerfile` - Custom Dockerfile at repository root
- `dockercompose` - Docker Compose deployment
- `dockerimage` - Pre-built Docker image

## Dockerfile Requirements

### Location
- Default: `/Dockerfile` at repository root
- Configurable via `dockerfile_location` field

### Key Requirements
1. **Expose correct port** - Use `EXPOSE` instruction
2. **Listen on 0.0.0.0** - Not `127.0.0.1` (critical for networking)
3. **Handle PORT env var** - Coolify injects `PORT` env var
4. **Respond to health check** - HTTP at `/` or custom HEALTHCHECK in Dockerfile

### Build Arguments Injected
```
SOURCE_COMMIT=<git-sha>
COOLIFY_BRANCH=<branch>
COOLIFY_FQDN=<app-url>
COOLIFY_URL=<app-url>
COOLIFY_RESOURCE_UUID=<uuid>
COOLIFY_CONTAINER_NAME=<container-name>
```

## Health Check

### Configuration Fields
```php
health_check_enabled      // boolean
health_check_type        // 'http' or 'cmd'
health_check_path        // URL path (default: '/')
health_check_port        // port (falls back to ports_exposes[0])
health_check_interval    // seconds (default: 5)
health_check_timeout     // seconds (default: 5)
health_check_retries     // retries (default: 10)
health_check_start_period // seconds before first check (default: 5)
```

### HTTP Health Check Command
```bash
curl -s -X GET -f http://localhost:<port>/<path> > /dev/null || exit 1
```

### Important: Port Mismatch
- `ports_exposes` shows `3000` but app runs on `6006`
- Health check uses `ports_exposes[0]` (3000) not actual app port (6006)
- This causes health check to fail → unhealthy

## Port Configuration

### ports_exposes vs ports_mappings
- `ports_exposes` - Internal container ports (what app listens on)
- `ports_mappings` - Host ports to map (optional)

### Port Resolution Order
1. `health_check_port` if set
2. First port in `ports_exposes_array`
3. Default to 80 for static builds

### Coolify-Wide Setting
The `ports_exposes` value is set at Coolify level, NOT in docker-compose.yml.
To change it, update the application settings in Coolify dashboard.

## Network

### Auto-created Network
- Coolify creates network named `<app-uuid>`
- Connects coolify-proxy for routing
- Containers must be on this network

### docker-compose networks
```yaml
networks:
  default:
    name: pawnshop_network      # Coolify managed
  <uuid>:                      # External network
    external: true
    name: <uuid>
    attachable: true
```

## Environment Variables

### Injected by Coolify (Runtime)
```
PORT=<main-exposed-port>
HOST=0.0.0.0
COOLIFY_FQDN=<app-url>
COOLIFY_URL=<app-url>
COOLIFY_CONTAINER_NAME=<container-name>
COOLIFY_BRANCH=<branch>
COOLIFY_RESOURCE_UUID=<uuid>
```

### Docker Compose Services (for inter-service communication)
```
SERVICE_URL_APP=https://rs.demo.nexeraa.io
SERVICE_FQDN_APP=rs.demo.nexeraa.io
SERVICE_NAME_APP=app
SERVICE_NAME_POSTGRES=postgres
```

## Common Issues → Unhealthy

### 1. Port Mismatch
**Problem**: Health check on wrong port
```
ports_exposes: 3000  ← Coolify setting (NOT in docker-compose)
Health check: http://localhost:3000  ← But app listens on 6006
```
**Fix**: Update `ports_exposes` in Coolify to `6006`

### 2. App Not Binding to 0.0.0.0
**Problem**: App listens on 127.0.0.1 or localhost
**Fix**: Set `HOST=0.0.0.0` env var or bind to 0.0.0.0 in code

### 3. Health Check Path Doesn't Exist
**Problem**: App doesn't respond at `/` path
**Fix**: Add health check endpoint OR disable health check

### 4. Slow Starting App
**Problem**: Health check fails before app is ready
**Fix**: Increase `health_check_start_period` (default 5s)

### 5. Missing Environment Variables
**Problem**: App fails to start without required env vars
**Fix**: Ensure all required env vars are set

## docker-compose.yml Additions by Coolify

Coolify automatically adds to all services:
```yaml
env_file:
  - .env

labels:
  - coolify.managed=true
  - coolify.version=4.0.0-beta.473
  - coolify.applicationId=<id>
  - coolify.type=application
  - coolify.name=<name>
  - coolify.resourceName=<resource>
  - coolify.projectName=<project>
  - coolify.serviceName=<service>
  - coolify.environmentName=<environment>
  - coolify.pullRequestId=<pr-id>
```

## Required for Coolify-Ready Apps

1. **Expose correct port** in Dockerfile or via Coolify settings
2. **Listen on 0.0.0.0** (bind to all interfaces)
3. **Respond to HTTP health check** at configured path
4. **Handle PORT env var** for port configuration
5. **No interactive prompts** - run headless
6. **Graceful shutdown** - handle SIGTERM

## Debug Commands

```bash
# Check container health
docker inspect --format='{{json .State.Health.Status}}' <container>

# Check container logs
docker logs -n 100 <container>

# Check running containers
docker ps

# Check networks
docker network ls
```

## Current Pawnshop Status

- **Docker Compose app** (mgzxm6wb7vahqjhme4pi3k6m): running:healthy ✅
  - ports_exposes: 6006
  - ports_mappings: 6006:6006
  - App logs show: "Ready in 202ms"
  - Health check now passes

### External Access Issue
- App is running inside Docker network on Coolify host
- Direct IP:6006 access fails because:
  1. FQDN is null - no traefik route configured
  2. Redirect is "both" - HTTP redirects to HTTPS
  3. Port mapping works inside Docker but host firewall may block
- To fix external access, set FQDN in Coolify dashboard or use Coolify's built-in URL

### Critical Finding: API Limitation for FQDN on DockerCompose Apps

**For dockercompose build_pack apps:**
- `domains` (fqdn) field CANNOT be set via PATCH API
- Error: "The domains field cannot be used for dockercompose applications. Use docker_compose_domains instead"
- `docker_compose_domains` sets domains in docker-compose file, but does NOT create traefik route
- Traefik routing requires `fqdn` to be set at application level

**Solution:**
1. Set FQDN manually in Coolify dashboard UI (only option for API)
2. Or use local Coolify for testing
3. Dockercompose apps use `docker_compose_domains` for service-level domain routing, not global FQDN

**Verification:** `docker_compose_domains: {"app":{"domain":"https:\/\/rs.demo.nexeraa.io"}}` is set but traefik still returns 503 because `fqdn` is null

### URL Resolution
- docker_compose_domains sets domain for services but doesn't create traefik route
- Without fqdn set, traefik returns 503 for all requests
- App logs show "Ready" - app itself is working correctly
- Traefik routing is the blocker