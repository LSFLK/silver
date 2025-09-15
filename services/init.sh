#!/bin/bash

# ============================================
#  Silver Mail Setup Wizard
# ============================================

# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Get the script directory (where init.sh is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="silver.yaml"

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
echo -e "\n${YELLOW}Step 1/7: Configure domain name${NC}"

MAIL_DOMAIN=$(grep -m 1 '^domain:' "$CONFIG_FILE" | sed 's/domain: //' | xargs)

# Validate if MAIL_DOMAIN is empty
if [ -z "$MAIL_DOMAIN" ]; then
    echo -e "${RED}Error: Domain name is not configured or is empty. Please set it in '$CONFIG_FILE'.${NC}"
    exit 1 # Exit the script with a failure status
else
    echo "Domain name found: $MAIL_DOMAIN"
    # ...continue with the rest of your script...
fi

if ! [[ "$MAIL_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}✗ Warning: '${MAIL_DOMAIN}' does not look like a valid domain name.${NC}"
    exit 1
fi

# ================================
# Step 2: Generate & Verify Certificates (via certbot container)
# ================================
echo -e "\n${YELLOW}Step 2/7: Generating TLS certificates using certbot container${NC}"

# Start only certbot container first
( cd "${SCRIPT_DIR}" && docker compose up certbot-server --build --force-recreate )

LETSENCRYPT_DIR="./letsencrypt/live/${MAIL_DOMAIN}/"

# Wait until certbot finishes and files exist
echo -n "⏳ Waiting for certificates..."
RETRIES=20
while [ $RETRIES -gt 0 ]; do
    if [ -f "${LETSENCRYPT_DIR}/fullchain.pem" ] && [ -f "${LETSENCRYPT_DIR}/privkey.pem" ]; then
        echo -e " ${GREEN}done${NC}"
        break
    fi
    echo -n "."
    sleep 5
    RETRIES=$((RETRIES-1))
done

if [ ! -f "${LETSENCRYPT_DIR}/fullchain.pem" ] || [ ! -f "${LETSENCRYPT_DIR}/privkey.pem" ]; then
    echo -e "${RED}✗ Certificate generation failed. Required files not found:${NC}"
    echo " - ${LETSENCRYPT_DIR}/fullchain.pem"
    echo " - ${LETSENCRYPT_DIR}/privkey.pem"
    exit 1
fi

echo -e "${GREEN}✓ Certificates ready for ${MAIL_DOMAIN}${NC}"
echo " - ${LETSENCRYPT_DIR}/fullchain.pem"
echo " - ${LETSENCRYPT_DIR}/privkey.pem"

# ================================
# Step 3: SMTP Configuration
# ================================
echo -e "\n${YELLOW}Step 3/7: Creating SMTP configuration${NC}"

TARGET_DIR="${SCRIPT_DIR}/smtp/conf"
if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory '$TARGET_DIR' does not exist. Creating it now..."
    mkdir -p "$TARGET_DIR"
fi

# Create required files
echo "${MAIL_DOMAIN} OK" > "$TARGET_DIR/virtual-domains"
: > "$TARGET_DIR/virtual-aliases"
: > "$TARGET_DIR/virtual-users"

echo -e "${GREEN}✓ SMTP configuration files prepared${NC}"
echo " - $TARGET_DIR/virtual-domains (with '${MAIL_DOMAIN} OK')"
echo " - $TARGET_DIR/virtual-aliases (empty)"
echo " - $TARGET_DIR/virtual-users (empty)"

# ================================
# Step 4: Spam Filter Configuration
# ================================
echo -e "\n${YELLOW}Step 4/7: Configuring Spam Filter${NC}"

if [ ! -d "${SCRIPT_DIR}/spam/conf" ]; then
    mkdir -p "${SCRIPT_DIR}/spam/conf"
fi
echo "password = \"\$2\$8hn4c88rmafsueo4h3yckiirwkieidb3\$uge4i3ynbba89qpo1gqmqk9gqjy8ysu676z1p8ss5qz5y1773zgb\";" > "${SCRIPT_DIR}/spam/conf/worker-controller.inc"
echo -e "${GREEN}✓ worker-controller.inc created for spam filter${NC}"

# ================================
# Step 5: Thunder TLS Configuration
# ================================
echo -e "\n${YELLOW}Step 5/7: Configuring Thunder TLS certificates${NC}"

THUNDER_HOST=${MAIL_DOMAIN}
THUNDER_PORT=8090

LETSENCRYPT_DIR="./letsencrypt/live/${MAIL_DOMAIN}/"

mkdir -p "./thunder/certs"

cp "${LETSENCRYPT_DIR}/fullchain.pem" "./thunder/certs/server.cert"
cp "${LETSENCRYPT_DIR}/privkey.pem" "./thunder/certs/server.key"

# Set ownership to user ID 802 (thunder user in container)
sudo chown 802:802 ./thunder/certs/server.key ./thunder/certs/server.cert

chmod 600 ./thunder/certs/server.key
chmod 644 ./thunder/certs/server.cert

# ================================
# Step 6: Docker Setup
# ================================
echo -e "\n${YELLOW}Step 6/7: Starting Docker services${NC}"

( cd "${SCRIPT_DIR}" && docker compose up -d --build --force-recreate )
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Docker compose failed. Please check the logs.${NC}"
    exit 1
fi

echo -n "⏳ Waiting for services to become healthy"
while [ "$(cd "${SCRIPT_DIR}" && docker compose ps --services --filter "status=running" | wc -l)" -lt "$(cd "${SCRIPT_DIR}" && docker compose ps --services | wc -l)" ]; do
    echo -n "."
    sleep 5
done
echo -e " ${GREEN}done${NC}"

# ================================
# Step 7: Initialize Thunder User Schema
# ================================


echo -e "\n${YELLOW}Step 7/7: Creating default user schema in Thunder${NC}"

SCHEMA_RESPONSE=$(curl -w  "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  https://${THUNDER_HOST}:${THUNDER_PORT}/user-schemas \
  -d "{
    \"name\": \"emailuser\",
    \"schema\": {
      \"username\": { \"type\": \"string\", \"unique\": true },
      \"password\": { \"type\": \"string\" },
      \"email\": { \"type\": \"string\", \"unique\": true }
    }
  }")

SCHEMA_BODY=$(echo "$SCHEMA_RESPONSE" | head -n -1)
SCHEMA_STATUS=$(echo "$SCHEMA_RESPONSE" | tail -n1)

if [ "$SCHEMA_STATUS" -eq 201 ] || [ "$SCHEMA_STATUS" -eq 200 ]; then
    echo -e "${GREEN}✓ User schema 'emailuser' created successfully (HTTP $SCHEMA_STATUS)${NC}"
else
    echo -e "${RED}✗ Failed to create user schema (HTTP $SCHEMA_STATUS)${NC}"
    echo "Response: $SCHEMA_BODY"
    exit 1
fi

# ================================
# Public DKIM Key Instructions
# ================================
chmod +x "${SCRIPT_DIR}/get-dkim.sh"
( cd "${SCRIPT_DIR}" && ./get-dkim.sh )