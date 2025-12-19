#!/bin/bash

# ============================================
#  Silver Mail - Generate Test Users Script
# ============================================
# This script generates 100 random test users, adds them to Thunder and shared.db,
# and saves their credentials to a CSV file.
# Domain is automatically read from conf/silver.yaml

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

# User generation settings
NUM_USERS=100
MAX_USERS=100

# Thunder settings
THUNDER_PORT="8090"

# -------------------------------
# Helper Functions
# -------------------------------

# Generate a random strong password
generate_password() {
    openssl rand -base64 24 | tr -d '\n' | head -c 16
}

# Generate random username
generate_username() {
    local index=$1
    # Generate random usernames with various patterns
    local prefixes=("user" "test" "demo" "employee" "staff" "member")
    local prefix=${prefixes[$((RANDOM % 6))]}
    printf "%s%03d" "$prefix" "$index"
}

# Extract domain from silver.yaml
get_domain_from_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}✗ Configuration file not found: $CONFIG_FILE${NC}"
        exit 1
    fi
    
    # Extract the first domain from the domains array in silver.yaml
    # Look for pattern: "- domain: example.com" or "  - domain: example.com"
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
        echo -e "${YELLOW}Please ensure at least one domain is configured in the domains section${NC}" >&2
        exit 1
    fi
    
    echo "$domain"
}

# Check if Docker Compose services are running
check_services() {
    echo -e "${YELLOW}Checking Docker Compose services...${NC}"

    if ! (cd "${SERVICES_DIR}" && docker compose ps smtp-server) | grep -q "Up\|running"; then
        echo -e "${RED}✗ SMTP server container is not running${NC}"
        echo -e "${YELLOW}Starting services with: docker compose up -d${NC}"
        (cd "${SERVICES_DIR}" && docker compose up -d)
        sleep 10
    else
        echo -e "${GREEN}✓ SMTP server container is running${NC}"
    fi
}

