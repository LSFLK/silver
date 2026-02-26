#!/bin/bash
set -e

# -------------------------------
# Base paths
# -------------------------------
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/.env"
SILVER_CONFIG="${PROJECT_ROOT}/silver-config"

# Grafana paths
GRAFANA_ALERTS_FILE="${SILVER_CONFIG}/grafana/provisioning/alerting/contact-points.yaml"
GRAFANA_CERTS_DIR="${SILVER_CONFIG}/grafana/certs"

# Certbot / Let's Encrypt paths
MAIL_DOMAIN=$(grep -m 1 '^\s*-\s*domain:' "${PROJECT_ROOT}/../conf/silver.yaml" | sed 's/.*domain:\s*//' | xargs)
LETSENCRYPT_DIR="${SILVER_CONFIG}/certbot/keys/etc/live/${MAIL_DOMAIN}"

# Grafana config
GRAFANA_CONFIG_FILE="${SILVER_CONFIG}/grafana/grafana.ini"

# -------------------------------
# Load environment variables
# -------------------------------
echo "Loading environment variables..."
set -o allexport
source "${ENV_FILE}"
set +o allexport

if [[ -z "${GOOGLE_CHAT_WEBHOOK_URL}" ]]; then
  echo "ERROR: GOOGLE_CHAT_WEBHOOK_URL is not set in .env" >&2
  exit 1
fi

# -------------------------------
# Update Grafana contact points
# -------------------------------
echo "Updating Grafana contact-points.yaml..."

ESCAPED_URL="$(printf '%s\n' "${GOOGLE_CHAT_WEBHOOK_URL}" | sed 's/[&]/\\&/g')"
sed -i "s|^\([[:space:]]*url:\).*|\1 ${ESCAPED_URL}|" "${GRAFANA_ALERTS_FILE}"

chown 472:472 "${GRAFANA_ALERTS_FILE}"
echo "Done."

# -------------------------------
# Install Grafana TLS certificates
# -------------------------------
echo "Installing Grafana TLS certificates..."

mkdir -p "${GRAFANA_CERTS_DIR}"

cp "${LETSENCRYPT_DIR}/fullchain.pem" "${GRAFANA_CERTS_DIR}/grafana.crt"
cp "${LETSENCRYPT_DIR}/privkey.pem"   "${GRAFANA_CERTS_DIR}/grafana.key"

chown 472:472 \
  "${GRAFANA_CERTS_DIR}/grafana.key" \
  "${GRAFANA_CERTS_DIR}/grafana.crt"

chmod 440 "${GRAFANA_CERTS_DIR}/grafana.key"
chmod 444 "${GRAFANA_CERTS_DIR}/grafana.crt"

echo "Grafana TLS certificates installed successfully."

# -------------------------------
# Update Grafana domain (<MAIL_DOMAIN>)
# -------------------------------
echo "Updating Grafana domain in grafana.ini..."

if [[ -z "${MAIL_DOMAIN}" ]]; then
  echo "ERROR: No domain configured in silver.yaml. Cannot update Grafana domain." >&2
  exit 1
fi

if [[ ! -f "${GRAFANA_CONFIG_FILE}" ]]; then
  echo "ERROR: Grafana config not found at ${GRAFANA_CONFIG_FILE}" >&2
  exit 1
fi

sed -i "s|<MAIL_DOMAIN>|${MAIL_DOMAIN}|g" "${GRAFANA_CONFIG_FILE}"

chown 472:472 "${GRAFANA_CONFIG_FILE}"

echo "Grafana domain updated to ${MAIL_DOMAIN}"