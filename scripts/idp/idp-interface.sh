#!/bin/bash

# ============================================
#  Identity Provider Interface Contract
# ============================================
#
# This file defines the interface that all Identity Provider
# implementations must follow. It serves as a contract for the
# Strategy pattern.
#
# Each IdP provider must implement these functions:
# - <provider>_initialize()
# - <provider>_wait_for_ready()
# - <provider>_configure()
# - <provider>_get_compose_file()
# - <provider>_cleanup()
#
# Where <provider> is the name of the provider (e.g., thunder, keycloak)

# Colors for output
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# ============================================
# Interface: initialize
# ============================================
# Starts the Identity Provider service
#
# Arguments:
#   $1 - Mail domain
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   thunder_initialize "example.com"
#   keycloak_initialize "example.com"
# ============================================

# ============================================
# Interface: wait_for_ready
# ============================================
# Waits for the Identity Provider to be healthy and ready
#
# Arguments:
#   $1 - IdP host
#   $2 - IdP port
#
# Returns:
#   0 on success, 1 on timeout/failure
#
# Example:
#   thunder_wait_for_ready "example.com" "8090"
#   keycloak_wait_for_ready "example.com" "8080"
# ============================================

# ============================================
# Interface: configure
# ============================================
# Configures the Identity Provider with necessary settings
# This includes creating realms, clients, schemas, etc.
#
# Arguments:
#   $1 - Mail domain
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   thunder_configure "example.com"
#   keycloak_configure "example.com"
# ============================================

# ============================================
# Interface: get_compose_file
# ============================================
# Returns the path to the docker-compose file for this provider
#
# Arguments:
#   None
#
# Returns:
#   Path to docker-compose file (stdout)
#
# Example:
#   compose_file=$(thunder_get_compose_file)
#   compose_file=$(keycloak_get_compose_file)
# ============================================

# ============================================
# Interface: cleanup
# ============================================
# Cleans up and stops the Identity Provider service
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   thunder_cleanup
#   keycloak_cleanup
# ============================================

# ============================================
# Helper: Validate Provider Implementation
# ============================================
# Validates that a provider implements all required functions
#
# Arguments:
#   $1 - Provider name (e.g., "thunder", "keycloak")
#
# Returns:
#   0 if valid, 1 if missing functions
# ============================================
validate_provider_implementation() {
    local provider_name="$1"

    if [ -z "$provider_name" ]; then
        echo -e "${RED}✗ Provider name is required for validation${NC}" >&2
        return 1
    fi

    local required_functions=(
        "${provider_name}_initialize"
        "${provider_name}_wait_for_ready"
        "${provider_name}_configure"
        "${provider_name}_get_compose_file"
        "${provider_name}_cleanup"
    )

    local missing_functions=()

    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" > /dev/null 2>&1; then
            missing_functions+=("$func")
        fi
    done

    if [ ${#missing_functions[@]} -gt 0 ]; then
        echo -e "${RED}✗ Provider '${provider_name}' is missing required functions:${NC}" >&2
        for func in "${missing_functions[@]}"; do
            echo -e "${RED}  - ${func}${NC}" >&2
        done
        return 1
    fi

    echo -e "${GREEN}✓ Provider '${provider_name}' implements all required functions${NC}"
    return 0
}

# Export validation function
export -f validate_provider_implementation