# Add user to SQLite database
update_container_virtual_users() {
    local smtp_container="$1"
    local user_email="$2"
    local username="$3"
    local mail_domain="$4"

    docker exec "$smtp_container" bash -c "
        DB_PATH='/app/data/databases/shared.db'

        # Get domain_id
        domain_id=\$(sqlite3 \"\$DB_PATH\" \"SELECT id FROM domains WHERE domain='${mail_domain}' AND enabled=1;\")

        if [ -z \"\$domain_id\" ]; then
            echo 'Error: Domain ${mail_domain} not found in database'
            exit 1
        fi

        # Insert user into database with password_initialized set to true (1) for testing
        sqlite3 \"\$DB_PATH\" \"INSERT OR REPLACE INTO users (username, domain_id, enabled, password_initialized) VALUES ('${username}', \$domain_id, 1, 1);\"

        if [ \$? -eq 0 ]; then
            echo 'User added to database successfully'
        else
            echo 'Failed to add user to database'
            exit 1
        fi
    " 2>&1
}

# Check user count in container (from SQLite database)
get_container_user_count() {
    local smtp_container="$1"
    local count=$(docker exec "$smtp_container" bash -c "sqlite3 /app/data/databases/shared.db 'SELECT COUNT(*) FROM users WHERE enabled=1;' 2>/dev/null || echo '0'" | tr -d '\n\r' | head -c 10)
    echo ${count:-0}
}

# Ensure domain exists in database
ensure_domain_exists() {
    local smtp_container="$1"
    local domain="$2"
    echo -e "${YELLOW}Ensuring domain ${domain} exists in database...${NC}"

    DOMAIN_CHECK=$(docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"SELECT COUNT(*) FROM domains WHERE domain='${domain}';\"
    " 2>/dev/null | tr -d '\n\r')

    if [ "$DOMAIN_CHECK" = "0" ]; then
        echo -e "${YELLOW}Domain ${domain} not found. Adding to database...${NC}"
        docker exec "$smtp_container" bash -c "
            sqlite3 /app/data/databases/shared.db \"INSERT INTO domains (domain, enabled, created_at) VALUES ('${domain}', 1, datetime('now'));\"
        "

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Domain ${domain} added to database${NC}"
        else
            echo -e "${RED}✗ Failed to add domain to database${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Domain ${domain} already exists in database${NC}"
    fi
    return 0
}

# -------------------------------
# Main Script
# -------------------------------

echo -e "${CYAN}==============================================${NC}"
echo -e " 🚀 ${GREEN}Silver Mail - Test User Generator${NC}"
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
    echo -e "${YELLOW}Try running: docker compose up -d${NC}"
    exit 1
fi

# Ensure SQLite database exists in container
docker exec "$SMTP_CONTAINER" bash -c "
    if [ ! -f /app/data/databases/shared.db ]; then
        echo 'Error: Database does not exist at /app/data/databases/shared.db'
        echo 'Please ensure raven-server is running and has created the database'
        exit 1
    fi
"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ SQLite database not found. Please start raven-server first.${NC}"
    exit 1
fi

# Ensure domain exists in database
if ! ensure_domain_exists "$SMTP_CONTAINER" "$DOMAIN"; then
    echo -e "${RED}✗ Failed to set up domain $DOMAIN. Exiting.${NC}"
    exit 1
fi

# Get current user count
CURRENT_USER_COUNT=$(get_container_user_count "$SMTP_CONTAINER")
CURRENT_USER_COUNT=${CURRENT_USER_COUNT:-0}
echo -e "${CYAN}Current users: ${GREEN}$CURRENT_USER_COUNT${NC}. Maximum allowed: $MAX_USERS${NC}"

# Prompt for number of users
echo -e "${YELLOW}Enter the number of test users to generate (default: ${NUM_USERS}):${NC}"
read -r USER_COUNT
if [ -z "$USER_COUNT" ]; then
    USER_COUNT="$NUM_USERS"
fi

# Validate user count
if ! [[ "$USER_COUNT" =~ ^[0-9]+$ ]] || [ "$USER_COUNT" -lt 1 ] || [ "$USER_COUNT" -gt 1000 ]; then
    echo -e "${RED}✗ Invalid user count. Please enter a number between 1 and 1000${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Generating $USER_COUNT test users${NC}\n"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Initialize CSV file with headers
echo "username,email,password" > "$CREDENTIALS_FILE"
echo -e "${GREEN}✓ Created credentials file: $CREDENTIALS_FILE${NC}"

echo -e "${CYAN}Generating test users...${NC}\n"

# Generate users
CREATED_COUNT=0
FAILED_COUNT=0
for i in $(seq 1 "$USER_COUNT"); do
    USERNAME=$(generate_username $i)
    EMAIL="${USERNAME}@${DOMAIN}"
    PASSWORD=$(generate_password)
    
    # Check user limit
    CURRENT_USER_COUNT=$(get_container_user_count "$SMTP_CONTAINER")
    if [ "$CURRENT_USER_COUNT" -ge "$MAX_USERS" ]; then
        echo -e "${RED}✗ Cannot add ${USERNAME}: maximum user limit ($MAX_USERS) reached. Stopping.${NC}"
        break
    fi
    
    # Check if user already exists in database
    USER_EXISTS=$(docker exec "$SMTP_CONTAINER" bash -c "sqlite3 /app/data/databases/shared.db \"SELECT COUNT(*) FROM users u INNER JOIN domains d ON u.domain_id = d.id WHERE u.username='${USERNAME}' AND d.domain='${DOMAIN}' AND u.enabled=1;\"" 2>/dev/null || echo "0")
    if [ "$USER_EXISTS" != "0" ]; then
        echo -e "${YELLOW}⚠ User ${EMAIL} already exists. Skipping.${NC}"
        continue
    fi
    
    # Create user in Thunder
    USER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer ${BEARER_TOKEN}" \
        https://${THUNDER_HOST}:${THUNDER_PORT}/users \
        -d "{
            \"organizationUnit\": \"${ORG_UNIT_ID}\",
            \"type\": \"emailuser\",
            \"attributes\": {
              \"username\": \"$USERNAME\",
              \"password\": \"$PASSWORD\",
              \"email\": \"$EMAIL\"
            }
          }")
    
    USER_BODY=$(echo "$USER_RESPONSE" | head -n -1)
    USER_STATUS=$(echo "$USER_RESPONSE" | tail -n1)
    
    if [ "$USER_STATUS" -eq 201 ] || [ "$USER_STATUS" -eq 200 ]; then
        # Update virtual configuration and add to database
        if update_container_virtual_users "$SMTP_CONTAINER" "$EMAIL" "$USERNAME" "$DOMAIN" >/dev/null 2>&1; then
            # Add to CSV
            echo "$USERNAME,$EMAIL,$PASSWORD" >> "$CREDENTIALS_FILE"
            CREATED_COUNT=$((CREATED_COUNT + 1))
            
            # Show progress
            if [ $((CREATED_COUNT % 10)) -eq 0 ]; then
                echo -e "${GREEN}✓ Created $CREATED_COUNT/$USER_COUNT users...${NC}"
            fi
        else
            echo -e "${RED}✗ Failed to add $EMAIL to database${NC}"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    else
        echo -e "${RED}✗ Failed to create user $EMAIL in Thunder (HTTP $USER_STATUS)${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

# -------------------------------
# Final Postfix configuration reload
# -------------------------------
if [ "$CREATED_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}Applying final Postfix configuration changes...${NC}"

    # Hot reload postfix configuration
    echo -e "${YELLOW}Reloading Postfix configuration...${NC}"
    if docker exec "$SMTP_CONTAINER" postfix reload >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Postfix configuration reloaded successfully${NC}"
    else
        echo -e "${RED}✗ Failed to reload Postfix configuration${NC}"
    fi
fi

# -------------------------------
# Final Summary
# -------------------------------

echo -e "\n${CYAN}==============================================${NC}"
echo -e " 🎉 ${GREEN}Test User Generation Complete!${NC}"
echo -e "${CYAN}==============================================${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo -e "  • Total users generated: ${GREEN}$CREATED_COUNT${NC}"
echo -e "  • Domain: ${GREEN}$DOMAIN${NC}"
echo -e "  • Output file: ${YELLOW}$CREDENTIALS_FILE${NC}"
echo ""
echo -e "${BLUE}🔐 Sample Credentials:${NC}"
echo -e "${CYAN}First 5 users:${NC}"
head -n 6 "$CREDENTIALS_FILE" | tail -n 5 | while IFS=',' read -r username email password; do
    echo -e "  ${YELLOW}$email${NC} : ${GREEN}$password${NC}"
done
echo ""
echo -e "${YELLOW}⚠️  SECURITY WARNING:${NC}"
echo -e "  The credentials file contains ${RED}plain text passwords${NC}!"
echo -e "  Please store it securely and delete after initial setup."
echo ""
echo -e "${BLUE}📝 CSV Format:${NC}"
echo -e "  ${CYAN}username,email,password${NC}"
echo ""
echo -e "${BLUE}📁 Output Location:${NC}"
echo -e "  ${GREEN}$CREDENTIALS_FILE${NC}"
echo ""
echo -e "${CYAN}==============================================${NC}"

