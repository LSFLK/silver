#!/bin/bash
set -e
# ---------------------------
# Fake Certbot Script for Local Dev
# ---------------------------

CONFIG_FILE="../conf/silver.yaml"
MAIL_DOMAIN=$(grep -m 1 '^domain:' "$CONFIG_FILE" | awk '{print $2}' | xargs)
MAIL_DOMAIN=${MAIL_DOMAIN:-example.local}

CERT_DIR="./letsencrypt-local/live/${MAIL_DOMAIN}"
mkdir -p "$CERT_DIR"

echo "🔹 Simulating Certbot for ${MAIL_DOMAIN}..."
echo "⏳ Please wait while certificates are being issued..."
sleep 1  # simulate delay like real certbot

# Generate self-signed certs
openssl req -x509 -nodes -days 1 \
    -newkey rsa:2048 \
    -keyout "${CERT_DIR}/privkey.pem" \
    -out "${CERT_DIR}/fullchain.pem" \
    -subj "/CN=${MAIL_DOMAIN}" >/dev/null 2>&1

chmod 600 "${CERT_DIR}/privkey.pem"
chmod 644 "${CERT_DIR}/fullchain.pem"

echo "✅ Self-signed certificates generated at ${CERT_DIR}"
echo " - privkey.pem"
echo " - fullchain.pem"
