#!/bin/bash

# ============================================
#  Silver Mail - Remove Test Users Script
# ============================================
# This script removes all test users created by create_test_users.sh
# It removes users from:
# 1. Thunder IDP
# 2. Shared database (SQLite)
# 3. Individual user databases
# 4. Test credentials file

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
SERVICES_DIR="$(cd "${SCRIPT_DIR}/../../services" && pwd)"
CONF_DIR="$(cd "${SCRIPT_DIR}/../../conf" && pwd)"
CONFIG_FILE="${CONF_DIR}/silver.yaml"
OUTPUT_DIR="${SCRIPT_DIR}/test_users"
CREDENTIALS_FILE="${OUTPUT_DIR}/test_users_credentials.csv"

# Thunder settings
THUNDER_PORT="8090"

# -------------------------------
# Helper Functions
# -------------------------------

# Extract domain from silver.yaml
get_domain_from_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}✗ Configuration file not found: $CONFIG_FILE${NC}"
        exit 1
    fi
    
    # Extract the first domain from the domains array in silver.yaml
    local domain=$(grep -m 1 '^\s*-\s*domain:' "$CONFIG_FILE" | sed 's/.*domain:\s*//' | xargs)
    
    if [ -z "$domain" ]; then
        # Try to get primary_domain as fallback
        domain=$(grep -E '^\s*primary_domain:' "$CONFIG_FILE" | sed 's/.*primary_domain:\s*//' | xargs)
    fi
    
    if [ -z "$domain" ]; then
        # Try to get mail_domain as fallback
        domain=$(grep -E '^\s*mail_domain:' "$CONFIG_FILE" | sed 's/.*mail_domain:\s*//' | xargs)
    fi
    
    if [ -z "$domain" ]; then
        echo -e "${RED}✗ Could not find domain in $CONFIG_FILE${NC}" >&2
        exit 1
    fi
    
    echo "$domain"
}

# Check if Docker Compose services are running
check_services() {
    echo -e "${YELLOW}Checking Docker Compose services...${NC}"

    if ! (cd "${SERVICES_DIR}" && docker compose ps smtp-server) | grep -q "Up\|running"; then
        echo -e "${RED}✗ SMTP server container is not running${NC}"
        echo -e "${YELLOW}Please start the services first: docker compose up -d${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ SMTP server container is running${NC}"
    fi
}

# Get user count from container database
get_container_user_count() {
    local smtp_container="$1"
    local count=$(docker exec "$smtp_container" bash -c "sqlite3 /app/data/databases/shared.db 'SELECT COUNT(*) FROM users WHERE enabled=1;' 2>/dev/null || echo '0'" | tr -d '\n\r' | head -c 10)
    echo ${count:-0}
}

# -------------------------------
# Main Script
# -------------------------------

echo -e "${CYAN}==============================================${NC}"
echo -e " 🗑️  ${RED}Silver Mail - Test User Removal${NC}"
echo -e "${CYAN}==============================================${NC}\n"

# Get domain from config file
echo -e "${YELLOW}Reading domain from configuration...${NC}"
DOMAIN=$(get_domain_from_config)
echo -e "${GREEN}✓ Using domain: $DOMAIN${NC}\n"

# Set Thunder host
THUNDER_HOST=${DOMAIN}
echo -e "${GREEN}✓ Thunder host set to: $THUNDER_HOST:$THUNDER_PORT${NC}\n"

# -------------------------------
# Authenticate with Thunder and get organization unit
# -------------------------------
# Source Thunder authentication utility
source "${SCRIPT_DIR}/../utils/thunder-auth.sh"

# Authenticate with Thunder
echo -e "${YELLOW}Authenticating with Thunder...${NC}"
if ! thunder_authenticate "$THUNDER_HOST" "$THUNDER_PORT"; then
    exit 1
fi

# Get organization unit ID for "silver"
if ! thunder_get_org_unit "$THUNDER_HOST" "$THUNDER_PORT" "$BEARER_TOKEN" "silver"; then
    exit 1
fi

# -------------------------------
# Check services and setup
# -------------------------------
check_services

# Find the smtp container
SMTP_CONTAINER=$(cd "${SERVICES_DIR}" && docker compose ps -q smtp-server 2>/dev/null)
if [ -z "$SMTP_CONTAINER" ]; then
    echo -e "${RED}✗ SMTP container not found. Is Docker Compose running?${NC}"
    exit 1
fi

# Get current user count
CURRENT_USER_COUNT=$(get_container_user_count "$SMTP_CONTAINER")
echo -e "${CYAN}Current users in database: ${GREEN}$CURRENT_USER_COUNT${NC}\n"

