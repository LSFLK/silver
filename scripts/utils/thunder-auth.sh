#!/bin/bash

# ============================================
#  Thunder Authentication Utility
# ============================================
#
# This utility provides shared authentication functions for Thunder API.
# Source this file in your scripts to use the authentication functions.
#
# Usage:
#   source "$(dirname "$0")/../utils/thunder-auth.sh"
#   thunder_authenticate "$THUNDER_HOST" "$THUNDER_PORT"
#   # Now you can use: $SAMPLE_APP_ID, $BEARER_TOKEN
#
#   thunder_get_org_unit "$THUNDER_HOST" "$THUNDER_PORT" "$BEARER_TOKEN" "silver"
#   # Now you can use: $ORG_UNIT_ID
#

# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# ============================================
# Function: Extract Sample App ID from Thunder setup logs
# ============================================
thunder_get_sample_app_id() {
    local sample_app_id
    sample_app_id=$(docker logs thunder-setup 2>&1 | grep 'Sample App ID:' | head -n1 | grep -o '[a-f0-9-]\{36\}')

    if [ -z "$sample_app_id" ]; then
        echo -e "${RED}✗ Failed to extract Sample App ID from Thunder setup logs${NC}" >&2
        echo "Please ensure Thunder setup container has completed successfully." >&2
        return 1
    fi

    echo "$sample_app_id"
    return 0
}

# ============================================
# Function: Authenticate with Thunder and get Bearer token
# ============================================
# Arguments:
#   $1 - Thunder host (e.g., "example.com")
#   $2 - Thunder port (e.g., "8090")
# Returns:
#   0 on success, 1 on failure
# Exports:
#   SAMPLE_APP_ID - The application ID extracted from logs
#   BEARER_TOKEN - The authentication token
# ============================================
thunder_authenticate() {
    local thunder_host="$1"
    local thunder_port="$2"

    if [ -z "$thunder_host" ] || [ -z "$thunder_port" ]; then
        echo -e "${RED}✗ Thunder host and port are required${NC}" >&2
        return 1
    fi

    echo -e "${YELLOW}Authenticating with Thunder...${NC}"

    # Step 1: Extract Sample App ID
    echo "  - Extracting Sample App ID from Thunder setup logs..."
    SAMPLE_APP_ID=$(thunder_get_sample_app_id)

    if [ $? -ne 0 ] || [ -z "$SAMPLE_APP_ID" ]; then
        return 1
    fi

    echo -e "${GREEN}  ✓ Sample App ID extracted: $SAMPLE_APP_ID${NC}"

    # Step 2: Execute authentication flow
    echo "  - Authenticating with Thunder API..."
    local auth_response
    auth_response=$(curl -s -w "\n%{http_code}" -X POST \
        "https://${thunder_host}:${thunder_port}/flow/execute" \
        -H "Content-Type: application/json" \
        -d "{\"applicationId\":\"${SAMPLE_APP_ID}\",\"flowType\":\"AUTHENTICATION\",\"inputs\":{\"username\":\"admin\",\"password\":\"admin\",\"requested_permissions\":\"system\"}}")

    local auth_body
    local auth_status
    auth_body=$(echo "$auth_response" | head -n -1)
    auth_status=$(echo "$auth_response" | tail -n1)

    if [ "$auth_status" -ne 200 ]; then
        echo -e "${RED}✗ Failed to authenticate with Thunder (HTTP $auth_status)${NC}" >&2
        echo "Response: $auth_body" >&2
        return 1
    fi

    # Step 3: Extract Bearer token (assertion)
    BEARER_TOKEN=$(echo "$auth_body" | grep -o '"assertion":"[^"]*' | sed 's/"assertion":"//')

    if [ -z "$BEARER_TOKEN" ]; then
        echo -e "${RED}✗ Failed to extract assertion from authentication response${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}  ✓ Authentication successful${NC}"

    # Export variables for use in calling script
    export SAMPLE_APP_ID
    export BEARER_TOKEN

    return 0
}

