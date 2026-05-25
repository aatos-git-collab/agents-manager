#!/usr/bin/env bash
# Coolify Bash Helper Functions
# Source this file: source /root/.hermes/skills/devops/coolify-manager/scripts/functions.sh

# Load required env vars if not already set
_load_env() {
    if [ -z "$COOLIFY_MASTER_URL" ] || [ -z "$COOLIFY_TOKEN" ]; then
        local env_file="${COOLIFY_ENV_FILE:-/data/coolify/source/.env}"
        if [ -f "$env_file" ]; then
            export "$(grep -v '^#' "$env_file" | grep 'COOLIFY_MASTER_URL\|COOLIFY_TOKEN' | tr '\n' ' ' | tr -d ' ' | sed 's/#.*$//')" 2>/dev/null
        fi
    fi
    if [ -z "$COOLIFY_MASTER_URL" ] || [ -z "$COOLIFY_TOKEN" ]; then
        echo "ERROR: COOLIFY_MASTER_URL and COOLIFY_TOKEN must be set" >&2
        return 1
    fi
    export AUTH_HEADER="Authorization: Bearer $COOLIFY_TOKEN"
    export BASE_URL="${COOLIFY_MASTER_URL}/api/v1"
    return 0
}

coolify_health() {
    _load_env || return 1
    curl -s "$BASE_URL/health" || echo "FAILED"
}

coolify_get_resources() {
    _load_env || return 1
    curl -s "$BASE_URL/resources" -H "$AUTH_HEADER"
}

coolify_get_servers() {
    _load_env || return 1
    curl -s "$BASE_URL/servers" -H "$AUTH_HEADER"
}

coolify_get_projects() {
    _load_env || return 1
    curl -s "$BASE_URL/projects" -H "$AUTH_HEADER"
}

coolify_get_project() {
    _load_env || return 1
    local project_uuid="$1"
    curl -s "$BASE_URL/projects/$project_uuid" -H "$AUTH_HEADER"
}

coolify_get_env_uuid() {
    _load_env || return 1
    local project_uuid="$1"
    curl -s "$BASE_URL/projects/$project_uuid" -H "$AUTH_HEADER" | grep -oP '"uuid":"[^"]+","name":"production"' | head -1 | grep -oP '(?<=:")[a-f0-9-]{36}'
}

coolify_create_service() {
    _load_env || return 1
    local name="$1" compose_yaml="$2" server_uuid="$3" project_uuid="$4" env_uuid="$5"
    local compose_b64
    compose_b64="$(echo "$compose_yaml" | base64 -w 0)"
    curl -s -X POST "$BASE_URL/services" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "'"$name"'",
            "docker_compose_raw": "'"$compose_b64"'",
            "server_uuid": "'"$server_uuid"'",
            "project_uuid": "'"$project_uuid"'",
            "environment_uuid": "'"$env_uuid"'"
        }'
}

coolify_start_service() {
    _load_env || return 1
    local service_uuid="$1"
    curl -s -X POST "$BASE_URL/services/$service_uuid/start" -H "$AUTH_HEADER"
}

coolify_stop_service() {
    _load_env || return 1
    local service_uuid="$1"
    curl -s -X POST "$BASE_URL/services/$service_uuid/stop" -H "$AUTH_HEADER"
}

coolify_restart_service() {
    _load_env || return 1
    local service_uuid="$1"
    curl -s -X POST "$BASE_URL/services/$service_uuid/restart" -H "$AUTH_HEADER"
}

coolify_get_service() {
    _load_env || return 1
    local service_uuid="$1"
    curl -s "$BASE_URL/services/$service_uuid" -H "$AUTH_HEADER"
}

coolify_get_service_status() {
    _load_env || return 1
    local service_uuid="$1"
    curl -s "$BASE_URL/services/$service_uuid" -H "$AUTH_HEADER" | grep -oP '"status":"[^"]+"' | head -1
}

coolify_delete_service() {
    _load_env || return 1
    local service_uuid="$1"
    curl -s -X DELETE "$BASE_URL/services/$service_uuid" -H "$AUTH_HEADER"
}

coolify_deploy() {
    # Usage: coolify_deploy "my-app" "$compose_yaml" "$project_name"
    _load_env || return 1
    local name="$1" compose_yaml="$2" project_name="${3:-default}"
    
    # Get server UUID (first one)
    local server_uuid
    server_uuid="$(curl -s "$BASE_URL/servers" -H "$AUTH_HEADER" | grep -oP '(?<="uuid":")[a-f0-9-]{36}' | head -1)"
    if [ -z "$server_uuid" ]; then
        echo "ERROR: Could not find server UUID" >&2
        return 1
    fi
    
    # Get or create project
    local project_uuid
    project_uuid="$(curl -s "$BASE_URL/projects" -H "$AUTH_HEADER" | grep -oP '(?<="uuid":")[a-f0-9-]{36}' | head -1)"
    if [ -z "$project_uuid" ]; then
        echo "ERROR: Could not find project UUID" >&2
        return 1
    fi
    
    # Get environment UUID
    local env_uuid
    env_uuid="$(curl -s "$BASE_URL/projects/$project_uuid" -H "$AUTH_HEADER" | grep -oP '(?<=:")[a-f0-9-]{36}' | head -1)"
    
    echo "Deploying $name..."
    echo "Server: $server_uuid | Project: $project_uuid | Env: $env_uuid"
    
    coolify_create_service "$name" "$compose_yaml" "$server_uuid" "$project_uuid" "$env_uuid"
}
