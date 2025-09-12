#!/bin/bash
set -e

# -------------------------------
# Read domain from yaml file
# -------------------------------

CONFIG_FILE="silver.yaml"

DOMAIN=$(grep -m 1 '^domain:' "$CONFIG_FILE" | sed 's/domain: //' | xargs)

# Validate if DOMAIN is empty
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Domain name is not configured or is empty. Please set it in '$CONFIG_FILE'.${NC}"
    exit 1 # Exit the script with a failure status
else
    echo "Domain name found: $DOMAIN"
    # ...continue with the rest of your script...
fi

if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}✗ Warning: '${DOMAIN}' does not look like a valid domain name.${NC}"
    exit 1
fi

SELECTOR="mail"
CONTAINER_NAME="opendkim-server"
KEY_PATH="/etc/opendkim/keys/$DOMAIN/$SELECTOR.txt"

# -------------------------------
# Extract DKIM record from container
# -------------------------------
DKIM_RAW=$(docker exec -i "$CONTAINER_NAME" cat "$KEY_PATH")

# Extract the content between quotes, remove the parentheses and join the parts
DKIM_CONTENT=$(echo "$DKIM_RAW" | grep -A10 'TXT.*(' | sed -n '/"/,/"/p' | tr -d '\n\t' | sed 's/[[:space:]]*"[[:space:]]*/ /g; s/^[[:space:]]*"//; s/"[[:space:]]*$//')

# Now we need to split this properly for DNS - the long p= value needs to be split
# Extract everything before the long p= value
PREFIX=$(echo "$DKIM_CONTENT" | sed 's/\(.*p=\).*/\1/')

# Extract the p= value only
P_VALUE=$(echo "$DKIM_CONTENT" | sed 's/.*p=\([^"]*\).*/\1/' | tr -d ' ')

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

# -------------------------------
# Print instructions
# -------------------------------
echo "🚀 DKIM Record for $DOMAIN"
echo "----------------------------------------"
echo "Type: TXT"
echo "Name: ${SELECTOR}._domainkey"
echo "Content:"
echo "$DKIM_VALUE"
echo "----------------------------------------"
echo "✅ Copy this value into your DNS TXT record."