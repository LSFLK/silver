#!/bin/bash
# gen-dovecot-conf.sh
# Script to generate Dovecot configuration files

set -euo pipefail

# Define constant paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SILVER_YAML_FILE="${ROOT_DIR}/../conf/silver.yaml"
readonly CONFIGS_PATH="${ROOT_DIR}/silver-config/static/dovecot"
readonly DKIM_SELECTOR=mail
readonly DKIM_KEY_SIZE=2048

# --- Main Logic ---
readonly MAIL_DOMAIN=$(grep -m 1 '^domain:' "${SILVER_YAML_FILE}" | sed 's/domain: //' | xargs)

sed -i'' -e "s#\${MAIL_DOMAIN}#${MAIL_DOMAIN}#g" ${CONFIGS_PATH}/dovecot.conf
sed -i'' -e "s#__MAIL_DOMAIN__#\"${MAIL_DOMAIN}\"#g" ${CONFIGS_PATH}/auth_api.lua
