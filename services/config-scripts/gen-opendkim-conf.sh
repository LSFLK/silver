#!/bin/bash
#
# This script initializes the OpenDKIM config files for all domains and their subdomains
#

set -euo pipefail

# --- Paths ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SILVER_YAML_FILE="${ROOT_DIR}/../conf/silver.yaml"
readonly CONFIGS_PATH="${ROOT_DIR}/silver-config/opendkim"

# --- Helper: Extract domain configs from silver.yaml ---
extract_domain_configs() {
    awk '
    /^[[:space:]]*-[[:space:]]*domain:/ {
        domain = $0
        sub(/^[[:space:]]*-[[:space:]]*domain:[[:space:]]*/, "", domain)
        sub(/[[:space:]]*$/, "", domain)

        selector = "mail"
        keysize = "2048"

        while ((getline line) > 0) {
            if (line ~ /^[[:space:]]*-[[:space:]]*domain:/) {
                print domain "," selector "," keysize
                domain = line
                sub(/^[[:space:]]*-[[:space:]]*domain:[[:space:]]*/, "", domain)
                sub(/[[:space:]]*$/, "", domain)
                selector = "mail"
                keysize = "2048"
                continue
            }
            if (line ~ /^[[:space:]]*dkim-selector:/) {
                selector = line
                sub(/^[[:space:]]*dkim-selector:[[:space:]]*/, "", selector)
                if (selector == "" || selector == "null") selector = "mail"
            }
            if (line ~ /^[[:space:]]*dkim-key-size:/) {
                keysize = line
                sub(/^[[:space:]]*dkim-key-size:[[:space:]]*/, "", keysize)
                if (keysize == "" || keysize == "null") keysize = "2048"
            }
            if (line ~ /^[^[:space:]#]/ && line !~ /domains:/) { break }
        }
        if (domain != "" && domain != "null") { print domain "," selector "," keysize }
    }
    ' "$SILVER_YAML_FILE"
}

# --- Main ---
echo "=== Generating OpenDKIM configuration files for all domains and subdomains ==="

DOMAIN_CONFIGS=$(extract_domain_configs)
if [ -z "$DOMAIN_CONFIGS" ]; then
    echo "Error: No domains found in ${SILVER_YAML_FILE}"
    exit 1
fi

mkdir -p "$CONFIGS_PATH"

# --- TrustedHosts ---
echo "Generating TrustedHosts..."
cat >"${CONFIGS_PATH}/TrustedHosts" <<'EOF'
127.0.0.1
localhost
192.168.65.0/16
172.16.0.0/12
10.0.0.0/8
EOF

echo "$DOMAIN_CONFIGS" | while IFS=',' read -r DOMAIN SELECTOR KEYSIZE; do
    echo "$DOMAIN" >> "${CONFIGS_PATH}/TrustedHosts"
    echo "*.$DOMAIN" >> "${CONFIGS_PATH}/TrustedHosts"
done
echo "✓ TrustedHosts generated"

# --- SigningTable ---
echo "Generating SigningTable..."
> "${CONFIGS_PATH}/SigningTable"
echo "$DOMAIN_CONFIGS" | while IFS=',' read -r DOMAIN SELECTOR KEYSIZE; do
    echo "*@$DOMAIN $SELECTOR._domainkey.$DOMAIN" >> "${CONFIGS_PATH}/SigningTable"
    echo "*@*.$DOMAIN $SELECTOR._domainkey.$DOMAIN" >> "${CONFIGS_PATH}/SigningTable"
done
echo "✓ SigningTable generated"

# --- KeyTable ---
echo "Generating KeyTable..."
> "${CONFIGS_PATH}/KeyTable"
echo "$DOMAIN_CONFIGS" | while IFS=',' read -r DOMAIN SELECTOR KEYSIZE; do
    echo "$SELECTOR._domainkey.$DOMAIN $DOMAIN:$SELECTOR:/etc/dkimkeys/$DOMAIN/$SELECTOR.private" >> "${CONFIGS_PATH}/KeyTable"
done
echo "✓ KeyTable generated"

echo ""
echo "=== OpenDKIM configuration completed ==="
echo "Domains configured: $(echo "$DOMAIN_CONFIGS" | wc -l | xargs)"
echo "Files:"
echo "  - ${CONFIGS_PATH}/TrustedHosts"
echo "  - ${CONFIGS_PATH}/SigningTable"
echo "  - ${CONFIGS_PATH}/KeyTable"