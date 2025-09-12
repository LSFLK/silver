#!/bin/sh
set -e

CONFIG_FILE="/etc/certbot/silver.yaml"

export MAIL_DOMAIN=$(yq -e '.domain' "$CONFIG_FILE")

MAIL_DOMAIN=${MAIL_DOMAIN:-example.org}

echo "Requesting certificate for ${MAIL_DOMAIN} and mail.${MAIL_DOMAIN}..."

# Execute the main certbot command passed from the Dockerfile's CMD
exec certbot certonly --standalone --non-interactive --key-type rsa --agree-tos \
    --email "admin@${MAIL_DOMAIN}" \
    -d "${MAIL_DOMAIN}" \
    -d "mail.${MAIL_DOMAIN}"

echo "Certbot process completed."