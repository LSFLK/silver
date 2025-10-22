#!/bin/bash
#
# This script initializes the OpenDKIM config files
#

# --- Sanity Checks & Configuration ---
set -euo pipefail

# Define constant paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SILVER_YAML_FILE="${ROOT_DIR}/../conf/silver.yaml"
readonly CONFIGS_PATH="${ROOT_DIR}/silver-config/gen/opendkim"
readonly DKIM_SELECTOR=mail
readonly DKIM_KEYS_PATH="${ROOT_DIR}/silver-config/data/opendkim/keys"
readonly DKIM_KEY_SIZE=2048

# --- Main Logic ---
readonly MAIL_DOMAIN=$(grep -m 1 '^domain:' "${SILVER_YAML_FILE}" | sed 's/domain: //' | xargs)

# --- generate all files needed for OpenDkim ---
# Generate the TrustedHosts file.
mkdir -p ${CONFIGS_PATH}
cat >"${CONFIGS_PATH}/TrustedHosts" <<EOF
127.0.0.1
localhost
192.168.65.0/16
172.16.0.0/12
10.0.0.0/8
*.${MAIL_DOMAIN}
EOF

echo "Successfully generated OpenDKIM TrustedHosts file for domain: ${MAIL_DOMAIN}"

cat >"${CONFIGS_PATH}/SigningTable" <<EOF
*@$MAIL_DOMAIN $DKIM_SELECTOR._domainkey.$MAIL_DOMAIN
EOF

echo "Successfully generated OpenDKIM SigningTable file for domain: ${MAIL_DOMAIN}"

# Write KeyTable
cat >"${CONFIGS_PATH}/KeyTable" <<EOF
$DKIM_SELECTOR._domainkey.$MAIL_DOMAIN $MAIL_DOMAIN:$DKIM_SELECTOR:/etc/dkimkeys/$MAIL_DOMAIN/$DKIM_SELECTOR.private
EOF

echo "Successfully generated OpenDKIM KeyTable file for domain: ${MAIL_DOMAIN}"
