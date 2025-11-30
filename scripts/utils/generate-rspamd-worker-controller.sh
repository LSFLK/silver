#!/bin/bash

set -e

# Load .env
if [ ! -f .env ]; then
  echo ".env file not found!"
  exit 1
fi

# Export variables from .env
export $(grep -v '^#' .env | xargs)

# Check variable
if [ -z "$RSPAMD_PASSWORD" ]; then
  echo "RSPAMD_PASSWORD is not set in .env"
  exit 1
fi

# Generate hashed password
echo "Generating Rspamd password hash..."
HASH=$(docker exec rspamd-server rspamadm pw --password "$RSPAMD_PASSWORD")

echo "Generated hash:"
echo "$HASH"

# Ensure config directory exists
CONFIG_DIR="../../services/silver-config/rspamd"
mkdir -p "$CONFIG_DIR"

# Create worker-controller.inc
FILE="$CONFIG_DIR/worker-controller.inc"

cat > "$FILE" <<EOF
password = "$HASH";
enable_password = "$HASH";
EOF

echo "Created $FILE"

# Restart Rspamd container
echo "Restarting Rspamd..."
docker compose -f ../../services/docker-compose.yaml restart rspamd-server

echo "Done. Use the password from .env to log in."
