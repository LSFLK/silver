#!/bin/bash

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/gen-certbot-certs.sh"
bash "${SCRIPT_DIR}/gen-opendkim-conf.sh"
bash "${SCRIPT_DIR}/gen-rspamd-conf.sh"
bash "${SCRIPT_DIR}/gen-postfix-conf.sh"
bash "${SCRIPT_DIR}/gen-thunder-certs.sh"
bash "${SCRIPT_DIR}/gen-raven-conf.sh"
