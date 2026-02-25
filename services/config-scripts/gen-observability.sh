#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
CONTACT_POINTS_FILE="$PROJECT_ROOT/silver-config/grafana/provisioning/alerting/contact-points.yaml"

echo "Loading environment variables..."

set -o allexport
source "$ENV_FILE"
set +o allexport

if [ -z "$GOOGLE_CHAT_WEBHOOK_URL" ]; then
  echo "ERROR: GOOGLE_CHAT_WEBHOOK_URL is not set in .env" >&2
  exit 1
fi

echo "Updating Grafana contact-points.yaml..."

# Escape & for sed
ESCAPED_URL=$(printf '%s\n' "$GOOGLE_CHAT_WEBHOOK_URL" | sed 's/[&]/\\&/g')

sed -i "s|^\([[:space:]]*url:\).*|\1 $ESCAPED_URL|" "$CONTACT_POINTS_FILE"

echo "Done."

chown 472:472 "$CONTACT_POINTS_FILE" # Set ownership for Grafana user (uid:gid 472:472)