# ============================================
# Function: Get organization unit ID by handle
# ============================================
# Arguments:
#   $1 - Thunder host (e.g., "example.com")
#   $2 - Thunder port (e.g., "8090")
#   $3 - Bearer token
#   $4 - Organization handle (e.g., "silver")
# Returns:
#   0 on success, 1 on failure
# Exports:
#   ORG_UNIT_ID - The organization unit ID
# ============================================
thunder_get_org_unit() {
    local thunder_host="$1"
    local thunder_port="$2"
    local bearer_token="$3"
    local org_handle="$4"

    if [ -z "$thunder_host" ] || [ -z "$thunder_port" ] || [ -z "$bearer_token" ] || [ -z "$org_handle" ]; then
        echo -e "${RED}✗ All parameters (host, port, token, handle) are required${NC}" >&2
        return 1
    fi

    echo -e "${YELLOW}Fetching organization unit '${org_handle}'...${NC}"

    local ou_response
    ou_response=$(curl -s -w "\n%{http_code}" -X GET \
        "https://${thunder_host}:${thunder_port}/organization-units" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${bearer_token}")

    local ou_body
    local ou_status
    ou_body=$(echo "$ou_response" | head -n -1)
    ou_status=$(echo "$ou_response" | tail -n1)

    if [ "$ou_status" -ne 200 ]; then
        echo -e "${RED}✗ Failed to fetch organization units (HTTP $ou_status)${NC}" >&2
        echo "Response: $ou_body" >&2
        return 1
    fi

    # Extract organization unit ID for the specified handle
    ORG_UNIT_ID=$(echo "$ou_body" | grep -o "{[^}]*\"handle\":\"${org_handle}\"[^}]*}" | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"//')

    if [ -z "$ORG_UNIT_ID" ]; then
        echo -e "${RED}✗ Failed to find '${org_handle}' organization unit${NC}" >&2
        echo "Available organizations in response:" >&2
        echo "$ou_body" | grep -o '"handle":"[^"]*"' | sed 's/"handle":"//;s/"//g' | sed 's/^/  - /' >&2
        return 1
    fi

    echo -e "${GREEN}✓ Organization unit '${org_handle}' found (ID: $ORG_UNIT_ID)${NC}"

    # Export variable for use in calling script
    export ORG_UNIT_ID

    return 0
}

# ============================================
# Function: Create organization unit
# ============================================
# Arguments:
#   $1 - Thunder host
#   $2 - Thunder port
#   $3 - Bearer token
#   $4 - Organization handle
#   $5 - Organization name
#   $6 - Organization description
# Returns:
#   0 on success, 1 on failure
# Exports:
#   ORG_UNIT_ID - The created organization unit ID
# ============================================
thunder_create_org_unit() {
    local thunder_host="$1"
    local thunder_port="$2"
    local bearer_token="$3"
    local org_handle="$4"
    local org_name="$5"
    local org_description="$6"

    if [ -z "$thunder_host" ] || [ -z "$thunder_port" ] || [ -z "$bearer_token" ] || [ -z "$org_handle" ] || [ -z "$org_name" ]; then
        echo -e "${RED}✗ Required parameters missing (host, port, token, handle, name)${NC}" >&2
        return 1
    fi

    echo "  - Creating organization unit..."

    local ou_response
    ou_response=$(curl -s -w "\n%{http_code}" -X POST \
        "https://${thunder_host}:${thunder_port}/organization-units" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${bearer_token}" \
        -d "{
            \"handle\": \"${org_handle}\",
            \"name\": \"${org_name}\",
            \"description\": \"${org_description}\",
            \"parent\": null
        }")

    local ou_body
    local ou_status
    ou_body=$(echo "$ou_response" | head -n -1)
    ou_status=$(echo "$ou_response" | tail -n1)

    if [ "$ou_status" -ne 201 ] && [ "$ou_status" -ne 200 ]; then
        echo -e "${RED}✗ Failed to create organization unit (HTTP $ou_status)${NC}" >&2
        echo "Response: $ou_body" >&2
        return 1
    fi

    # Extract organization unit ID
    ORG_UNIT_ID=$(echo "$ou_body" | grep -o '"id":"[^"]*"' | head -n1 | sed 's/"id":"//;s/"//')

    if [ -z "$ORG_UNIT_ID" ]; then
        echo -e "${RED}✗ Failed to extract organization unit ID from response${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}  ✓ Organization unit created successfully (ID: $ORG_UNIT_ID)${NC}"

    # Export variable for use in calling script
    export ORG_UNIT_ID

    return 0
}
