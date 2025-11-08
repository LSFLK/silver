#!/bin/bash

# ============================================
#  Silver Mail Setup Script - This script is responsible for generating all the configs for our services.
# ============================================

# Colors
readonly CYAN="\033[0;36m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[1;33m"
readonly RED="\033[0;31m"
readonly NC="\033[0m" # No Color

# Get the script directory (where the scripts are located)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Services directory contains config-scripts
readonly SERVICES_DIR="$(cd "${SCRIPT_DIR}/../../services" && pwd)"
# Conf directory contains config files
readonly CONF_DIR="$(cd "${SCRIPT_DIR}/../../conf" && pwd)"
readonly CONFIG_FILE="${CONF_DIR}/silver.yaml"
# Read silver-config from the configuration file
readonly SILVER_CONFIG=$(grep -m 1 '^config-url:' "${CONFIG_FILE}" | sed 's/config-url: //' | xargs)

# ASCII Banner
echo -e "${CYAN}"
cat <<'EOF'
                                                                                                
                                                                                                
   SSSSSSSSSSSSSSS   iiii  lllllll                                                              
 SS:::::::::::::::S i::::i l:::::l                                                              
S:::::SSSSSS::::::S  iiii  l:::::l                                                              
S:::::S     SSSSSSS        l:::::l                                                              
S:::::S            iiiiiii  l::::lvvvvvvv           vvvvvvv eeeeeeeeeeee    rrrrr   rrrrrrrrr   
S:::::S            i::::i  l::::l v:::::v         v:::::vee::::::::::::ee  r::::rrr:::::::::r  
 S::::SSSS          i::::i  l::::l  v:::::v       v:::::ve::::::eeeee:::::eer:::::::::::::::::r 
  SS::::::SSSSS     i::::i  l::::l   v:::::v     v:::::ve::::::e     e:::::err::::::rrrrr::::::r
    SSS::::::::SS   i::::i  l::::l    v:::::v   v:::::v e:::::::eeeee::::::e r:::::r     r:::::r
       SSSSSS::::S  i::::i  l::::l     v:::::v v:::::v  e:::::::::::::::::e  r:::::r     rrrrrrr
            S:::::S i::::i  l::::l      v:::::v:::::v   e::::::eeeeeeeeeee   r:::::r            
            S:::::S i::::i  l::::l       v:::::::::v    e:::::::e            r:::::r            
SSSSSSS     S:::::Si::::::il::::::l       v:::::::v     e::::::::e           r:::::r            
S::::::SSSSSS:::::Si::::::il::::::l        v:::::v       e::::::::eeeeeeee   r:::::r            
S:::::::::::::::SS i::::::il::::::l         v:::v         ee:::::::::::::e   r:::::r            
 SSSSSSSSSSSSSSS   iiiiiiiillllllll          vvv            eeeeeeeeeeeeee   rrrrrrr            
                                                                                                 
EOF
echo -e "${NC}"

echo
echo -e " 🚀 ${GREEN}Welcome to the Silver Mail System Setup${NC}"
echo "---------------------------------------------"

MAIL_DOMAIN=""

# ================================
# Step 1: Domain Configuration
# ================================
echo -e "\n${YELLOW}Step 1/8: Configure domain name${NC}"

# Extract primary (first) domain from the domains list in silver.yaml
readonly MAIL_DOMAIN=$(grep -m 1 '^\s*-\s*domain:' "${CONFIG_FILE}" | sed 's/.*domain:\s*//' | xargs)

# Validate if MAIL_DOMAIN is empty
if [[ -z "${MAIL_DOMAIN}" ]]; then
	echo -e "${RED}ERROR: Domain name is not configured. Please set it in '${CONFIG_FILE}'.${NC}"
	exit 1
else
	echo "Domain name found: ${MAIL_DOMAIN}"
fi

if ! [[ "${MAIL_DOMAIN}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
	echo -e "${RED}✗ ERROR: '${MAIL_DOMAIN}' does not look like a valid domain name.${NC}"
	exit 1
fi

# ================================
# Step 2: Config Generation
# ================================

git clone ${SILVER_CONFIG} "${SERVICES_DIR}/silver-config"

# ================================
# Step 3: Generate Service Configurations
# ================================

bash ${SERVICES_DIR}/config-scripts/gen-configs.sh
