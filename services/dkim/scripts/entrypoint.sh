#!/bin/bash
set -e

CONFIG_FILE="/etc/opendkim/silver.yaml"

echo "=== Extracting domains from $CONFIG_FILE ==="

# Extract all domains from the YAML configuration
DOMAINS=$(yq eval '.domains[].domain' "$CONFIG_FILE" 2>/dev/null | grep -v '^null$' | grep -v '^$' || echo "")

# Fallback if no domains found
if [ -z "$DOMAINS" ]; then
    echo "⚠️  Warning: Could not extract domains from $CONFIG_FILE"
    echo "⚠️  Please ensure silver.yaml has domains configured"
    DOMAINS="example.org"
fi

# Get the primary domain (first one)
PRIMARY_DOMAIN=$(echo "$DOMAINS" | head -n 1)
export MAIL_DOMAIN="$PRIMARY_DOMAIN"

echo "Primary domain: $PRIMARY_DOMAIN"
echo "Total domains to process: $(echo "$DOMAINS" | wc -l | xargs)"
echo ""

# Process each domain
echo "=== Processing domains and generating DKIM keys ==="
while IFS= read -r DOMAIN; do
    # Skip empty domains
    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
        continue
    fi

    # Extract domain-specific settings or use defaults
    DKIM_SELECTOR=$(yq eval ".domains[] | select(.domain == \"$DOMAIN\") | .dkim-selector" "$CONFIG_FILE" 2>/dev/null | grep -v '^null$' || echo "mail")
    DKIM_KEY_SIZE=$(yq eval ".domains[] | select(.domain == \"$DOMAIN\") | .dkim-key-size" "$CONFIG_FILE" 2>/dev/null | grep -v '^null$' || echo "2048")

    # Use defaults if extraction failed
    DKIM_SELECTOR=${DKIM_SELECTOR:-mail}
    DKIM_KEY_SIZE=${DKIM_KEY_SIZE:-2048}

    echo "Processing domain: $DOMAIN"
    echo "  Selector: $DKIM_SELECTOR"
    echo "  Key size: $DKIM_KEY_SIZE"

    # Create domain directory
    mkdir -p /etc/dkimkeys/$DOMAIN

    # Generate DKIM keys if missing
    if [ ! -f /etc/dkimkeys/$DOMAIN/$DKIM_SELECTOR.private ]; then
        echo "  Generating DKIM keys..."
        opendkim-genkey -b $DKIM_KEY_SIZE -s $DKIM_SELECTOR -d $DOMAIN -D /etc/dkimkeys/$DOMAIN/
        chmod 600 /etc/dkimkeys/$DOMAIN/$DKIM_SELECTOR.private
        chmod 644 /etc/dkimkeys/$DOMAIN/$DKIM_SELECTOR.txt
        echo "  ✓ DKIM keys generated"
    else
        echo "  ✓ DKIM keys already exist"
    fi
    echo ""
done <<< "$DOMAINS"

# Output DKIM DNS records for all domains
echo "========== DKIM DNS Records =========="
while IFS= read -r DOMAIN; do
    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
        continue
    fi

    DKIM_SELECTOR=$(yq eval ".domains[] | select(.domain == \"$DOMAIN\") | .dkim-selector" "$CONFIG_FILE" 2>/dev/null | grep -v '^null$' || echo "mail")
    DKIM_SELECTOR=${DKIM_SELECTOR:-mail}

    if [ -f /etc/dkimkeys/$DOMAIN/$DKIM_SELECTOR.txt ]; then
        echo ""
        echo "Domain: $DOMAIN"
        echo "Record name: $DKIM_SELECTOR._domainkey.$DOMAIN"
        echo "Record value:"
        cat /etc/dkimkeys/$DOMAIN/$DKIM_SELECTOR.txt
        echo "---"
    fi
done <<< "$DOMAINS"
echo "======================================"
echo ""

echo "=== Starting OpenDKIM ==="
echo "Configuration files:"
echo "  - KeyTable: $(wc -l < /etc/opendkim/KeyTable | xargs) entries"
echo "  - SigningTable: $(wc -l < /etc/opendkim/SigningTable | xargs) entries"
echo "  - TrustedHosts: $(wc -l < /etc/opendkim/TrustedHosts | xargs) entries"
echo ""

# Start OpenDKIM
exec opendkim -f -x /etc/opendkim/opendkim.conf