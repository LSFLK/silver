#!/bin/bash

set -e

ENV_FILE="/root/mail/silver/services/.env"
CONTACT_POINTS_FILE="/root/mail/silver/services/silver-config/grafana/provisioning/alerting/contact-points.yaml"

echo "Loading environment variables..."

set -o allexport
source "$ENV_FILE"
set +o allexport

if [ -z "$GOOGLE_CHAT_WEBHOOK_URL" ]; then
  echo "ERROR: GOOGLE_CHAT_WEBHOOK_URL is not set in .env"
  exit 1
fi

echo "Updating Grafana contact-points.yaml..."

# Escape & for sed
ESCAPED_URL=$(printf '%s\n' "$GOOGLE_CHAT_WEBHOOK_URL" | sed 's/[&]/\\&/g')

sed -i "s|^\([[:space:]]*url:\).*|\1 $ESCAPED_URL|" "$CONTACT_POINTS_FILE"

echo "Done."

chown 472:472 /root/mail/silver/services/silver-config/grafana/provisioning/alerting/contact-points.yaml