# -------------------------------
# Read test users from credentials file
# -------------------------------
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo -e "${YELLOW}⚠️  Credentials file not found: $CREDENTIALS_FILE${NC}"
    echo -e "${YELLOW}Will attempt to remove all test users based on username patterns${NC}\n"
    
    # Get test user patterns from database (excluding admin users)
    TEST_USERS=$(docker exec "$SMTP_CONTAINER" bash -c "sqlite3 /app/data/databases/shared.db \"SELECT u.username FROM users u INNER JOIN domains d ON u.domain_id = d.id WHERE d.domain='${DOMAIN}' AND u.enabled=1 AND u.username != 'admin' AND (u.username LIKE 'user%' OR u.username LIKE 'test%' OR u.username LIKE 'demo%' OR u.username LIKE 'employee%' OR u.username LIKE 'staff%' OR u.username LIKE 'member%');\" 2>/dev/null" | tr '\n' ' ')
    
    if [ -z "$TEST_USERS" ]; then
        echo -e "${YELLOW}No test users found matching patterns (user*, test*, demo*, employee*, staff*, member*)${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}✓ Found credentials file: $CREDENTIALS_FILE${NC}"
    
    # Count users in CSV (excluding header)
    USER_COUNT=$(tail -n +2 "$CREDENTIALS_FILE" | wc -l | tr -d ' ')
    echo -e "${CYAN}Test users to remove: ${GREEN}$USER_COUNT${NC}\n"
    
    # Read usernames from CSV
    TEST_USERS=$(tail -n +2 "$CREDENTIALS_FILE" | cut -d',' -f1 | tr '\n' ' ')
fi

if [ -z "$TEST_USERS" ]; then
    echo -e "${YELLOW}No test users to remove${NC}"
    exit 0
fi

echo -e "${YELLOW}⚠️  WARNING: This will permanently delete the following:${NC}"
echo -e "  • All test users from Thunder IDP"
echo -e "  • All test users from shared database"
echo -e "  • All individual user databases"
echo -e "  • Test credentials file"
echo ""
echo -e "${RED}This action cannot be undone!${NC}"
echo ""

# Skip confirmation if AUTO_CONFIRM is set (for CI/CD)
if [ "${AUTO_CONFIRM}" != "true" ]; then
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}Auto-confirmed (running in automated mode)${NC}"
fi

echo ""
echo -e "${CYAN}Starting test user removal process...${NC}\n"

# -------------------------------
# Remove users from Thunder IDP
# -------------------------------
echo -e "${YELLOW}Step 1: Removing users from Thunder IDP...${NC}"

THUNDER_REMOVED=0
THUNDER_FAILED=0
THUNDER_NOT_FOUND=0

for USERNAME in $TEST_USERS; do
    # Skip admin user to prevent accidental deletion
    if [ "$USERNAME" = "admin" ]; then
        echo -e "${YELLOW}  ⚠️  Skipping admin user (protected)${NC}"
        continue
    fi
    
    EMAIL="${USERNAME}@${DOMAIN}"
    
    # Get user ID from Thunder by email using SCIM filter syntax
    # URL encode the filter: filter=email eq "user@domain.com"
    FILTER="email eq \"${EMAIL}\""
    ENCODED_FILTER=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${FILTER}'))")
    
    USER_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
        -H "Accept: application/json" \
        -H "Authorization: Bearer ${BEARER_TOKEN}" \
        "https://${THUNDER_HOST}:${THUNDER_PORT}/users?filter=${ENCODED_FILTER}")
    
    USER_BODY=$(echo "$USER_RESPONSE" | head -n -1)
    USER_STATUS=$(echo "$USER_RESPONSE" | tail -n1)
    
    if [ "$USER_STATUS" -eq 200 ]; then
        # Extract user ID and username from response
        USER_ID=$(echo "$USER_BODY" | grep -o '"id":"[^"]*' | head -n1 | sed 's/"id":"//')
        THUNDER_USERNAME=$(echo "$USER_BODY" | grep -o '"username":"[^"]*' | head -n1 | sed 's/"username":"//')
        
        if [ -n "$USER_ID" ]; then
            # Double-check: Never delete if Thunder username is "admin"
            if [ "$THUNDER_USERNAME" = "admin" ]; then
                echo -e "${YELLOW}  ⚠️  Skipping Thunder admin user (username: admin, email: $EMAIL)${NC}"
                THUNDER_NOT_FOUND=$((THUNDER_NOT_FOUND + 1))
            else
                # Delete user from Thunder
                DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
                    -H "Authorization: Bearer ${BEARER_TOKEN}" \
                    "https://${THUNDER_HOST}:${THUNDER_PORT}/users/${USER_ID}")
                
                DELETE_STATUS=$(echo "$DELETE_RESPONSE" | tail -n1)
                
                if [ "$DELETE_STATUS" -eq 204 ] || [ "$DELETE_STATUS" -eq 200 ]; then
                    THUNDER_REMOVED=$((THUNDER_REMOVED + 1))
                    if [ $((THUNDER_REMOVED % 10)) -eq 0 ]; then
                        echo -e "${GREEN}  ✓ Removed $THUNDER_REMOVED users from Thunder...${NC}"
                    fi
                else
                    echo -e "${RED}  ✗ Failed to delete $EMAIL from Thunder (HTTP $DELETE_STATUS)${NC}"
                    THUNDER_FAILED=$((THUNDER_FAILED + 1))
                fi
            fi
        else
            THUNDER_NOT_FOUND=$((THUNDER_NOT_FOUND + 1))
        fi
    else
        THUNDER_NOT_FOUND=$((THUNDER_NOT_FOUND + 1))
    fi
