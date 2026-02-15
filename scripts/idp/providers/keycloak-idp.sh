#!/bin/bash

# ============================================
#  Keycloak Identity Provider Implementation
# ============================================

# Source the interface
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../idp-interface.sh"

# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

# ============================================
# Keycloak: Initialize
# ============================================
keycloak_initialize() {
    local domain="$1"

    if [ -z "$domain" ]; then
        echo -e "${RED}✗ Domain is required for Keycloak initialization${NC}" >&2
        return 1
    fi

    echo "  - Starting Keycloak identity provider..."

    # Get the compose file path
    local compose_file=$(keycloak_get_compose_file)

    if [ ! -f "$compose_file" ]; then
        echo -e "${RED}✗ Keycloak docker-compose file not found: ${compose_file}${NC}" >&2
        return 1
    fi

    # Start Keycloak services
    (cd "$(dirname "$compose_file")" && docker compose -f "$(basename "$compose_file")" up -d)

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to start Keycloak services${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}  ✓ Keycloak service started${NC}"
    return 0
}

# ============================================
# Keycloak: Wait for Ready
# ============================================
keycloak_wait_for_ready() {
    local host="$1"
    local port="${2:-8080}"

    if [ -z "$host" ]; then
        echo -e "${RED}✗ Host is required${NC}" >&2
        return 1
    fi

    echo "  - Waiting for Keycloak to be ready..."

    local max_wait=120
    local wait_count=0

    while [ $wait_count -lt $max_wait ]; do
        # Try multiple health check endpoints
        if curl -s -f "http://${host}:${port}/health/ready" > /dev/null 2>&1 || \
           curl -s -f "http://${host}:${port}/health" > /dev/null 2>&1 || \
           curl -s "http://${host}:${port}/realms/master" 2>/dev/null | grep -q "realm" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Keycloak is ready${NC}"
            return 0
        fi
        sleep 2
        wait_count=$((wait_count + 2))
        echo -n "."
    done

    echo -e "${RED}\n✗ Keycloak did not become ready in time${NC}" >&2
    echo -e "${YELLOW}Note: Check Keycloak logs with: docker logs keycloak-server${NC}" >&2
    return 1
}

# ============================================
# Keycloak: Configure
# ============================================
keycloak_configure() {
    local domain="$1"

    if [ -z "$domain" ]; then
        echo -e "${RED}✗ Domain is required for Keycloak configuration${NC}" >&2
        return 1
    fi

    echo "  - Configuring Keycloak identity provider..."

    local keycloak_host="$domain"
    local keycloak_port=8080

    # Source Keycloak authentication utility
    local utils_dir="$(cd "${SCRIPT_DIR}/../../utils" && pwd)"
    source "${utils_dir}/keycloak-auth.sh"

    # Step 1: Authenticate with Keycloak (master realm)
    echo "  - Authenticating with Keycloak..."
    if ! keycloak_authenticate "$keycloak_host" "$keycloak_port" "master" "${KEYCLOAK_ADMIN}" "${KEYCLOAK_ADMIN_PASSWORD}"; then
        echo -e "${RED}✗ Failed to authenticate with Keycloak${NC}" >&2
        return 1
    fi

    # Step 2: Create Silver Mail realm
    echo "  - Creating Silver Mail realm..."
    local realm_name="silver-mail"
    if ! keycloak_create_realm "$keycloak_host" "$keycloak_port" "$KEYCLOAK_ACCESS_TOKEN" "$realm_name" "Silver Mail"; then
        echo -e "${RED}✗ Failed to create realm${NC}" >&2
        return 1
    fi

    # Step 3: Create client for Silver Mail
    echo "  - Creating Silver Mail client..."
    local client_id="silver-mail-client"
    if ! keycloak_create_client "$keycloak_host" "$keycloak_port" "$realm_name" "$KEYCLOAK_ACCESS_TOKEN" "$client_id" "Silver Mail Client"; then
        echo -e "${RED}✗ Failed to create client${NC}" >&2
        return 1
    fi

    # Step 4: Setup user attributes and federation
    echo "  - Setting up user attributes and federation..."
    # Note: In Keycloak, user attributes are flexible by default
    # You can create custom user attributes as needed via user federation or custom mappers
    echo -e "${GREEN}  ✓ Keycloak realm configured for email user management${NC}"

    # Step 5: Initialize domain in shared.db
    echo "  - Initializing domain in shared database..."
    source "${utils_dir}/shared-db-sync.sh"
    if db_init_domain "$domain"; then
        echo -e "${GREEN}  ✓ Domain initialized in mail database${NC}"
    else
        echo -e "${YELLOW}  ⚠ Warning: Failed to initialize domain in shared.db${NC}"
        echo -e "${YELLOW}  Mail services may not work properly until domain is initialized${NC}"
    fi

    echo -e "${GREEN}  ✓ Keycloak configured successfully${NC}"
    return 0
}

# ============================================
# Keycloak: Get Compose File
# ============================================
keycloak_get_compose_file() {
    local idp_docker_dir="$(cd "${SCRIPT_DIR}/../docker" && pwd)"
    echo "${idp_docker_dir}/docker-compose.keycloak.yaml"
}

# ============================================
# Keycloak: Cleanup
# ============================================
keycloak_cleanup() {
    echo "  - Cleaning up Keycloak services..."

    local compose_file=$(keycloak_get_compose_file)

    if [ ! -f "$compose_file" ]; then
        echo -e "${YELLOW}  ⚠ Keycloak compose file not found: ${compose_file}${NC}"
        return 0
    fi

    (cd "$(dirname "$compose_file")" && docker compose -f "$(basename "$compose_file")" down)

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ Keycloak services stopped${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to stop Keycloak services${NC}" >&2
        return 1
    fi
}

# Export all functions
export -f keycloak_initialize
export -f keycloak_wait_for_ready
export -f keycloak_configure
export -f keycloak_get_compose_file
export -f keycloak_cleanup