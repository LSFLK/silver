#!/bin/bash

# ============================================
#  Thunder Identity Provider Implementation
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
# Thunder: Initialize
# ============================================
thunder_initialize() {
    local domain="$1"

    if [ -z "$domain" ]; then
        echo -e "${RED}✗ Domain is required for Thunder initialization${NC}" >&2
        return 1
    fi

    echo "  - Starting Thunder (WSO2) identity provider..."

    # Get the compose file path
    local compose_file=$(thunder_get_compose_file)

    if [ ! -f "$compose_file" ]; then
        echo -e "${RED}✗ Thunder docker-compose file not found: ${compose_file}${NC}" >&2
        return 1
    fi

    # Start Thunder services
    (cd "$(dirname "$compose_file")" && docker compose -f "$(basename "$compose_file")" up -d)

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to start Thunder services${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}  ✓ Thunder service started${NC}"
    return 0
}

# ============================================
# Thunder: Wait for Ready
# ============================================
thunder_wait_for_ready() {
    local host="$1"
    local port="${2:-8090}"

    if [ -z "$host" ]; then
        echo -e "${RED}✗ Host is required${NC}" >&2
        return 1
    fi

    echo "  - Waiting for Thunder to be ready..."

    local max_wait=120
    local wait_count=0

    while [ $wait_count -lt $max_wait ]; do
        # Check if Thunder is responding (401 is acceptable - means server is up but needs auth)
        local response_code=$(curl -k -s -o /dev/null -w "%{http_code}" "https://${host}:${port}/scim2/Users" 2>/dev/null)

        # 401 (Unauthorized) means Thunder is up and running, just needs authentication
        # 200 would mean it's accessible (unlikely without auth)
        if [ "$response_code" = "401" ] || [ "$response_code" = "200" ]; then
            echo -e "${GREEN}  ✓ Thunder is ready${NC}"
            return 0
        fi

        sleep 2
        wait_count=$((wait_count + 2))
        echo -n "."
    done

    echo -e "${RED}\n✗ Thunder did not become ready in time${NC}" >&2
    echo -e "${YELLOW}Note: Check Thunder logs with: docker logs thunder-server${NC}" >&2
    return 1
}

# ============================================
# Thunder: Configure
# ============================================
thunder_configure() {
    local domain="$1"

    if [ -z "$domain" ]; then
        echo -e "${RED}✗ Domain is required for Thunder configuration${NC}" >&2
        return 1
    fi

    echo "  - Configuring Thunder identity provider..."

    local thunder_host="$domain"
    local thunder_port=8090

    # Source Thunder authentication utility
    local utils_dir="$(cd "${SCRIPT_DIR}/../../utils" && pwd)"
    source "${utils_dir}/thunder-auth.sh"

    # Step 1: Authenticate with Thunder
    echo "  - Authenticating with Thunder..."
    if ! thunder_authenticate "$thunder_host" "$thunder_port"; then
        echo -e "${RED}✗ Failed to authenticate with Thunder${NC}" >&2
        return 1
    fi

    # Step 2: Create organization unit
    echo "  - Creating organization unit..."
    if ! thunder_create_org_unit "$thunder_host" "$thunder_port" "$BEARER_TOKEN" "silver" "Silver Mail" "Organization Unit for Silver Mail"; then
        echo -e "${RED}✗ Failed to create organization unit${NC}" >&2
        return 1
    fi

    # Step 3: Create user schema
    echo "  - Creating user schema..."
    local schema_response
    schema_response=$(curl -k -s -w "\n%{http_code}" -X POST \
        "https://${thunder_host}:${thunder_port}/user-schemas" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer ${BEARER_TOKEN}" \
        -d "{
            \"name\": \"emailuser\",
            \"ouId\": \"${ORG_UNIT_ID}\",
            \"schema\": {
                \"username\": { \"type\": \"string\", \"unique\": true },
                \"password\": { \"type\": \"string\" },
                \"email\": { \"type\": \"string\", \"unique\": true }
            }
        }")

    local schema_body=$(echo "$schema_response" | head -n -1)
    local schema_status=$(echo "$schema_response" | tail -n1)

    if [ "$schema_status" -eq 201 ] || [ "$schema_status" -eq 200 ]; then
        echo -e "${GREEN}  ✓ User schema 'emailuser' created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create user schema (HTTP $schema_status)${NC}" >&2
        echo "Response: $schema_body" >&2
        return 1
    fi

    # Step 4: Initialize domain in shared.db
    echo "  - Initializing domain in shared database..."
    source "${utils_dir}/shared-db-sync.sh"
    if db_init_domain "$domain"; then
        echo -e "${GREEN}  ✓ Domain initialized in mail database${NC}"
    else
        echo -e "${YELLOW}  ⚠ Warning: Failed to initialize domain in shared.db${NC}"
        echo -e "${YELLOW}  Mail services may not work properly until domain is initialized${NC}"
    fi

    echo -e "${GREEN}  ✓ Thunder configured successfully${NC}"
    return 0
}

# ============================================
# Thunder: Get Compose File
# ============================================
thunder_get_compose_file() {
    local idp_docker_dir="$(cd "${SCRIPT_DIR}/../docker" && pwd)"
    echo "${idp_docker_dir}/docker-compose.thunder.yaml"
}

# ============================================
# Thunder: Cleanup
# ============================================
thunder_cleanup() {
    echo "  - Cleaning up Thunder services..."

    local compose_file=$(thunder_get_compose_file)

    if [ ! -f "$compose_file" ]; then
        echo -e "${YELLOW}  ⚠ Thunder compose file not found: ${compose_file}${NC}"
        return 0
    fi

    (cd "$(dirname "$compose_file")" && docker compose -f "$(basename "$compose_file")" down)

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ Thunder services stopped${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to stop Thunder services${NC}" >&2
        return 1
    fi
}

# Export all functions
export -f thunder_initialize
export -f thunder_wait_for_ready
export -f thunder_configure
export -f thunder_get_compose_file
export -f thunder_cleanup