#!/bin/bash

# ============================================
#  Silver Mail Setup Script
#  Generates all configurations for services
# ============================================

# Colors
readonly CYAN="\033[0;36m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[1;33m"
readonly RED="\033[0;31m"
readonly NC="\033[0m" # No Color

# Get directories
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SERVICES_DIR="$(cd "${SCRIPT_DIR}/../../services" && pwd)"
readonly CONF_DIR="$(cd "${SCRIPT_DIR}/../../conf" && pwd)"
readonly CONFIG_FILE="${CONF_DIR}/silver.yaml"

# Read config repository URL
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

# ================================
# Step 1: Domain Configuration
# ================================
echo -e "\n${YELLOW}Step 1/3: Configure domain names${NC}"

# Extract ALL domains
readonly MAIL_DOMAINS=$(grep '^\s*-\s*domain:' "${CONFIG_FILE}" | sed 's/.*domain:\s*//' | xargs)

# Validate domains exist
if [[ -z "${MAIL_DOMAINS}" ]]; then
	echo -e "${RED}ERROR: No domains configured. Please set them in '${CONFIG_FILE}'.${NC}"
	exit 1
fi

# Primary domain (first one)
readonly PRIMARY_DOMAIN=$(echo "${MAIL_DOMAINS}" | awk '{print $1}')

echo "Primary domain: ${PRIMARY_DOMAIN}"
echo "Configured domains:"

for domain in ${MAIL_DOMAINS}; do
	echo " - ${domain}"
done

# Validate each domain
for domain in ${MAIL_DOMAINS}; do
	if ! [[ "${domain}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
		echo -e "${RED}✗ ERROR: '${domain}' does not look like a valid domain name.${NC}"
		exit 1
	fi
done

# ================================
# Step 2: Clone Config Repository
# ================================
echo -e "\n${YELLOW}Step 2/3: Clone configuration repository${NC}"

if [ -d "${SERVICES_DIR}/silver-config" ]; then
	echo "Configuration repository already exists. Skipping clone."
else
	git clone "${SILVER_CONFIG}" "${SERVICES_DIR}/silver-config"
fi

# ================================
# Step 3: Generate Configurations
# ================================
echo -e "\n${YELLOW}Step 3/3: Generate service configurations${NC}"

bash "${SERVICES_DIR}/config-scripts/gen-configs.sh"

echo
echo -e "${GREEN}✓ Setup completed successfully!${NC}"
echo