#!/bin/bash

# ============================================
#  Silver Mail - Add User Wizard + Thunder Init
# ============================================

# -------------------------------
# Configuration
# -------------------------------
# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Directories & files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIRTUAL_USERS_FILE="${SCRIPT_DIR}/smtp/conf/virtual-users"
CONFIG_FILE="${SCRIPT_DIR}/silver.yaml"

echo -e "${CYAN}---------------------------------------------${NC}"
echo -e " 🚀 ${GREEN}Silver Mail - Add User${NC}"
echo -e "${CYAN}---------------------------------------------${NC}\n"

# -------------------------------
# Step 0: Check maximum user limit
# -------------------------------
MAX_USERS=100
mkdir -p "$(dirname "$VIRTUAL_USERS_FILE")"
touch "$VIRTUAL_USERS_FILE"

CURRENT_USER_COUNT=$(grep -c "@" "$VIRTUAL_USERS_FILE")
if [ "$CURRENT_USER_COUNT" -ge "$MAX_USERS" ]; then
    echo -e "${RED}✗ Cannot add new user: maximum user limit ($MAX_USERS) reached. Current users: $CURRENT_USER_COUNT${NC}"
    exit 1
fi

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

## Set Thunder Host

THUNDER_HOST= "$MAIL_DOMAIN"
THUNDER_PORT=8090

# -------------------------------
# Step 2: Collect user info
# -------------------------------
echo -e "${YELLOW}Step 2/3: Enter new user information${NC}"
read -p "Enter username: " USER_USERNAME
read -s -p "Enter password: " USER_PASSWORD
echo ""
read -p "Enter email (default: ${USER_USERNAME}@${MAIL_DOMAIN}): " USER_EMAIL
USER_EMAIL=${USER_EMAIL:-"${USER_USERNAME}@${MAIL_DOMAIN}"}

echo -e "${GREEN}✓ User input collected${NC}"

# -------------------------------
# Step 3: Create user via Thunder API
# -------------------------------
echo -e "\n${YELLOW}Step 4/5: Creating user in Thunder...${NC}"

USER_RESPONSE=$(curl -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  https://maneesha.dev:8090/users \
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
    echo -e "${GREEN}✓ User created successfully (HTTP $USER_STATUS)${NC}"
else
    echo -e "${RED}✗ Failed to create user (HTTP $USER_STATUS)${NC}"
    echo "Response: $USER_BODY"
    exit 1
fi

# -------------------------------
# Step 4: Update SMTP virtual-users
# -------------------------------
echo -e "\n${YELLOW}Step 3/5: Updating SMTP configuration...${NC}"
mkdir -p "$(dirname "$VIRTUAL_USERS_FILE")"
touch "$VIRTUAL_USERS_FILE"

# Remove old entry if exists
sed -i "/^${USER_USERNAME}@${MAIL_DOMAIN}[[:space:]]/d" "$VIRTUAL_USERS_FILE" 2>/dev/null || sed -i '' "/^${USER_USERNAME}@${MAIL_DOMAIN}[[:space:]]/d" "$VIRTUAL_USERS_FILE"

# Add new entry
echo -e "${USER_USERNAME}@${MAIL_DOMAIN}\t${MAIL_DOMAIN}/${USER_USERNAME}" >> "$VIRTUAL_USERS_FILE"

# Remove duplicates
sort -u -o "$VIRTUAL_USERS_FILE" "$VIRTUAL_USERS_FILE"

# Ensure file ends with newline
sed -i -e '$a\' "$VIRTUAL_USERS_FILE" 2>/dev/null || sed -i '' -e '$a\' "$VIRTUAL_USERS_FILE"

echo -e "${GREEN}✓ SMTP configuration updated${NC}"

# -------------------------------
# Step 5: Recreate SMTP service
# -------------------------------
echo -e "\n${YELLOW}Rebuilding and recreating only the SMTP service...${NC}"
( cd "$SCRIPT_DIR" && docker compose up -d --build --force-recreate smtp-server )

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SMTP service successfully rebuilt and running${NC}"
else
    echo -e "${RED}✗ Failed to recreate SMTP service. Check logs.${NC}"
    exit 1
fi

# -------------------------------
# Final Summary
# -------------------------------
echo -e "\n${CYAN}---------------------------------------------${NC}"
echo -e " 🎉 ${GREEN}New User Setup Complete!${NC}"
echo " Username: $USER_USERNAME"
echo " Email:    $USER_EMAIL"
echo " Domain:   $MAIL_DOMAIN"
echo " Total users now: $((CURRENT_USER_COUNT + 1))"
echo -e "${CYAN}---------------------------------------------${NC}"