#!/bin/bash
set -e

# -------------------------------
# Read domains from yaml file
# -------------------------------

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Conf directory contains config files
CONF_DIR="$(cd "${SCRIPT_DIR}/../../conf" && pwd)"
CONFIG_FILE="${CONF_DIR}/silver.yaml"

CONTAINER_NAME="opendkim-server"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Error: Container '$CONTAINER_NAME' is not running!"
    echo "Please start the container first."
    exit 1
fi

# Function to process and format DKIM record
process_dkim_record() {
    local DOMAIN=$1
    local SELECTOR=$2
    local KEY_PATH="/etc/dkimkeys/$DOMAIN/$SELECTOR.txt"

    # Check if the key file exists in the container
    if ! docker exec "$CONTAINER_NAME" test -f "$KEY_PATH" 2>/dev/null; then
        echo "⚠️  Warning: DKIM key not found for $DOMAIN at $KEY_PATH"
        return
    fi

    # Extract DKIM record from container
    DKIM_RAW=$(docker exec "$CONTAINER_NAME" cat "$KEY_PATH" 2>/dev/null || echo "")

    if [ -z "$DKIM_RAW" ]; then
        echo "⚠️  Warning: Could not read DKIM key for $DOMAIN"
        return
    fi

    # Extract the content between quotes and join multiple lines
    DKIM_CONTENT=$(echo "$DKIM_RAW" | grep -o '"[^"]*"' | tr -d '"' | tr -d '\n' | sed 's/[[:space:]]\+/ /g')

    if [ -z "$DKIM_CONTENT" ]; then
        echo "⚠️  Warning: Could not parse DKIM content for $DOMAIN"
        return
    fi

    # Extract everything before the long p= value
    PREFIX=$(echo "$DKIM_CONTENT" | sed 's/\(.*p=\).*/\1/')

    # Extract the p= value only (everything after p=)
    P_VALUE=$(echo "$DKIM_CONTENT" | sed 's/.*p=\(.*\)/\1/' | tr -d ' ')

    # Split the p= value at a reasonable point (around 200 characters to stay within DNS limits)
    LEN=${#P_VALUE}
    if [ $LEN -gt 200 ]; then
        SPLIT_POINT=200
        P_PART1=${P_VALUE:0:$SPLIT_POINT}
        P_PART2=${P_VALUE:$SPLIT_POINT}
        DKIM_VALUE="\"${PREFIX}${P_PART1}\" \"${P_PART2}\""
    else
        DKIM_VALUE="\"${PREFIX}${P_VALUE}\""
    fi

    # Print instructions
    echo ""
    echo "🚀 DKIM Record for $DOMAIN"
    echo "----------------------------------------"
    echo "Type: TXT"
    echo "Name: ${SELECTOR}._domainkey"
    echo "Content:"
    echo "$DKIM_VALUE"
    echo "----------------------------------------"
}

# -------------------------------
# Print DKIM records for all domains
# -------------------------------
echo "📋 DKIM Records for All Configured Domains"
echo "========================================"

# Use a simpler approach - read the YAML directly with grep and awk
grep -E "^\s*-\s*domain:" "$CONFIG_FILE" | while read -r line; do
    # Extract domain from the line
    DOMAIN=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*domain:[[:space:]]*//;s/[[:space:]]*$//')
    
    # Get selector (default to 'mail' if not found)
    SELECTOR=$(grep -A2 "domain:[[:space:]]*$DOMAIN" "$CONFIG_FILE" | grep "dkim-selector:" | sed 's/^[[:space:]]*dkim-selector:[[:space:]]*//;s/[[:space:]]*$//' || echo "mail")
    
    if [ -z "$SELECTOR" ]; then
        SELECTOR="mail"
    fi
    
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "null" ]; then
        process_dkim_record "$DOMAIN" "$SELECTOR"
    fi
done

echo ""
echo "✅ Copy these values into your DNS TXT records."
echo ""