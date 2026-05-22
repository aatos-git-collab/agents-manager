---
name: docker-manager
description: 🐳 Docker Manager Skill
---

# 🐳 Docker Manager Skill

## Description

Manage Docker containers, images, and networks. Provides full lifecycle management for containerized applications in the ecosystem.

## Requirements

- **Docker:** 20.10+ installed and accessible
- **Permissions:** Docker socket access (/var/run/docker.sock)
- **Python:** 3.10+ (for Python implementation)

## Usage

### Container Lifecycle

```bash
# Start a container
docker.start(container_id="my-container")

# Stop a container
docker.stop(container_id="my-container")

# Restart a container
docker.restart(container_id="my-container")

# Get container status
docker.status(container_id="my-container")
```

### Image Management

```bash
# Pull an image
docker.pull(image="myregistry/myimage:latest")

# List images
docker.images()

# Remove unused images
docker.prune_images(space_threshold_gb=10)
```

### Container Operations

```bash
# Get container logs
docker.logs(container_id="my-container", tail=100)

# Execute command in container
docker.exec(
  container_id="my-container",
  command="ls -la",
  workdir="/app"
)

# Copy files to/from container
docker.cp(
  container_id="my-container",
  source="/local/file",
  destination="/container/path"
)
```

---

## Tool Functions

### start
Start a stopped container.

**Parameters:**
- `container_id` (string): Container name or ID
- `timeout` (int, optional): Start timeout in seconds

**Returns:** Confirmation of start

### stop
Gracefully stop a running container.

**Parameters:**
- `container_id` (string): Container name or ID
- `timeout` (int, optional): Grace period in seconds (default: 10)

**Returns:** Confirmation of stop

### restart
Restart a container.

**Parameters:**
- `container_id` (string): Container name or ID
- `timeout` (int, optional): Stop timeout

**Returns:** Confirmation of restart

### status
Get detailed container status.

**Parameters:**
- `container_id` (string): Container name or ID

**Returns:** Status object with CPU, memory, network stats

### logs
Retrieve container logs.

**Parameters:**
- `container_id` (string): Container name or ID
- `tail` (int, optional): Number of lines from end
- `follow` (bool, optional): Follow log stream
- `timestamps` (bool, optional): Include timestamps

**Returns:** Log output

### exec
Execute a command in a running container.

**Parameters:**
- `container_id` (string): Container name or ID
- `command` (string): Command to execute
- `workdir` (string, optional): Working directory
- `env` (object, optional): Environment variables
- `timeout` (int, optional): Execution timeout

**Returns:** Command output

### pull
Pull a Docker image from registry.

**Parameters:**
- `image` (string): Image name with tag
- `auth` (string, optional): Registry authentication

**Returns:** Pull progress and confirmation

### images
List all Docker images.

**Parameters:**
- `filters` (object, optional): Image filters

**Returns:** List of images with details

### ps
List running containers.

**Parameters:**
- `all` (bool, optional): Include stopped containers
- `filters` (object, optional): Container filters

**Returns:** List of containers

### prune
Clean up unused resources.

**Parameters:**
- `containers` (bool): Remove stopped containers
- `images` (bool): Remove dangling images
- `volumes` (bool): Remove unused volumes
- `space_threshold_gb` (int): Threshold for auto-prune

**Returns:** Cleanup results

---

## Example Use Cases

### 1. Deploy Container

```python
# Pull latest image
docker.pull(image="my-image:latest")

# Run container
docker.run(
  image="my-image:latest",
  name="my-production-container",
  ports={"8080": 8080},
  volumes={
    "/data/my-workspace": "/workspace",
    "/var/run/docker.sock": "/var/run/docker.sock"
  },
  env={"MY_ENV_VAR": "..."},
  restart_policy="unless-stopped"
)
```

### 2. Monitor Container Health

```python
# Check status periodically
status = docker.status(container_id="my-container")

if status.health != "healthy":
    docker.restart(container_id="my-container")
    alert_manager.send(
        level="warning",
        message=f"Container restarted: {status}"
    )
```

### 3. Debug Container Issues

```python
# Get logs and exec into container
logs = docker.logs(container_id="my-container", tail=50)
output = docker.exec(
    container_id="my-container",
    command="cat /var/log/app.log",
    workdir="/"
)
```

---

## Error Handling

| Error Code | Description | Resolution |
|------------|-------------|------------|
| CONTAINER_NOT_FOUND | Container doesn't exist | Check container name/ID |
| CONTAINER_NOT_RUNNING | Container is stopped | Start container first |
| IMAGE_NOT_FOUND | Image not available | Pull image |
| PERMISSION_DENIED | No Docker access | Check socket permissions |
| COMMAND_FAILED | Exec command failed | Check command syntax |

---

## Metrics Collected

- Container CPU usage (%)
- Memory usage (MB/GB)
- Network I/O (bytes)
- Block I/O (bytes)
- Container restart count
- Uptime

---

## Security Considerations

1. **Socket Permissions:** Ensure proper socket access
2. **Image Security:** Scan images for vulnerabilities
3. **Resource Limits:** Set CPU/memory limits
4. **Network Isolation:** Use Docker networks
5. **Secrets Management:** Don't store secrets in images

---

## Best Practices

1. **Use tagged images** - Avoid `latest` tag in production
2. **Set resource limits** - Prevent resource exhaustion
3. **Monitor health** - Implement health checks
4. **Log management** - Centralize logs
5. **Regular cleanup** - Prune unused resources

---

## Integration Points

- **server-monitor:** Combine for infrastructure monitoring
- **deployment-orchestrator:** Use for application deployments
- **alert-manager:** Send alerts on container failures
- **metrics-collector:** Feed metrics to monitoring

---

*Skill Version: 1.0.0*
*For: Infrastructure Management*
*Requires: Docker 20.10+*
