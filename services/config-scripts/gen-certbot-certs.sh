#!/bin/bash
#
# This script initializes certbot certificates with wildcard support
# for ALL domains defined in silver.yaml
#

set -euo pipefail

# --- Paths ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SILVER_YAML_FILE="${ROOT_DIR}/../conf/silver.yaml"
readonly LETSENCRYPT_PATH="${ROOT_DIR}/silver-config/certbot/keys"

# Extract domains from silver.yaml
DOMAINS=$(grep '^\s*-\s*domain:' "${SILVER_YAML_FILE}" | sed 's/.*domain:\s*//' | xargs)

if [ -z "$DOMAINS" ]; then
    echo "❌ Error: No domains found in ${SILVER_YAML_FILE}"
    exit 1
fi

echo "========================================="
echo "  Wildcard Certificate Setup"
echo "========================================="
echo ""

echo "Domains detected:"
for domain in $DOMAINS; do
    echo " • $domain"
done

echo ""
echo "Each domain will receive:"
echo "  - domain certificate"
echo "  - wildcard subdomain certificate"
echo ""

read -p "Press Enter to continue..."

# Loop through each domain
for DOMAIN in $DOMAINS; do

    echo ""
    echo "========================================="
    echo "Processing domain: ${DOMAIN}"
    echo "========================================="

    if [ -d "${LETSENCRYPT_PATH}/etc/live/${DOMAIN}" ]; then
        echo "Existing certificate found for ${DOMAIN}"
        read -p "Attempt renewal for ${DOMAIN}? (y/n): " RENEW_CHOICE

        if [[ "$RENEW_CHOICE" =~ ^[Yy]$ ]]; then
            docker run --rm \
                -v "${LETSENCRYPT_PATH}/etc:/etc/letsencrypt" \
                -v "${LETSENCRYPT_PATH}/lib:/var/lib/letsencrypt" \
                -v "${LETSENCRYPT_PATH}/log:/var/log/letsencrypt" \
                certbot/certbot renew --cert-name "${DOMAIN}"
        else
            echo "Skipping ${DOMAIN}"
        fi

        continue
    fi

    echo ""
    echo "Certificate will cover:"
    echo "  • ${DOMAIN}"
    echo "  • *.${DOMAIN}"
    echo ""

    echo "DNS verification will be required."
    echo "You will need to create TXT records manually."
    echo ""

    read -p "Press Enter to request certificate for ${DOMAIN}..."

    docker run -it --rm \
        -v "${LETSENCRYPT_PATH}/etc:/etc/letsencrypt" \
        -v "${LETSENCRYPT_PATH}/lib:/var/lib/letsencrypt" \
        -v "${LETSENCRYPT_PATH}/log:/var/log/letsencrypt" \
        certbot/certbot \
        certonly \
        --manual \
        --preferred-challenges dns \
        --agree-tos \
        --email "admin@${DOMAIN}" \
        --key-type rsa \
        -d "${DOMAIN}" \
        -d "*.${DOMAIN}"

    echo ""
    echo "✅ Certificate generated for ${DOMAIN}"

done

echo ""
echo "========================================="
echo "🎉 All certificate operations completed!"
echo "========================================="
echo ""
echo "Certificates stored in:"
echo "${LETSENCRYPT_PATH}/etc/live/"