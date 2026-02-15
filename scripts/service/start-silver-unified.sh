#!/bin/bash

# ============================================
#  Silver Mail Setup Wizard (Unified)
# ============================================
#
# This script supports pluggable Identity Providers through
# the Strategy pattern with Factory.
#
# The Identity Provider is selected from silver.yaml configuration.

# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Services directory contains docker-compose.yaml
SERVICES_DIR="$(cd "${SCRIPT_DIR}/../../services" && pwd)"
# Conf directory contains config files
CONF_DIR="$(cd "${SCRIPT_DIR}/../../conf" && pwd)"
CONFIG_FILE="${CONF_DIR}/silver.yaml"
# IdP directory
IDP_DIR="$(cd "${SCRIPT_DIR}/../idp" && pwd)"

# ================================
# Helper: Get IdP Port from Config
# ================================
get_idp_port_from_config() {
    local config_file="$1"
    local provider_name="$2"
    
    # Extract port from YAML based on provider
    case "$provider_name" in
        thunder)
            echo "8090"
            ;;
        keycloak)
            echo "8080"
            ;;
        *)
            echo "8080"  # Default
            ;;
    esac
}

# ASCII Banner
echo -e "${CYAN}"
cat <<'EOF'
                                                                                                
                                                                                                
   SSSSSSSSSSSSSSS   iiii  lllllll                                                              
 SS:::::::::::::::S i::::i l:::::l                                                              
S:::::SSSSSS::::::S  iiii  l:::::l                                                              
S:::::S     SSSSSSS        l:::::l                                                              
S:::::S            iiiiiii  l::::lvvvvvvv           vvvvvvv eeeeeeeeeeee    rrrrr   rrrrrrrrr   
S:::::S            i::::i  l::::l v:::::v         v:::::vee::::::::::::ee  r::::rrr:::::::::r  
 S::::SSSS          i::::i  l::::l  v:::::v       v:::::ve::::::eeeee:::::eer:::::::::::::::::r 
  SS::::::SSSSS     i::::i  l::::l   v:::::v     v:::::ve::::::e     e:::::err::::::rrrrr::::::r
    SSS::::::::SS   i::::i  l::::l    v:::::v   v:::::v e:::::::eeeee::::::e r:::::r     r:::::r
       SSSSSS::::S  i::::i  l::::l     v:::::v v:::::v  e:::::::::::::::::e  r:::::r     rrrrrrr
            S:::::S i::::i  l::::l      v:::::v:::::v   e::::::eeeeeeeeeee   r:::::r            
            S:::::S i::::i  l::::l       v:::::::::v    e:::::::e            r:::::r            
SSSSSSS     S:::::Si::::::il::::::l       v:::::::v     e::::::::e           r:::::r            
S::::::SSSSSS:::::Si::::::il::::::l        v:::::v       e::::::::eeeeeeee   r:::::r            
S:::::::::::::::SS i::::::il::::::l         v:::v         ee:::::::::::::e   r:::::r            
 SSSSSSSSSSSSSSS   iiiiiiiillllllll          vvv            eeeeeeeeeeeeee   rrrrrrr            
                                                                                                 
EOF
echo -e "${NC}"

echo ""
echo -e " 🚀 ${GREEN}Welcome to Silver Mail System Setup${NC}"
echo "---------------------------------------------"

MAIL_DOMAIN=""

# ================================
# Step 1: Domain Configuration
# ================================
echo -e "\n${YELLOW}Step 1/5: Configure domain name${NC}"

# Extract primary (first) domain from the domains list in silver.yaml
MAIL_DOMAIN=$(grep -m 1 '^\s*-\s*domain:' "$CONFIG_FILE" | sed 's/.*domain:\s*//' | xargs)

# Validate if MAIL_DOMAIN is empty
if [ -z "$MAIL_DOMAIN" ]; then
    echo -e "${RED}Error: Domain name is not configured or is empty. Please set it in '$CONFIG_FILE'.${NC}"
    exit 1
else
    echo "Domain name found: $MAIL_DOMAIN"
fi

