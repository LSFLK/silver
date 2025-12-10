#!/bin/sh
set -e

CONFIG_FILE="/etc/certbot/silver.yaml"

echo "========================================="
echo "  Multi-Domain Certificate Request"
echo "========================================="
echo ""

# Extract ALL domains from the domains list in silver.yaml using grep/sed
DOMAINS=$(grep '^\s*-\s*domain:' "$CONFIG_FILE" | sed 's/.*domain:\s*//' | xargs)

if [ -z "$DOMAINS" ]; then
    echo "❌ Error: No domains found in $CONFIG_FILE"
    echo "Please check that $CONFIG_FILE contains domains in the correct format:"
    echo "domains:"
    echo "  - domain: example.com"
    exit 1
fi

# Get primary domain for email
PRIMARY_DOMAIN=$(echo "$DOMAINS" | awk '{print $1}')

echo "Domains to be covered by this certificate:"

# Build the certbot command with all domains
CERTBOT_CMD="certbot certonly --standalone --non-interactive --agree-tos --email admin@${PRIMARY_DOMAIN} --key-type rsa --keep-until-expiring --expand"

for domain in $DOMAINS; do
    echo "  • $domain"
    CERTBOT_CMD="$CERTBOT_CMD -d $domain"
done

# Add the mail subdomain for the primary domain at the end
echo "  • mail.$PRIMARY_DOMAIN"
CERTBOT_CMD="$CERTBOT_CMD -d mail.$PRIMARY_DOMAIN"

echo ""
echo "Using HTTP-01 challenge (port 80 required)"
echo "Starting certificate request..."
echo "========================================="
echo ""

# Execute the certbot command
exec $CERTBOT_CMD

echo "✅ Certificate successfully requested for all domains"