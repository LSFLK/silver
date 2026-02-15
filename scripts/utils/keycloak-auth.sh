#!/bin/bash

# ============================================
#  Keycloak Authentication Utility
# ============================================
#
# This utility provides shared authentication functions for Keycloak API.
# Source this file in your scripts to use the authentication functions.
#
# Usage:
#   source "$(dirname "$0")/../utils/keycloak-auth.sh"
#   keycloak_authenticate "$KEYCLOAK_HOST" "$KEYCLOAK_PORT" "$KEYCLOAK_REALM"
#   # Now you can use: $KEYCLOAK_ACCESS_TOKEN
#
#   keycloak_create_client "$KEYCLOAK_HOST" "$KEYCLOAK_PORT" "$KEYCLOAK_REALM" "$KEYCLOAK_ACCESS_TOKEN" "silver-mail"
#   # Now you can use: $CLIENT_ID
#

# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color


# ============================================
# Function: Authenticate with Keycloak and get access token
# ============================================
# Arguments:
#   $1 - Keycloak host (e.g., "example.com")
#   $2 - Keycloak port (e.g., "8080" or "8443")
#   $3 - Keycloak realm (e.g., "master")
#   $4 - Admin username (optional, defaults to "admin")
#   $5 - Admin password (optional, defaults to "admin")
# Environment Variables:
#   KEYCLOAK_USE_HTTPS - Set to "true" to use HTTPS (default: auto-detect based on port)
#   KEYCLOAK_INSECURE - Set to "true" to skip SSL verification (for self-signed certs)
# Returns:
#   0 on success, 1 on failure
# Exports:
#   KEYCLOAK_ACCESS_TOKEN - The authentication token
# ============================================
keycloak_authenticate() {
    local keycloak_host="$1"
    local keycloak_port="$2"
    local keycloak_realm="${3:-master}"
    local admin_username="${4:-admin}"
    local admin_password="${5:-admin}"

    if [ -z "$keycloak_host" ] || [ -z "$keycloak_port" ]; then
        echo -e "${RED}✗ Keycloak host and port are required${NC}" >&2
        return 1
    fi

    # Auto-detect HTTPS based on port or environment variable
    local protocol="http"
    local curl_opts=""

    if [ "$keycloak_port" = "8443" ] || [ "$keycloak_port" = "443" ] || [ "${KEYCLOAK_USE_HTTPS}" = "true" ]; then
        protocol="https"
        # Add insecure flag for self-signed certificates if requested
        if [ "${KEYCLOAK_INSECURE}" = "true" ]; then
            curl_opts="-k"
        fi
    fi

    echo -e "${YELLOW}Authenticating with Keycloak...${NC}"
    echo "  - Protocol: ${protocol}"
    echo "  - Requesting access token from Keycloak..."

    local auth_response
    auth_response=$(curl -s ${curl_opts} -w "\n%{http_code}" -X POST \
        "${protocol}://${keycloak_host}:${keycloak_port}/realms/${keycloak_realm}/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=${admin_username}" \
        -d "password=${admin_password}" \
        -d "grant_type=password")

    local auth_body
    local auth_status
    auth_body=$(echo "$auth_response" | head -n -1)
    auth_status=$(echo "$auth_response" | tail -n1)

    if [ "$auth_status" -ne 200 ]; then
        echo -e "${RED}✗ Failed to authenticate with Keycloak (HTTP $auth_status)${NC}" >&2
        echo "Response: $auth_body" >&2
        echo -e "${YELLOW}Note: Make sure Keycloak is running and accessible${NC}" >&2
        return 1
    fi

    # Extract access token
    KEYCLOAK_ACCESS_TOKEN=$(echo "$auth_body" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')

    if [ -z "$KEYCLOAK_ACCESS_TOKEN" ]; then
        echo -e "${RED}✗ Failed to extract access token from authentication response${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}  ✓ Authentication successful${NC}"

    # Export variables for use in calling script
    export KEYCLOAK_ACCESS_TOKEN
    export KEYCLOAK_PROTOCOL="${protocol}"
    export KEYCLOAK_CURL_OPTS="${curl_opts}"

    return 0
}

# ============================================
# Function: Create or get Keycloak realm
# ============================================
# Arguments:
#   $1 - Keycloak host
#   $2 - Keycloak port
#   $3 - Access token
#   $4 - Realm name
#   $5 - Realm display name
# Returns:
#   0 on success, 1 on failure
# Exports:
#   REALM_NAME - The realm name
# ============================================
keycloak_create_realm() {
    local keycloak_host="$1"
    local keycloak_port="$2"
    local access_token="$3"
    local realm_name="$4"
    local realm_display_name="${5:-$realm_name}"

    if [ -z "$keycloak_host" ] || [ -z "$keycloak_port" ] || [ -z "$access_token" ] || [ -z "$realm_name" ]; then
        echo -e "${RED}✗ Required parameters missing (host, port, token, realm name)${NC}" >&2
        return 1
    fi

    echo "  - Creating/checking realm '${realm_name}'..."

    # Use protocol and curl options from authentication
    local protocol="${KEYCLOAK_PROTOCOL:-http}"
    local curl_opts="${KEYCLOAK_CURL_OPTS:-}"

    # Check if realm exists
    local check_response
    check_response=$(curl -s -w ${curl_opts} "\n%{http_code}" ${curl_opts} -X GET \
        "${protocol}://${keycloak_host}:${keycloak_port}/admin/realms/${realm_name}" \
        -H "Authorization: Bearer ${access_token}")

    local check_status
    check_status=$(echo "$check_response" | tail -n1)

    if [ "$check_status" -eq 200 ]; then
        echo -e "${GREEN}  ✓ Realm '${realm_name}' already exists${NC}"
        export REALM_NAME="$realm_name"
        return 0
    fi

    # Create realm
    local realm_response
    realm_response=$(curl -s -w ${curl_opts} "\n%{http_code}" ${curl_opts} -X POST \
        "${protocol}://${keycloak_host}:${keycloak_port}/admin/realms" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${access_token}" \
        -d "{
            \"realm\": \"${realm_name}\",
            \"displayName\": \"${realm_display_name}\",
            \"enabled\": true,
            \"registrationAllowed\": false,
            \"loginWithEmailAllowed\": true,
            \"duplicateEmailsAllowed\": false
        }")

    local realm_body
    local realm_status
    realm_body=$(echo "$realm_response" | head -n -1)
    realm_status=$(echo "$realm_response" | tail -n1)

    if [ "$realm_status" -ne 201 ] && [ "$realm_status" -ne 204 ]; then
        echo -e "${RED}✗ Failed to create realm (HTTP $realm_status)${NC}" >&2
        echo "Response: $realm_body" >&2
        return 1
    fi

    echo -e "${GREEN}  ✓ Realm '${realm_name}' created successfully${NC}"

    export REALM_NAME="$realm_name"
    return 0
}

# ============================================
# Function: Create Keycloak client
# ============================================
# Arguments:
#   $1 - Keycloak host
#   $2 - Keycloak port
#   $3 - Realm name
#   $4 - Access token
#   $5 - Client ID
#   $6 - Client name
# Returns:
#   0 on success, 1 on failure
# Exports:
#   CLIENT_UUID - The created client's UUID
#   CLIENT_ID - The client ID
# ============================================
keycloak_create_client() {
    local keycloak_host="$1"
    local keycloak_port="$2"
    local realm_name="$3"
    local access_token="$4"
    local client_id="$5"
    local client_name="${6:-$client_id}"

    if [ -z "$keycloak_host" ] || [ -z "$keycloak_port" ] || [ -z "$realm_name" ] || [ -z "$access_token" ] || [ -z "$client_id" ]; then
        echo -e "${RED}✗ Required parameters missing (host, port, realm, token, client_id)${NC}" >&2
        return 1
    fi

    echo "  - Creating client '${client_id}'..."

    # Use protocol and curl options from authentication
    local protocol="${KEYCLOAK_PROTOCOL:-http}"
    local curl_opts="${KEYCLOAK_CURL_OPTS:-}"

    # Check if client already exists
    local check_response
    check_response=$(curl -s -w "\n%{http_code}" ${curl_opts} -X GET \
        "${protocol}://${keycloak_host}:${keycloak_port}/admin/realms/${realm_name}/clients?clientId=${client_id}" \
        -H "Authorization: Bearer ${access_token}")

    local check_body
    local check_status
    check_body=$(echo "$check_response" | head -n -1)
    check_status=$(echo "$check_response" | tail -n1)

    if [ "$check_status" -eq 200 ]; then
        # Check if client exists in response
        local existing_uuid
        existing_uuid=$(echo "$check_body" | grep -o '"id":"[^"]*"' | head -n1 | sed 's/"id":"//;s/"//')

        if [ -n "$existing_uuid" ]; then
            echo -e "${GREEN}  ✓ Client '${client_id}' already exists${NC}"
            export CLIENT_UUID="$existing_uuid"
            export CLIENT_ID="$client_id"
            return 0
        fi
    fi

    # Create client
    local client_response
    client_response=$(curl -s -w "\n%{http_code}" ${curl_opts} -X POST \
        "${protocol}://${keycloak_host}:${keycloak_port}/admin/realms/${realm_name}/clients" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${access_token}" \
        -d "{
            \"clientId\": \"${client_id}\",
            \"name\": \"${client_name}\",
            \"description\": \"Silver Mail Client\",
            \"enabled\": true,
            \"publicClient\": false,
            \"serviceAccountsEnabled\": true,
            \"directAccessGrantsEnabled\": true,
            \"standardFlowEnabled\": true,
            \"protocol\": \"openid-connect\"
        }")

    local client_body
    local client_status
    client_body=$(echo "$client_response" | head -n -1)
    client_status=$(echo "$client_response" | tail -n1)

    if [ "$client_status" -ne 201 ] && [ "$client_status" -ne 204 ]; then
        echo -e "${RED}✗ Failed to create client (HTTP $client_status)${NC}" >&2
        echo "Response: $client_body" >&2
        return 1
    fi

    # Get the created client UUID
    local get_client_response
    get_client_response=$(curl -s -w "\n%{http_code}" ${curl_opts} -X GET \
        "${protocol}://${keycloak_host}:${keycloak_port}/admin/realms/${realm_name}/clients?clientId=${client_id}" \
        -H "Authorization: Bearer ${access_token}")

    local get_client_body
    get_client_body=$(echo "$get_client_response" | head -n -1)

    CLIENT_UUID=$(echo "$get_client_body" | grep -o '"id":"[^"]*"' | head -n1 | sed 's/"id":"//;s/"//')

    if [ -z "$CLIENT_UUID" ]; then
        echo -e "${RED}✗ Failed to get client UUID${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}  ✓ Client '${client_id}' created successfully (UUID: $CLIENT_UUID)${NC}"

    export CLIENT_UUID
    export CLIENT_ID="$client_id"
    return 0
}

# ============================================
# Function: Create user in Keycloak realm
# ============================================
# Arguments:
#   $1 - Keycloak host
#   $2 - Keycloak port
#   $3 - Realm name
#   $4 - Access token
#   $5 - Username
#   $6 - Email
#   $7 - First name (optional)
#   $8 - Last name (optional)
# Returns:
#   0 on success, 1 on failure
# Exports:
#   USER_ID - The created user's ID
# ============================================
keycloak_create_user() {
    local keycloak_host="$1"
    local keycloak_port="$2"
    local realm_name="$3"
    local access_token="$4"
    local username="$5"
    local email="$6"
    local first_name="${7:-}"
    local last_name="${8:-}"

    if [ -z "$keycloak_host" ] || [ -z "$keycloak_port" ] || [ -z "$realm_name" ] || [ -z "$access_token" ] || [ -z "$username" ] || [ -z "$email" ]; then
        echo -e "${RED}✗ Required parameters missing (host, port, realm, token, username, email)${NC}" >&2
        return 1
    fi

    echo "  - Creating user '${username}'..."

    # Use protocol and curl options from authentication
    local protocol="${KEYCLOAK_PROTOCOL:-http}"
    local curl_opts="${KEYCLOAK_CURL_OPTS:-}"

    local user_response
    user_response=$(curl -s -w "\n%{http_code}" ${curl_opts} -X POST \
        "${protocol}://${keycloak_host}:${keycloak_port}/admin/realms/${realm_name}/users" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${access_token}" \
        -d "{
            \"username\": \"${username}\",
            \"email\": \"${email}\",
            \"firstName\": \"${first_name}\",
            \"lastName\": \"${last_name}\",
            \"enabled\": true,
            \"emailVerified\": true
        }")

    local user_body
    local user_status
    user_body=$(echo "$user_response" | head -n -1)
    user_status=$(echo "$user_response" | tail -n1)

    if [ "$user_status" -ne 201 ] && [ "$user_status" -ne 204 ]; then
        # Check if user already exists
        if echo "$user_body" | grep -q "User exists"; then
            echo -e "${YELLOW}  ⚠ User '${username}' already exists${NC}"
            return 0
        fi
        echo -e "${RED}✗ Failed to create user (HTTP $user_status)${NC}" >&2
        echo "Response: $user_body" >&2
        return 1
    fi

    echo -e "${GREEN}  ✓ User '${username}' created successfully${NC}"
    return 0
}
