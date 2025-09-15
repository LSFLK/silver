#!/bin/bash

# ============================================
#  Silver Mail - Add Users from users.yaml + Thunder Init
# ============================================

# -------------------------------
# Configuration
# -------------------------------
# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Directories & files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIRTUAL_USERS_FILE="${SCRIPT_DIR}/smtp/conf/virtual-users"
CONFIG_FILE="${SCRIPT_DIR}/silver.yaml"
USERS_FILE="${SCRIPT_DIR}/users.yaml"
PASSWORDS_DIR="${SCRIPT_DIR}/../scripts/decrypt"
PASSWORDS_FILE="${PASSWORDS_DIR}/user_passwords.txt"

# -------------------------------
# Prompt for encryption key
# -------------------------------
echo -e "${YELLOW}Enter encryption key for storing passwords:${NC}"
read -s ENCRYPT_KEY
echo ""
if [ -z "$ENCRYPT_KEY" ]; then
    echo -e "${RED}✗ Encryption key cannot be empty${NC}"
    exit 1
fi

echo -e "${CYAN}---------------------------------------------${NC}"
echo -e " 🚀 ${GREEN}Silver Mail - Bulk Add Users${NC}"
echo -e "${CYAN}---------------------------------------------${NC}\n"

# -------------------------------
# Helper Functions
# -------------------------------

# Generate a random strong password
generate_password() {
    # Use OpenSSL for cryptographically secure password generation
    openssl rand -base64 24 | tr -d '\n' | head -c 16
}

