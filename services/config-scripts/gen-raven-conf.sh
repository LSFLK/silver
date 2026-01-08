#!/bin/bash
# -----------------------------------------------------------------------------
# Raven Configuration Generator
# Generates the raven.yaml and copies required certificates.
# -----------------------------------------------------------------------------

set -euo pipefail # Exit on error, undefined vars, or failed pipe

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"       # /root/silver/services
GEN_DIR="${ROOT_DIR}/silver-config/raven" # Base path

CONFIG_FILE="${ROOT_DIR}/../conf/silver.yaml"
OUTPUT_FILE="${GEN_DIR}/conf/raven.yaml"
MAILS_DB_PATH="${GEN_DIR}/data/databases/shared.db"
SEAWEEDFS_ENV_FILE="${ROOT_DIR}/seaweedfs/.env"
SEAWEEDFS_ENV_EXAMPLE="${ROOT_DIR}/seaweedfs/.env.example"

# --- Extract primary (first) domain from silver.yaml ---
# Look for the first domain entry under the domains list
MAIL_DOMAIN=$(grep -m 1 '^\s*-\s*domain:' "$CONFIG_FILE" | sed 's/.*domain:\s*//' | xargs)
MAIL_DOMAIN=${MAIL_DOMAIN:-example.local}

# --- Load SeaweedFS credentials from .env file ---
if [ -f "$SEAWEEDFS_ENV_FILE" ]; then
	# Source the .env file
	set -a  # automatically export all variables
	source "$SEAWEEDFS_ENV_FILE"
	set +a
	echo "✅ Loaded SeaweedFS credentials from .env file"
else
	echo "⚠️  Warning: SeaweedFS .env file not found at $SEAWEEDFS_ENV_FILE"
	if [ -f "$SEAWEEDFS_ENV_EXAMPLE" ]; then
		echo "   Creating .env from .env.example..."
		cp "$SEAWEEDFS_ENV_EXAMPLE" "$SEAWEEDFS_ENV_FILE"
		set -a
		source "$SEAWEEDFS_ENV_FILE"
		set +a
		echo "   ⚠️  Using example credentials. Please update $SEAWEEDFS_ENV_FILE with secure credentials!"
	else
		echo "   ❌ Error: .env.example not found. Using fail to prevent insecure defaults."
		exit 1
	fi
fi

# Set defaults if variables are not set
S3_ACCESS_KEY=${S3_ACCESS_KEY:-raven}
S3_SECRET_KEY=${S3_SECRET_KEY:-raven-secret}
S3_ENDPOINT=${S3_ENDPOINT:-http://seaweedfs-s3:8333}
S3_REGION=${S3_REGION:-us-east-1}
S3_BUCKET=${S3_BUCKET:-email-attachments}
S3_TIMEOUT=${S3_TIMEOUT:-30}

# --- Certificate paths ---
LETSENCRYPT_PATH="${ROOT_DIR}/silver-config/certbot/keys/etc/live/${MAIL_DOMAIN}"
RAVEN_CERT_PATH="${ROOT_DIR}/silver-config/raven/certs"

# --- Prepare directories ---
mkdir -p "$(dirname "$OUTPUT_FILE")" "$(dirname "$MAILS_DB_PATH")" "$RAVEN_CERT_PATH"

# --- Generate raven.yaml ---
cat >"$OUTPUT_FILE" <<EOF
domain: ${MAIL_DOMAIN}
auth_server_url: https://thunder-server:8090/auth/credentials/authenticate

# S3-Compatible Blob Storage Configuration
blob_storage:
  enabled: true
  endpoint: "${S3_ENDPOINT}"
  region: "${S3_REGION}"
  bucket: "${S3_BUCKET}"
  access_key: "${S3_ACCESS_KEY}"
  secret_key: "${S3_SECRET_KEY}"
  timeout: ${S3_TIMEOUT}  # seconds
EOF

echo "✅ Generated: $OUTPUT_FILE (domain: ${MAIL_DOMAIN})"

# --- Create shared.db if not exists ---
if [ ! -f "$MAILS_DB_PATH" ]; then
	touch "$MAILS_DB_PATH"
	echo "✅ Created: empty shared.db at $MAILS_DB_PATH"
else
	echo "ℹ️ shared.db already exists at $MAILS_DB_PATH (not overwritten)"
fi

# --- Copy certificates ---
if [ -f "${LETSENCRYPT_PATH}/fullchain.pem" ] && [ -f "${LETSENCRYPT_PATH}/privkey.pem" ]; then
	cp "${LETSENCRYPT_PATH}/fullchain.pem" "${RAVEN_CERT_PATH}/fullchain.pem"
	cp "${LETSENCRYPT_PATH}/privkey.pem" "${RAVEN_CERT_PATH}/privkey.pem"
	echo "✅ Copied Raven certificates for domain: ${MAIL_DOMAIN}"
else
	echo "⚠️ Warning: Certificates not found in ${LETSENCRYPT_PATH}"
	echo "   Skipped copying Raven certificates."
fi

echo "✅ Raven configuration successfully generated."
