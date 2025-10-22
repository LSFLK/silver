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
readonly CONFIGS_PATH="${ROOT_DIR}/silver-config/gen/certbot"
readonly LETSENCRYPT_PATH="${ROOT_DIR}/silver-config/data/certbot/keys"
readonly DKIM_KEY_SIZE=2048

# --- Main Logic ---
readonly MAIL_DOMAIN=$(grep -m 1 '^domain:' "${SILVER_YAML_FILE}" | sed 's/domain: //' | xargs)

if [ -d "${LETSENCRYPT_PATH}/etc/live/${MAIL_DOMAIN}" ]; then
	echo "An existing certificate was found for ${MAIL_DOMAIN}."
	read -p "Do you want to attempt to renew it? (y/n): " RENEW_CHOICE
	if [[ "$RENEW_CHOICE" == "y" || "$RENEW_CHOICE" == "Y" ]]; then
		CERTBOT_COMMAND="renew"
	else
		echo "Skipping renewal. If you want a new certificate, please remove the directory: ${LETSENCRYPT_PATH}/etc/live/${MAIL_DOMAIN}"
		exit 0
	fi
else
	echo "No existing certificate found. Requesting a new one..."
	CERTBOT_COMMAND="certonly"
fi

docker run --rm \
	-p 80:80 \
	-v "${LETSENCRYPT_PATH}/etc:/etc/letsencrypt" \
	-v "${LETSENCRYPT_PATH}/lib:/var/lib/letsencrypt" \
	-v "${LETSENCRYPT_PATH}/log:/var/log/letsencrypt" \
	certbot/certbot \
	certonly \
	--standalone \
	--agree-tos \
	--register-unsafely-without-email \
	--key-type rsa \
	-d "${MAIL_DOMAIN}" \
	-d "mail.${MAIL_DOMAIN}"