# Simple XOR encryption
encrypt_password() {
    local password="$1"
    local key="$ENCRYPT_KEY"
    local encrypted=""
    local i=0
    local key_len=${#key}
    
    while [ $i -lt ${#password} ]; do
        local char="${password:$i:1}"
        local key_char="${key:$((i % key_len)):1}"
        local char_code=$(printf '%d' "'$char")
        local key_code=$(printf '%d' "'$key_char")
        local xor_result=$((char_code ^ key_code))
        encrypted="${encrypted}$(printf '%02x' $xor_result)"
        i=$((i + 1))
    done
    
    echo "$encrypted"
}

# -------------------------------
# Step 0: Check maximum user limit
# -------------------------------
MAX_USERS=100
mkdir -p "$(dirname "$VIRTUAL_USERS_FILE")"
touch "$VIRTUAL_USERS_FILE"

CURRENT_USER_COUNT=$(grep -c "@" "$VIRTUAL_USERS_FILE")
echo -e "${CYAN}Current users: ${GREEN}$CURRENT_USER_COUNT${NC}. Maximum allowed: $MAX_USERS${NC}"

# -------------------------------
# Step 1: Read domain from YAML
# -------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗ Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

MAIL_DOMAIN=$(grep -m 1 '^domain:' "$CONFIG_FILE" | sed 's/domain: //' | xargs)

if [ -z "$MAIL_DOMAIN" ]; then
    echo -e "${RED}✗ Domain not defined in $CONFIG_FILE${NC}"
    exit 1
fi

if ! [[ "$MAIL_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}✗ Invalid domain: $MAIL_DOMAIN${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Domain name is valid: $MAIL_DOMAIN${NC}"

THUNDER_HOST=${MAIL_DOMAIN}
THUNDER_PORT="8090"
echo -e "${GREEN}✓ Thunder host set to: $THUNDER_HOST:$THUNDER_PORT${NC}"

# -------------------------------
# Step 2: Validate users.yaml
# -------------------------------
if [ ! -f "$USERS_FILE" ]; then
    echo -e "${RED}✗ Users file not found: $USERS_FILE${NC}"
    exit 1
fi

# Count how many users defined
YAML_USER_COUNT=$(grep -c "username:" "$USERS_FILE")
if [ "$YAML_USER_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ No users defined in $USERS_FILE${NC}"
    exit 1
fi

# Initialize passwords file
mkdir -p "$PASSWORDS_DIR"
echo "# Silver Mail User Passwords - Generated on $(date)" > "$PASSWORDS_FILE"
echo "# Passwords are encrypted. Use decrypt_password.sh to view them." >> "$PASSWORDS_FILE"
echo "" >> "$PASSWORDS_FILE"

# -------------------------------
# Step 3: Process each user
# -------------------------------
ADDED_COUNT=0
USER_USERNAME=""

while IFS= read -r line; do
    # Remove leading/trailing spaces but preserve structure for YAML parsing
    trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    # Parse username (handles both "- username:" and "username:" formats)
    if [[ $trimmed_line =~ ^-\ username:\ (.+)$ ]] || [[ $trimmed_line =~ ^username:\ (.+)$ ]]; then
        USER_USERNAME="${BASH_REMATCH[1]}"
        
        if [ -n "$USER_USERNAME" ]; then
            USER_EMAIL="${USER_USERNAME}@${MAIL_DOMAIN}"

            # --- max users check ---
            CURRENT_USER_COUNT=$(grep -c "@" "$VIRTUAL_USERS_FILE")
            if [ "$CURRENT_USER_COUNT" -ge "$MAX_USERS" ]; then
                echo -e "${RED}✗ Cannot add ${USER_USERNAME}: maximum user limit ($MAX_USERS) reached. Skipping.${NC}"
                USER_USERNAME=""
                continue
            fi

            # Generate random strong password
            USER_PASSWORD=$(generate_password)
            
            echo -e "\n${YELLOW}Creating user $USER_EMAIL in Thunder...${NC}"

            USER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
              -H "Content-Type: application/json" \
              -H "Accept: application/json" \
              https://$THUNDER_HOST:$THUNDER_PORT/users \
              -d "{
                \"organizationUnit\": \"456e8400-e29b-41d4-a716-446655440001\",
                \"type\": \"emailuser\",
                \"attributes\": {
                  \"username\": \"$USER_USERNAME\",
                  \"password\": \"$USER_PASSWORD\",
                  \"email\": \"$USER_EMAIL\"
                }
              }")

            USER_BODY=$(echo "$USER_RESPONSE" | head -n -1)
            USER_STATUS=$(echo "$USER_RESPONSE" | tail -n1)

            if [ "$USER_STATUS" -eq 201 ] || [ "$USER_STATUS" -eq 200 ]; then
                echo -e "${GREEN}✓ User $USER_EMAIL created successfully (HTTP $USER_STATUS)${NC}"

                # Update Postfix virtual-users
                sed -i "/^${USER_USERNAME}@${MAIL_DOMAIN}[[:space:]]/d" "$VIRTUAL_USERS_FILE" 2>/dev/null || \
                sed -i '' "/^${USER_USERNAME}@${MAIL_DOMAIN}[[:space:]]/d" "$VIRTUAL_USERS_FILE"

                echo -e "${USER_USERNAME}@${MAIL_DOMAIN}\t${MAIL_DOMAIN}/${USER_USERNAME}" >> "$VIRTUAL_USERS_FILE"
                sort -u -o "$VIRTUAL_USERS_FILE" "$VIRTUAL_USERS_FILE"
                sed -i -e '$a\' "$VIRTUAL_USERS_FILE" 2>/dev/null || sed -i '' -e '$a\' "$VIRTUAL_USERS_FILE"

                echo -e "${GREEN}✓ SMTP configuration updated for $USER_EMAIL${NC}"

                # Encrypt password and store
                ENCRYPTED_PASSWORD=$(encrypt_password "$USER_PASSWORD")
                echo "EMAIL: $USER_EMAIL" >> "$PASSWORDS_FILE"
                echo "ENCRYPTED: $ENCRYPTED_PASSWORD" >> "$PASSWORDS_FILE"
                echo "" >> "$PASSWORDS_FILE"

                # Show encrypted password in terminal for admin
                echo -e "${BLUE}📧 Email: ${GREEN}$USER_EMAIL${NC}"
                echo -e "${BLUE}🔐 Encrypted Password: ${YELLOW}$ENCRYPTED_PASSWORD${NC}"
                echo -e "${CYAN}   Use './decrypt_password.sh $USER_EMAIL' to view the plain password${NC}"

                ADDED_COUNT=$((ADDED_COUNT + 1))
            else
                echo -e "${RED}✗ Failed to create $USER_EMAIL (HTTP $USER_STATUS)${NC}"
                echo "Response: $USER_BODY"
            fi

            # Reset for next user
            USER_USERNAME=""
        fi
    fi
done < "$USERS_FILE"

# -------------------------------
# Step 4: Recreate SMTP service (once after all users are added)
# -------------------------------
if [ "$ADDED_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}Rebuilding and recreating only the SMTP service...${NC}"
    ( cd "$SCRIPT_DIR" && docker compose up -d --build --force-recreate smtp-server )

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SMTP service successfully rebuilt and running${NC}"
    else
        echo -e "${RED}✗ Failed to recreate SMTP service. Check logs.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}No new users added, skipping SMTP rebuild.${NC}"
fi

# -------------------------------
# Final Summary
# -------------------------------
TOTAL_USERS=$(grep -c "@" "$VIRTUAL_USERS_FILE")
echo -e "\n${CYAN}==============================================${NC}"
echo -e " 🎉 ${GREEN}User Setup Complete!${NC}"
echo " Total new users added: $ADDED_COUNT"
echo " Domain: $MAIL_DOMAIN"
echo " Total users now: $TOTAL_USERS"
echo ""
echo -e "${BLUE}🔐 Security Information:${NC}"
echo -e " Encrypted passwords: ${YELLOW}$PASSWORDS_FILE${NC}"
echo -e " Admin decryption tool: ${YELLOW}./decrypt_password.sh${NC}"
echo ""
echo -e "${CYAN}Admin Usage Examples:${NC}"
echo -e " View specific user password: ${YELLOW}./decrypt_password.sh alice@$MAIL_DOMAIN${NC}"
echo -e " View all passwords: ${YELLOW}./decrypt_password.sh all${NC}"
echo -e " Decrypt hex string: ${YELLOW}./decrypt_password.sh '1a2b3c4d...'${NC}"
echo -e "${CYAN}==============================================${NC}"