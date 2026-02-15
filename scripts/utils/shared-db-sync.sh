#!/bin/bash

# ============================================
#  Shared Database Utility for Keycloak
# ============================================
#
# This utility synchronizes users between Keycloak and the shared.db
# used by Raven (IMAP/SMTP server)
#

# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$(cd "${SCRIPT_DIR}/../../services" && pwd)"
CONF_DIR="$(cd "${SCRIPT_DIR}/../../conf" && pwd)"
CONFIG_FILE="${CONF_DIR}/silver.yaml"

# Database path inside container
DB_PATH='/app/data/databases/shared.db'

# SMTP container name
SMTP_CONTAINER="smtp-server-container"

# ============================================
# Function: Check if SMTP container is running
# ============================================
check_smtp_container() {
    if ! docker ps | grep -q "$SMTP_CONTAINER"; then
        echo -e "${RED}✗ SMTP container is not running${NC}" >&2
        echo "Please start the services first" >&2
        return 1
    fi
    return 0
}

# ============================================
# Function: Add user to shared.db
# ============================================
# Arguments:
#   $1 - Username
#   $2 - Domain
# Returns:
#   0 on success, 1 on failure
# ============================================
db_add_user() {
    local username="$1"
    local domain="$2"

    if [ -z "$username" ] || [ -z "$domain" ]; then
        echo -e "${RED}✗ Username and domain are required${NC}" >&2
        return 1
    fi

    if ! check_smtp_container; then
        return 1
    fi

    echo "  - Adding user to shared.db: ${username}@${domain}"

    local result
    result=$(docker exec "$SMTP_CONTAINER" bash -c "
        # Get domain_id
        domain_id=\$(sqlite3 '$DB_PATH' \"SELECT id FROM domains WHERE domain='$domain' AND enabled=1;\")

        if [ -z \"\$domain_id\" ]; then
            echo 'ERROR: Domain $domain not found in database'
            exit 1
        fi

        # Check if user already exists
        user_exists=\$(sqlite3 '$DB_PATH' \"SELECT COUNT(*) FROM users WHERE username='$username' AND domain_id=\$domain_id;\")

        if [ \"\$user_exists\" != \"0\" ]; then
            echo 'INFO: User already exists, updating enabled status'
            sqlite3 '$DB_PATH' \"UPDATE users SET enabled=1 WHERE username='$username' AND domain_id=\$domain_id;\"
        else
            # Insert user into database
            sqlite3 '$DB_PATH' \"INSERT INTO users (username, domain_id, enabled) VALUES ('$username', \$domain_id, 1);\"
        fi

        if [ \$? -eq 0 ]; then
            echo 'SUCCESS'
        else
            echo 'ERROR: Failed to add user to database'
            exit 1
        fi
    " 2>&1)

    if echo "$result" | grep -q "SUCCESS"; then
        echo -e "${GREEN}  ✓ User added to shared.db successfully${NC}"
        return 0
    elif echo "$result" | grep -q "INFO: User already exists"; then
        echo -e "${GREEN}  ✓ User already exists in shared.db (enabled)${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to add user to shared.db${NC}" >&2
        echo "$result" >&2
        return 1
    fi
}

# ============================================
# Function: Remove user from shared.db
# ============================================
# Arguments:
#   $1 - Username
#   $2 - Domain
# Returns:
#   0 on success, 1 on failure
# ============================================
db_remove_user() {
    local username="$1"
    local domain="$2"

    if [ -z "$username" ] || [ -z "$domain" ]; then
        echo -e "${RED}✗ Username and domain are required${NC}" >&2
        return 1
    fi

    if ! check_smtp_container; then
        return 1
    fi

    echo "  - Removing user from shared.db: ${username}@${domain}"

    local result
    result=$(docker exec "$SMTP_CONTAINER" bash -c "
        # Get domain_id
        domain_id=\$(sqlite3 '$DB_PATH' \"SELECT id FROM domains WHERE domain='$domain' AND enabled=1;\")

        if [ -z \"\$domain_id\" ]; then
            echo 'ERROR: Domain $domain not found in database'
            exit 1
        fi

        # Disable user (soft delete)
        sqlite3 '$DB_PATH' \"UPDATE users SET enabled=0 WHERE username='$username' AND domain_id=\$domain_id;\"

        if [ \$? -eq 0 ]; then
            echo 'SUCCESS'
        else
            echo 'ERROR: Failed to disable user in database'
            exit 1
        fi
    " 2>&1)

    if echo "$result" | grep -q "SUCCESS"; then
        echo -e "${GREEN}  ✓ User disabled in shared.db successfully${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to disable user in shared.db${NC}" >&2
        echo "$result" >&2
        return 1
    fi
}

# ============================================
# Function: List users from shared.db
# ============================================
# Arguments:
#   $1 - Domain (optional)
# Returns:
#   0 on success, 1 on failure
# ============================================
db_list_users() {
    local domain="$1"

    if ! check_smtp_container; then
        return 1
    fi

    local query
    if [ -n "$domain" ]; then
        query="SELECT u.username, d.domain, u.enabled FROM users u INNER JOIN domains d ON u.domain_id = d.id WHERE d.domain='$domain' ORDER BY u.username;"
    else
        query="SELECT u.username, d.domain, u.enabled FROM users u INNER JOIN domains d ON u.domain_id = d.id ORDER BY d.domain, u.username;"
    fi

    docker exec "$SMTP_CONTAINER" bash -c "sqlite3 -header -column '$DB_PATH' \"$query\""
}

# ============================================
# Function: Check if user exists in shared.db
# ============================================
# Arguments:
#   $1 - Username
#   $2 - Domain
# Returns:
#   0 if exists, 1 if not
# ============================================
db_user_exists() {
    local username="$1"
    local domain="$2"

    if [ -z "$username" ] || [ -z "$domain" ]; then
        return 1
    fi

    if ! check_smtp_container; then
        return 1
    fi

    local count
    count=$(docker exec "$SMTP_CONTAINER" bash -c "
        domain_id=\$(sqlite3 '$DB_PATH' \"SELECT id FROM domains WHERE domain='$domain' AND enabled=1;\")
        if [ -n \"\$domain_id\" ]; then
            sqlite3 '$DB_PATH' \"SELECT COUNT(*) FROM users WHERE username='$username' AND domain_id=\$domain_id AND enabled=1;\"
        else
            echo '0'
        fi
    " 2>/dev/null | tr -d '\n\r')

    if [ "$count" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# ============================================
# Function: Initialize domain in shared.db
# ============================================
# Arguments:
#   $1 - Domain
# Returns:
#   0 on success, 1 on failure
# ============================================
db_init_domain() {
    local domain="$1"

    if [ -z "$domain" ]; then
        echo -e "${RED}✗ Domain is required${NC}" >&2
        return 1
    fi

    if ! check_smtp_container; then
        return 1
    fi

    echo "  - Initializing domain in shared.db: ${domain}"

    local result
    result=$(docker exec "$SMTP_CONTAINER" bash -c "
        # Check if domain exists
        domain_exists=\$(sqlite3 '$DB_PATH' \"SELECT COUNT(*) FROM domains WHERE domain='$domain';\")

        if [ \"\$domain_exists\" != \"0\" ]; then
            echo 'INFO: Domain already exists'
            sqlite3 '$DB_PATH' \"UPDATE domains SET enabled=1 WHERE domain='$domain';\"
        else
            # Insert domain into database
            sqlite3 '$DB_PATH' \"INSERT INTO domains (domain, enabled) VALUES ('$domain', 1);\"
        fi

        if [ \$? -eq 0 ]; then
            echo 'SUCCESS'
        else
            echo 'ERROR: Failed to initialize domain'
            exit 1
        fi
    " 2>&1)

    if echo "$result" | grep -q "SUCCESS\|INFO: Domain already exists"; then
        echo -e "${GREEN}  ✓ Domain initialized successfully${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to initialize domain${NC}" >&2
        echo "$result" >&2
        return 1
    fi
}

# Export functions for use in other scripts
export -f db_add_user
export -f db_remove_user
export -f db_list_users
export -f db_user_exists
export -f db_init_domain
export -f check_smtp_container