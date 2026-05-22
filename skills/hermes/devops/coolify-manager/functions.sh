#!/bin/bash
# Coolify Manager Functions
# Learn and adapt from deployments

COOLIFY_URL="${COOLIFY_URL:-http://10.2.0.5:8000}"
COOLIFY_API_TOKEN="${COOLIFY_API_TOKEN:-1|zXmSq03f2Gtmi3o8HaG0PJtQYY3F5voLVZ6MciPI45ff7f31}"
AUTH_HEADER="Authorization: Bearer $COOLIFY_API_TOKEN"

# Get all resources
coolify_get_resources() {
    curl -s "$COOLIFY_URL/api/v1/resources" -H "$AUTH_HEADER"
}

# Get servers - returns just the UUIDs
coolify_get_servers() {
    curl -s "$COOLIFY_URL/api/v1/servers" -H "$AUTH_HEADER" 2>/dev/null | grep -o '"uuid":"[^"]*"' | head -1 | cut -d'"' -f4
}

# Get projects - returns id|uuid|name
coolify_get_projects() {
    curl -s "$COOLIFY_URL/api/v1/projects" -H "$AUTH_HEADER" 2>/dev/null | grep -o '"id":[0-9]*,"uuid":"[^"]*","name":"[^"]*"' | head -10
}

# Get project environments
coolify_get_env_uuid() {
    local project_uuid="$1"
    curl -s "$COOLIFY_URL/api/v1/projects/$project_uuid" -H "$AUTH_HEADER" 2>/dev/null | grep -o '"uuid":"[^"]*"' | head -2 | tail -1 | cut -d'"' -f4
}

# Create standalone service
coolify_create_service() {
    local name="$1"
    local compose_yaml="$2"
    local server_uuid="$3"
    local project_uuid="$4"
    local env_uuid="$5"
    
    local compose_base64=$(echo "$compose_yaml" | base64 -w 0)
    
    curl -s -X POST "$COOLIFY_URL/api/v1/services" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"docker_compose_raw\": \"$compose_base64\",
            \"server_uuid\": \"$server_uuid\",
            \"project_uuid\": \"$project_uuid\",
            \"environment_uuid\": \"$env_uuid\"
        }"
}

# Start service
coolify_start_service() {
    local service_uuid="$1"
    curl -s -X POST "$COOLIFY_URL/api/v1/services/$service_uuid/start" \
        -H "$AUTH_HEADER"
}

# Stop service
coolify_stop_service() {
    local service_uuid="$1"
    curl -s -X POST "$COOLIFY_URL/api/v1/services/$service_uuid/stop" \
        -H "$AUTH_HEADER"
}

# Restart service
coolify_restart_service() {
    local service_uuid="$1"
    curl -s -X POST "$COOLIFY_URL/api/v1/services/$service_uuid/restart" \
        -H "$AUTH_HEADER"
}

# Deploy complete service
coolify_deploy() {
    local name="$1"
    local compose_yaml="$2"
    local project_name="$3"
    
    echo "=== Deploying $name ==="
    
    # Get server UUID
    local server_uuid=$(coolify_get_servers | head -1)
    echo "Server UUID: $server_uuid"
    
    # Get project UUID by name
    local project_info=$(coolify_get_projects | grep "$project_name")
    if [ -z "$project_info" ]; then
        echo "ERROR: Project '$project_name' not found"
        return 1
    fi
    local project_uuid=$(echo "$project_info" | cut -d'|' -f2)
    echo "Project UUID: $project_uuid"
    
    # Get environment UUID
    local env_uuid=$(coolify_get_env_uuid "$project_uuid")
    echo "Environment UUID: $env_uuid"
    
    # Create service
    local result=$(coolify_create_service "$name" "$compose_yaml" "$server_uuid" "$project_uuid" "$env_uuid")
    echo "Create result: $result"
    
    # Extract service UUID
    local service_uuid=$(echo "$result" | jq -r '.uuid')
    
    if [ "$service_uuid" != "null" ]; then
        echo "Service UUID: $service_uuid"
        echo "Starting service..."
        coolify_start_service "$service_uuid"
        echo "=== $name deployed successfully ==="
    else
        echo "ERROR: Failed to create service"
        return 1
    fi
}

# Learn from deployment
coolify_learn() {
    local deployment_name="$1"
    local status="$2"
    local error="$3"
    
    echo "=== Learning from $deployment_name ==="
    echo "Status: $status"
    if [ -n "$error" ]; then
        echo "Error: $error"
        # Add error pattern to learning file
        echo "$(date): $deployment_name - $error" >> /root/.hermes/memory/coolify-manager-errors.log
    else
        echo "Success! Adding to successful patterns..."
    fi
}
