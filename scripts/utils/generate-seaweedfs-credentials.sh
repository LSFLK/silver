#!/bin/bash

# ============================================
#  SeaweedFS S3 Credentials Generator
# ============================================
#  This script generates secure S3 credentials
#  for SeaweedFS configuration
# ============================================

# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

echo -e "${CYAN}"
echo "========================================="
echo "  SeaweedFS S3 Credentials Generator"
echo "========================================="
echo -e "${NC}"

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    echo -e "${YELLOW}⚠ Warning: openssl not found. Using basic random generation.${NC}"
    ACCESS_KEY=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)
    SECRET_KEY=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 40)
else
    # Generate secure random credentials
    ACCESS_KEY=$(openssl rand -base64 32 | tr -d /=+ | cut -c -20)
    SECRET_KEY=$(openssl rand -base64 32)
fi

echo ""
echo -e "${GREEN}Generated Credentials:${NC}"
echo "---------------------------------------------"
echo "Access Key: ${ACCESS_KEY}"
echo "Secret Key: ${SECRET_KEY}"
echo "---------------------------------------------"
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$(cd "${SCRIPT_DIR}/../../services" && pwd)"
CONFIG_FILE="${SERVICES_DIR}/seaweedfs/s3-config.json"
EXAMPLE_FILE="${SERVICES_DIR}/seaweedfs/s3-config.json.example"
ENV_FILE="${SERVICES_DIR}/seaweedfs/.env"
ENV_EXAMPLE="${SERVICES_DIR}/seaweedfs/.env.example"

echo "S3 Config file: ${CONFIG_FILE}"
echo "Environment file: ${ENV_FILE}"
echo ""

# Ask if user wants to update the config files
read -p "Do you want to update configuration files with these credentials? (y/n): " UPDATE_CONFIG

if [[ "$UPDATE_CONFIG" == "y" || "$UPDATE_CONFIG" == "Y" ]]; then
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Create s3-config.json
    cat > "$CONFIG_FILE" <<EOF
{
  "identities": [
    {
      "name": "raven",
      "credentials": [
        {
          "accessKey": "${ACCESS_KEY}",
          "secretKey": "${SECRET_KEY}"
        }
      ],
      "actions": [
        "Admin",
        "Read",
        "Write"
      ]
    }
  ]
}
EOF
    
    echo -e "${GREEN}✓ s3-config.json updated successfully!${NC}"
    
    # Create .env file
    cat > "$ENV_FILE" <<EOF
# SeaweedFS S3 Configuration
# NEVER commit this file to git!

# S3 Access Credentials
S3_ACCESS_KEY=${ACCESS_KEY}
S3_SECRET_KEY=${SECRET_KEY}

# S3 Endpoint Configuration
S3_ENDPOINT=http://seaweedfs-s3:8333
S3_REGION=us-east-1
S3_BUCKET=email-attachments
S3_TIMEOUT=30
EOF
    
    echo -e "${GREEN}✓ .env file created successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Configuration files updated:"
    echo "   - ${CONFIG_FILE}"
    echo "   - ${ENV_FILE}"
    echo "2. Restart SeaweedFS S3 service: docker restart seaweedfs-s3"
    echo "3. Regenerate Raven configuration: cd services/config-scripts && ./gen-raven-conf.sh"
    echo "4. Restart Raven service: docker restart raven"
    echo "5. Store these credentials securely (e.g., password manager)"
    echo ""
    echo -e "${YELLOW}⚠ IMPORTANT: Both files are in .gitignore - never commit them to git!${NC}"
else
    echo "Configuration files not updated."
    echo ""
    echo "You can manually update:"
    echo "1. ${CONFIG_FILE}"
    echo "2. ${ENV_FILE}"
    echo ""
    echo "Or copy from examples:"
    echo "  cp ${ENV_EXAMPLE} ${ENV_FILE}"
    echo "  # Then edit with your credentials"
fi

echo ""
echo -e "${CYAN}Done!${NC}"