done

echo -e "${GREEN}✓ Thunder cleanup complete:${NC}"
echo -e "  • Removed: ${GREEN}$THUNDER_REMOVED${NC}"
echo -e "  • Not found: ${YELLOW}$THUNDER_NOT_FOUND${NC}"
echo -e "  • Failed: ${RED}$THUNDER_FAILED${NC}\n"

# -------------------------------
# Remove individual user databases (BEFORE removing from shared DB)
# -------------------------------
echo -e "${YELLOW}Step 2: Removing individual user databases...${NC}"
echo -e "${CYAN}  Database location: /app/data/databases/user_db_{id}.db${NC}"
echo -e "${CYAN}  Getting user IDs from shared database first...${NC}"

DATABASES_REMOVED=0
DATABASES_NOT_FOUND=0
DATABASES_FAILED=0
DB_REMOVED=0

for USERNAME in $TEST_USERS; do
    # Skip admin user to prevent accidental deletion
    if [ "$USERNAME" = "admin" ]; then
        continue
    fi
    
    # Get user ID from shared database first
    RESULT=$(docker exec "$SMTP_CONTAINER" bash -c "
        DB_PATH='/app/data/databases/shared.db'
        
        # Get domain_id
        domain_id=\$(sqlite3 \"\$DB_PATH\" \"SELECT id FROM domains WHERE domain='${DOMAIN}' AND enabled=1;\" 2>/dev/null)
        
        if [ -z \"\$domain_id\" ]; then
            echo 'DOMAIN_NOT_FOUND'
            exit 0
        fi
        
        # Get user ID
        user_id=\$(sqlite3 \"\$DB_PATH\" \"SELECT id FROM users WHERE username='${USERNAME}' AND domain_id=\$domain_id;\" 2>/dev/null)
        
        if [ -z \"\$user_id\" ]; then
            echo 'USER_NOT_FOUND'
            exit 0
        fi
        
        # Remove user database file using the naming convention: user_db_{id}.db
        DB_FILE=\"/app/data/databases/user_db_\${user_id}.db\"
        
        if [ -f \"\$DB_FILE\" ]; then
            rm -f \"\$DB_FILE\"
            if [ \$? -eq 0 ]; then
                echo \"REMOVED:\${user_id}\"
            else
                echo \"FAILED:\${user_id}\"
            fi
        else
            echo \"NOT_FOUND:\${user_id}\"
        fi
    " 2>&1)
    
    # Parse the result
    if echo "$RESULT" | grep -q "^REMOVED:"; then
        DATABASES_REMOVED=$((DATABASES_REMOVED + 1))
        USER_ID=$(echo "$RESULT" | cut -d: -f2)
        if [ $((DATABASES_REMOVED % 10)) -eq 0 ]; then
            echo -e "${GREEN}  ✓ Removed $DATABASES_REMOVED user databases...${NC}"
        fi
    elif echo "$RESULT" | grep -q "^NOT_FOUND:"; then
        USER_ID=$(echo "$RESULT" | cut -d: -f2)
        DATABASES_NOT_FOUND=$((DATABASES_NOT_FOUND + 1))
        # Database file doesn't exist, but we'll still try to remove the user from shared DB
    elif echo "$RESULT" | grep -q "^FAILED:"; then
        USER_ID=$(echo "$RESULT" | cut -d: -f2)
        DATABASES_FAILED=$((DATABASES_FAILED + 1))
        echo -e "${RED}  ✗ Failed to remove user_db_${USER_ID}.db for ${USERNAME}${NC}"
    fi
done

echo -e "${GREEN}✓ User database files cleanup complete:${NC}"
echo -e "  • Removed: ${GREEN}$DATABASES_REMOVED${NC}"
echo -e "  • Not found: ${YELLOW}$DATABASES_NOT_FOUND${NC}"
echo -e "  • Failed: ${RED}$DATABASES_FAILED${NC}\n"

# -------------------------------
# Remove users from shared database
# -------------------------------
echo -e "${YELLOW}Step 3: Removing users from shared database...${NC}"

for USERNAME in $TEST_USERS; do
    # Skip admin user to prevent accidental deletion
    if [ "$USERNAME" = "admin" ]; then
        continue
    fi
    
    docker exec "$SMTP_CONTAINER" bash -c "
        DB_PATH='/app/data/databases/shared.db'
        
        # Get domain_id
        domain_id=\$(sqlite3 \"\$DB_PATH\" \"SELECT id FROM domains WHERE domain='${DOMAIN}' AND enabled=1;\" 2>/dev/null)
        
        if [ -n \"\$domain_id\" ]; then
            # Delete user from shared database
            sqlite3 \"\$DB_PATH\" \"DELETE FROM users WHERE username='${USERNAME}' AND domain_id=\$domain_id;\" 2>/dev/null
            
            if [ \$? -eq 0 ]; then
                echo 'SUCCESS'
            fi
        fi
    " 2>&1 | grep -q "SUCCESS" && DB_REMOVED=$((DB_REMOVED + 1))
    
    if [ $((DB_REMOVED % 10)) -eq 0 ] && [ $DB_REMOVED -gt 0 ]; then
        echo -e "${GREEN}  ✓ Removed $DB_REMOVED users from shared database...${NC}"
    fi
done

echo -e "${GREEN}✓ Shared database cleanup complete: Removed $DB_REMOVED users${NC}\n"

# -------------------------------
# Reload Postfix configuration
# -------------------------------
echo -e "${YELLOW}Step 4: Reloading Postfix configuration...${NC}"
if docker exec "$SMTP_CONTAINER" postfix reload >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Postfix configuration reloaded successfully${NC}\n"
else
    echo -e "${RED}✗ Failed to reload Postfix configuration${NC}\n"
fi

# -------------------------------
# Remove credentials file and test users directory
# -------------------------------
echo -e "${YELLOW}Step 5: Cleaning up local files...${NC}"

FILES_REMOVED=0
if [ -f "$CREDENTIALS_FILE" ]; then
    rm -f "$CREDENTIALS_FILE"
    echo -e "${GREEN}✓ Removed credentials file${NC}"
    FILES_REMOVED=$((FILES_REMOVED + 1))
fi

# Remove the entire test_users directory if empty or only contains credentials
if [ -d "$OUTPUT_DIR" ]; then
    # Count files in directory
    FILE_COUNT=$(find "$OUTPUT_DIR" -type f | wc -l)
    if [ "$FILE_COUNT" -eq 0 ]; then
        rmdir "$OUTPUT_DIR"
        echo -e "${GREEN}✓ Removed empty test_users directory${NC}"
    else
        echo -e "${YELLOW}⚠️  test_users directory contains other files, not removing${NC}"
    fi
fi

# Also remove from test/load/test_data/users.csv if it exists
TEST_LOAD_CSV="${SCRIPT_DIR}/../../test/load/test_data/users.csv"
if [ -f "$TEST_LOAD_CSV" ]; then
    rm -f "$TEST_LOAD_CSV"
    echo -e "${GREEN}✓ Removed test load data file${NC}"
    FILES_REMOVED=$((FILES_REMOVED + 1))
fi

echo ""

# -------------------------------
# Final Summary
# -------------------------------
FINAL_USER_COUNT=$(get_container_user_count "$SMTP_CONTAINER")

echo -e "${CYAN}==============================================${NC}"
echo -e " 🎉 ${GREEN}Test User Removal Complete!${NC}"
echo -e "${CYAN}==============================================${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo -e "  • Thunder IDP: ${GREEN}$THUNDER_REMOVED${NC} removed, ${YELLOW}$THUNDER_NOT_FOUND${NC} not found, ${RED}$THUNDER_FAILED${NC} failed"
echo -e "  • Shared database: ${GREEN}$DB_REMOVED${NC} users removed"
echo -e "  • User databases: ${GREEN}$DATABASES_REMOVED${NC} databases removed"
echo -e "  • Files cleaned: ${GREEN}$FILES_REMOVED${NC} files"
echo ""
echo -e "${BLUE}📈 User Statistics:${NC}"
echo -e "  • Users before: ${YELLOW}$CURRENT_USER_COUNT${NC}"
echo -e "  • Users after: ${GREEN}$FINAL_USER_COUNT${NC}"
echo -e "  • Total removed: ${GREEN}$((CURRENT_USER_COUNT - FINAL_USER_COUNT))${NC}"
echo ""
echo -e "${CYAN}==============================================${NC}"
echo ""