#!/bin/bash


# ============================================
#  Identity Provider Factory
# ============================================
#
# This factory creates and returns the appropriate Identity Provider
# based on the configuration in silver.yaml
#
# Usage:
#   source "$(dirname "$0")/../idp/idp-factory.sh"
#   create_idp_provider "thunder"
#   # Now you can call: thunder_initialize, thunder_wait_for_ready, etc.


# Get the directory where this script is located
IDP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS_DIR="${IDP_DIR}/providers"


# Source the interface
source "${IDP_DIR}/idp-interface.sh"


# ============================================
# Function: Create IdP Provider
# ============================================
# Creates and initializes the specified Identity Provider
#
# Arguments:
#   $1 - Provider name (thunder, keycloak, etc.)
#
# Returns:
#   0 on success, 1 on failure
#
# Exports:
#   IDP_PROVIDER - The name of the loaded provider
#   IDP_INITIALIZE - Function name for initialize
#   IDP_WAIT_FOR_READY - Function name for wait_for_ready
#   IDP_CONFIGURE - Function name for configure
#   IDP_GET_COMPOSE_FILE - Function name for get_compose_file
#   IDP_CLEANUP - Function name for cleanup
# ============================================
create_idp_provider() {
    local provider_name="$1"


    if [ -z "$provider_name" ]; then
        echo -e "${RED}✗ Provider name is required${NC}" >&2
        return 1
    fi


    # Convert to lowercase
    provider_name=$(echo "$provider_name" | tr '[:upper:]' '[:lower:]')


    echo -e "${CYAN}Loading Identity Provider: ${provider_name}${NC}"


    # Load the appropriate provider implementation
    case "$provider_name" in
        thunder)
            if [ ! -f "${PROVIDERS_DIR}/thunder-idp.sh" ]; then
                echo -e "${RED}✗ Thunder provider not found at ${PROVIDERS_DIR}/thunder-idp.sh${NC}" >&2
                return 1
            fi
            source "${PROVIDERS_DIR}/thunder-idp.sh"
            ;;
        keycloak)
            if [ ! -f "${PROVIDERS_DIR}/keycloak-idp.sh" ]; then
                echo -e "${RED}✗ Keycloak provider not found at ${PROVIDERS_DIR}/keycloak-idp.sh${NC}" >&2
                return 1
            fi
            source "${PROVIDERS_DIR}/keycloak-idp.sh"
            ;;
        *)
            echo -e "${RED}✗ Unknown identity provider: ${provider_name}${NC}" >&2
            echo -e "${YELLOW}Supported providers: thunder, keycloak${NC}" >&2
            return 1
            ;;
    esac


    # Validate that the provider implements all required functions
    if ! validate_provider_implementation "$provider_name"; then
        echo -e "${RED}✗ Provider '${provider_name}' does not implement the required interface${NC}" >&2
        return 1
    fi


    # Export provider information
    export IDP_PROVIDER="$provider_name"
    export IDP_INITIALIZE="${provider_name}_initialize"
    export IDP_WAIT_FOR_READY="${provider_name}_wait_for_ready"
    export IDP_CONFIGURE="${provider_name}_configure"
    export IDP_GET_COMPOSE_FILE="${provider_name}_get_compose_file"
    export IDP_CLEANUP="${provider_name}_cleanup"


    echo -e "${GREEN}✓ Identity Provider '${provider_name}' loaded successfully${NC}"
    return 0
}


# ============================================
# Function: Get Provider from Config
# ============================================
# Reads the provider name from silver.yaml
#
# Arguments:
#   $1 - Path to silver.yaml config file
#
# Returns:
#   Provider name (stdout), empty if not found
# ============================================
get_provider_from_config() {
    local config_file="$1"


    if [ ! -f "$config_file" ]; then
        echo -e "${RED}✗ Configuration file not found: ${config_file}${NC}" >&2
        return 1
    fi


    # Extract provider from YAML (simple grep-based parsing)
    # Looking for: identity:
    #                provider: thunder
    local provider=$(grep -A 1 '^identity:' "$config_file" | grep 'provider:' | sed 's/.*provider:\s*//' | xargs)


    if [ -z "$provider" ]; then
        echo -e "${YELLOW}⚠ No identity provider configured in ${config_file}${NC}" >&2
        echo -e "${YELLOW}  Defaulting to 'thunder'${NC}" >&2
        echo "thunder"
    else
        echo "$provider"
    fi
}


# Export functions
export -f create_idp_provider
export -f get_provider_from_config