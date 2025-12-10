#!/bin/bash
#
# This script initializes the certbot certs
#

# --- Sanity Checks & Configuration ---
set -euo pipefail

# Define constant paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SILVER_YAML_FILE="${ROOT_DIR}/../conf/silver.yaml"
readonly CONFIGS_PATH="${ROOT_DIR}/silver-config/certbot"
readonly LETSENCRYPT_PATH="${ROOT_DIR}/silver-config/certbot/keys"
readonly DKIM_KEY_SIZE=2048

# --- Main Logic ---
# Extract ALL domains from the domains list in silver.yaml
DOMAINS=$(grep '^\s*-\s*domain:' "${SILVER_YAML_FILE}" | sed 's/.*domain:\s*//' | xargs)

if [ -z "$DOMAINS" ]; then
    echo "❌ Error: No domains found in ${SILVER_YAML_FILE}"
    exit 1
fi

# Get primary domain for certificate name and email
PRIMARY_DOMAIN=$(echo "$DOMAINS" | awk '{print $1}')

echo "========================================="
echo "  Multi-Domain Certificate Setup"
echo "========================================="
echo ""
echo "Domains to be covered by this certificate:"

for domain in $DOMAINS; do
    echo "  • $domain"
done
echo "  • mail.$PRIMARY_DOMAIN"

echo ""
echo "Using HTTP-01 challenge (port 80 required)"
echo "Certificate will be non-interactive"
echo ""

if [ -d "${LETSENCRYPT_PATH}/etc/live/${PRIMARY_DOMAIN}" ]; then
	echo "An existing certificate was found for ${PRIMARY_DOMAIN}."
	read -p "Do you want to attempt to renew it? (y/n): " RENEW_CHOICE
	if [[ "$RENEW_CHOICE" == "y" || "$RENEW_CHOICE" == "Y" ]]; then
		echo "Attempting renewal..."
		docker run --rm \
			-p 80:80 \
			-v "${LETSENCRYPT_PATH}/etc:/etc/letsencrypt" \
			-v "${LETSENCRYPT_PATH}/lib:/var/lib/letsencrypt" \
			-v "${LETSENCRYPT_PATH}/log:/var/log/letsencrypt" \
			certbot/certbot \
			renew
		exit 0
	else
		echo "Skipping renewal. If you want a new certificate, please remove the directory: ${LETSENCRYPT_PATH}/etc/live/${PRIMARY_DOMAIN}"
		exit 0
	fi
fi

echo "No existing certificate found. Requesting a new multi-domain certificate..."
echo "========================================="
echo ""

read -p "Press Enter to continue with certificate request..."

# Build the certbot command with all domains
DOMAIN_ARGS=""
for domain in $DOMAINS; do
    DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
done
# Add mail subdomain at the end
DOMAIN_ARGS="$DOMAIN_ARGS -d mail.$PRIMARY_DOMAIN"

# Request certificate using HTTP-01 challenge for all domains
docker run --rm \
	-p 80:80 \
	-v "${LETSENCRYPT_PATH}/etc:/etc/letsencrypt" \
	-v "${LETSENCRYPT_PATH}/lib:/var/lib/letsencrypt" \
	-v "${LETSENCRYPT_PATH}/log:/var/log/letsencrypt" \
	certbot/certbot \
	certonly \
	--standalone \
	--non-interactive \
	--agree-tos \
	--email "admin@${PRIMARY_DOMAIN}" \
	--key-type rsa \
	--keep-until-expiring \
	--expand \
	$DOMAIN_ARGS

echo ""
echo "========================================="
echo "✅ Certificate request completed!"
echo "========================================="
echo ""
echo "Certificate files located at:"
echo "  ${LETSENCRYPT_PATH}/etc/live/${PRIMARY_DOMAIN}/"
