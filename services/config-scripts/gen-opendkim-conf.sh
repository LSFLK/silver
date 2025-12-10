#!/bin/bash
#
# This script initializes the OpenDKIM config files for all domains and subdomains
#

# --- Sanity Checks & Configuration ---
set -euo pipefail

# Define constant paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SILVER_YAML_FILE="${ROOT_DIR}/../conf/silver.yaml"
readonly CONFIGS_PATH="${ROOT_DIR}/silver-config/opendkim"

# --- Helper function to extract domain config ---
# This awk script parses the YAML and extracts domain, selector, and key-size
extract_domain_configs() {
    awk '
    /^[[:space:]]*-[[:space:]]*domain:/ {
        # Extract domain
        domain = $0
        sub(/^[[:space:]]*-[[:space:]]*domain:[[:space:]]*/, "", domain)
        sub(/[[:space:]]*$/, "", domain)

        # Read next lines for selector and key-size
        selector = "mail"  # default
        keysize = "2048"   # default

        while ((getline line) > 0) {
            if (line ~ /^[[:space:]]*-[[:space:]]*domain:/) {
                # Next domain found, print current and reprocess this line
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
                sub(/[[:space:]]*$/, "", selector)
                if (selector == "" || selector == "null") selector = "mail"
            }
            if (line ~ /^[[:space:]]*dkim-key-size:/) {
                keysize = line
                sub(/^[[:space:]]*dkim-key-size:[[:space:]]*/, "", keysize)
                sub(/[[:space:]]*$/, "", keysize)
                if (keysize == "" || keysize == "null") keysize = "2048"
            }
            # Stop if we hit a line that suggests end of domains section
            if (line ~ /^[^[:space:]#]/ && line !~ /domains:/) {
                break
            }
        }

        # Print last domain
        if (domain != "" && domain != "null") {
            print domain "," selector "," keysize
        }
    }
    ' "$SILVER_YAML_FILE"
}

# --- Main Logic ---
echo "=== Generating OpenDKIM configuration files for all domains ==="

# Extract all domain configurations
DOMAIN_CONFIGS=$(extract_domain_configs)

if [ -z "$DOMAIN_CONFIGS" ]; then
    echo "Error: No domains found in ${SILVER_YAML_FILE}"
    exit 1
fi

# Create configs directory
mkdir -p "${CONFIGS_PATH}"

# --- Generate TrustedHosts file ---
echo "Generating TrustedHosts file..."
cat >"${CONFIGS_PATH}/TrustedHosts" <<'EOF'
127.0.0.1
localhost
192.168.65.0/16
172.16.0.0/12
10.0.0.0/8
EOF

# Add each domain to TrustedHosts
echo "$DOMAIN_CONFIGS" | while IFS=',' read -r DOMAIN SELECTOR KEYSIZE; do
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "null" ]; then
        echo "*.${DOMAIN}" >> "${CONFIGS_PATH}/TrustedHosts"
    fi
done

echo "✓ TrustedHosts file generated successfully"

# --- Generate SigningTable file ---
echo "Generating SigningTable file..."
> "${CONFIGS_PATH}/SigningTable"  # Clear the file

echo "$DOMAIN_CONFIGS" | while IFS=',' read -r DOMAIN SELECTOR KEYSIZE; do
    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
        continue
    fi

    # Add entry to SigningTable
    echo "*@${DOMAIN} ${SELECTOR}._domainkey.${DOMAIN}" >> "${CONFIGS_PATH}/SigningTable"
    echo "  Added domain: ${DOMAIN} (selector: ${SELECTOR})"
done

echo "✓ SigningTable file generated successfully"

# --- Generate KeyTable file ---
echo "Generating KeyTable file..."
> "${CONFIGS_PATH}/KeyTable"  # Clear the file

echo "$DOMAIN_CONFIGS" | while IFS=',' read -r DOMAIN SELECTOR KEYSIZE; do
    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
        continue
    fi

    # Add entry to KeyTable
    echo "${SELECTOR}._domainkey.${DOMAIN} ${DOMAIN}:${SELECTOR}:/etc/dkimkeys/${DOMAIN}/${SELECTOR}.private" >> "${CONFIGS_PATH}/KeyTable"
    echo "  Added key entry for: ${DOMAIN}"
done

echo "✓ KeyTable file generated successfully"

echo ""
echo "=== OpenDKIM configuration files generated successfully ==="
echo "Total domains configured: $(echo "$DOMAIN_CONFIGS" | wc -l | xargs)"
echo ""
echo "Files generated:"
echo "  - ${CONFIGS_PATH}/TrustedHosts"
echo "  - ${CONFIGS_PATH}/SigningTable"
echo "  - ${CONFIGS_PATH}/KeyTable"
