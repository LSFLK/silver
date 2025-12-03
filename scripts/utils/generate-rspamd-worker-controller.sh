#!/bin/bash

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="${SCRIPT_DIR}/../../services"
CONFIG_DIR="${SERVICES_DIR}/silver-config/rspamd"

# Load .env if it exists, using safer 'source' approach
if [ -f "${SCRIPT_DIR}/../.env" ]; then
  set -a
  source "${SCRIPT_DIR}/../.env"
  set +a
elif [ -f "${SERVICES_DIR}/.env" ]; then
  set -a
  source "${SERVICES_DIR}/.env"
  set +a
fi

# Check if RSPAMD_PASSWORD is set, otherwise use default
if [ -z "$RSPAMD_PASSWORD" ]; then
  echo "Warning: RSPAMD_PASSWORD not set in .env, using default password 'admin'"
  RSPAMD_PASSWORD="admin"
fi

# Generate hashed password
echo "Generating Rspamd password hash..."
HASH=$(docker exec rspamd-server rspamadm pw --password "$RSPAMD_PASSWORD" 2>/dev/null)

if [ -z "$HASH" ]; then
  echo "Error: Could not generate password hash. Is rspamd-server running?"
  exit 1
fi

echo "Generated hash: $HASH"

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# Create worker-controller.inc with full configuration
FILE="$CONFIG_DIR/worker-controller.inc"

cat > "$FILE" <<EOF
# Controller worker configuration
# Enables both web UI (password-protected) and Prometheus metrics

# Bind to all interfaces for Docker networking
bind_socket = "0.0.0.0:11334";

# Single controller worker
count = 1;

# Allow unauthenticated access to /metrics endpoint for Prometheus
# This allows metrics to be scraped from anywhere without password
# Web UI (/index.html, /graph, etc.) still requires authentication
#
# secure_ip allows these IPs to access /metrics without password:
# - Docker networks (172.16.0.0/12, 192.168.0.0/16)
# - localhost (127.0.0.1, ::1)
# - All IPs (0.0.0.0/0) for external Prometheus access
secure_ip = ["0.0.0.0/0", "127.0.0.1", "::1"];

# Password-protected web UI access
# Password is stored in .env as RSPAMD_PASSWORD
# This password is required for:
# - Web UI: http://server:11334
# - API endpoints (except /metrics)
password = "$HASH";
enable_password = "$HASH";
EOF

echo "✓ Created $FILE"
echo "  - Rspamd web UI: http://localhost:11334"
echo "  - Password: (see .env file for RSPAMD_PASSWORD)"

# Restart Rspamd container
echo ""
echo "Restarting Rspamd..."
(cd "$SERVICES_DIR" && docker compose restart rspamd-server)

echo ""
echo "✓ Done! You can now access the Rspamd web UI with your password."