if ! [[ "$MAIL_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}✗ Warning: '${MAIL_DOMAIN}' does not look like a valid domain name.${NC}"
    exit 1
fi

# ================================
# Step 2: Load Identity Provider
# ================================
echo -e "\n${YELLOW}Step 2/5: Loading Identity Provider${NC}"

# Source the IdP factory
source "${IDP_DIR}/idp-factory.sh"

# Get provider from config
IDP_PROVIDER_NAME=$(get_provider_from_config "$CONFIG_FILE")

if [ -z "$IDP_PROVIDER_NAME" ]; then
    echo -e "${RED}✗ Failed to determine Identity Provider from configuration${NC}"
    exit 1
fi

echo "Identity Provider: $IDP_PROVIDER_NAME"

# Create the provider instance
if ! create_idp_provider "$IDP_PROVIDER_NAME"; then
    echo -e "${RED}✗ Failed to load Identity Provider: $IDP_PROVIDER_NAME${NC}"
    exit 1
fi

# ================================
# Step 3: Update /etc/hosts
# ================================
echo -e "\n${YELLOW}Step 3/5: Updating ${MAIL_DOMAIN} mapping in /etc/hosts${NC}"

if grep -q "[[:space:]]${MAIL_DOMAIN}" /etc/hosts; then
    # Replace existing entry
    sudo sed -i "/^[^#]*[[:space:]]${MAIL_DOMAIN}\([[:space:]]\|$\)/s/^.*[[:space:]]${MAIL_DOMAIN}\([[:space:]]\|$\).*/127.0.0.1   ${MAIL_DOMAIN}/" /etc/hosts
    echo -e "${GREEN}✓ Updated existing ${MAIL_DOMAIN} entry to 127.0.0.1${NC}"
else
    # Add new if not present
    echo "127.0.0.1   ${MAIL_DOMAIN}" | sudo tee -a /etc/hosts >/dev/null
    echo -e "${GREEN}✓ Added ${MAIL_DOMAIN} entry to /etc/hosts${NC}"
fi

# ================================
# Step 4: Docker Setup
# ================================
echo -e "\n${YELLOW}Step 4/5: Starting Docker services${NC}"

# Check and setup SeaweedFS S3 configuration
SEAWEEDFS_CONFIG="${SERVICES_DIR}/seaweedfs/s3-config.json"
SEAWEEDFS_EXAMPLE="${SERVICES_DIR}/seaweedfs/s3-config.json.example"

if [ ! -f "$SEAWEEDFS_CONFIG" ]; then
    echo "  - SeaweedFS S3 configuration not found. Creating from example..."
    if [ -f "$SEAWEEDFS_EXAMPLE" ]; then
        cp "$SEAWEEDFS_EXAMPLE" "$SEAWEEDFS_CONFIG"
        echo -e "${YELLOW}  ⚠ WARNING: Using example S3 credentials. Update ${SEAWEEDFS_CONFIG} with secure credentials!${NC}"
    else
        echo -e "${RED}✗ SeaweedFS example configuration not found at ${SEAWEEDFS_EXAMPLE}${NC}"
        exit 1
    fi
fi

# Start SeaweedFS services first
echo "  - Starting SeaweedFS blob storage..."
(cd "${SERVICES_DIR}" && docker compose -f docker-compose.seaweedfs.yaml up -d)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ SeaweedFS docker compose failed. Please check the logs.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ SeaweedFS services started${NC}"

# Start Identity Provider using the loaded provider
if ! $IDP_INITIALIZE "$MAIL_DOMAIN"; then
    echo -e "${RED}✗ Failed to initialize Identity Provider${NC}"
    exit 1
fi

# Wait for Identity Provider to be ready
IDP_HOST="$MAIL_DOMAIN"
IDP_PORT=$(get_idp_port_from_config "$CONFIG_FILE" "$IDP_PROVIDER_NAME")

if ! $IDP_WAIT_FOR_READY "$IDP_HOST" "$IDP_PORT"; then
    echo -e "${RED}✗ Identity Provider failed to become ready${NC}"
    exit 1
fi

# Start main Silver mail services
echo "  - Starting Silver mail services..."
(cd "${SERVICES_DIR}" && docker compose up -d)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Docker compose failed. Please check the logs.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Silver mail services started${NC}"

sleep 1 # Wait a bit for services to initialize

# ================================
# Step 5: Configure Identity Provider
# ================================
echo -e "\n${YELLOW}Step 5/5: Configuring Identity Provider${NC}"

if ! $IDP_CONFIGURE "$MAIL_DOMAIN"; then
    echo -e "${RED}✗ Failed to configure Identity Provider${NC}"
    exit 1
fi

# ================================
# Public DKIM Key Instructions
# ================================
chmod +x "${SCRIPT_DIR}/../utils/get-dkim.sh"
(cd "${SCRIPT_DIR}/../utils" && ./get-dkim.sh)

# ================================
# Generate RSPAMD worker-controller.inc
# ================================
chmod +x "${SCRIPT_DIR}/../utils/generate-rspamd-worker-controller.sh"
(cd "${SCRIPT_DIR}/../utils" && ./generate-rspamd-worker-controller.sh)

# ================================
# Final Success Message
# ================================
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Silver Mail System is now running!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Configuration:${NC}"
echo -e "  Domain:             ${MAIL_DOMAIN}"
echo -e "  Identity Provider:  ${IDP_PROVIDER_NAME}"
echo ""
echo -e "Next steps:"
echo -e "  1. Access your IdP admin console to manage users"
echo -e "  2. Configure your mail client to connect to ${MAIL_DOMAIN}"
echo -e "  3. Create email users through IdP admin interface"
echo -e "  4. Check service logs: ${YELLOW}docker compose logs -f${NC}"
echo ""
echo -e "${CYAN}For more information, check the documentation.${NC}"
echo ""