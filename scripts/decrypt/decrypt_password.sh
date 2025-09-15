#!/bin/bash

# ============================================
#  Silver Mail - Admin Password Decryption Tool
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORDS_FILE="${SCRIPT_DIR}/user_passwords.txt"

# -------------------------------
# Prompt for encryption key
# -------------------------------
echo -e "Enter encryption key to decrypt passwords:"
read -s ENCRYPT_KEY
echo ""
if [ -z "$ENCRYPT_KEY" ]; then
    echo -e "\033[0;31m✗ Encryption key cannot be empty\033[0m"
    exit 1
fi

# Colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BLUE="\033[0;34m"
NC="\033[0m"

# Simple XOR decryption
decrypt_password() {
    local encrypted="$1"
    local key="$ENCRYPT_KEY"
    local decrypted=""
    local i=0
    local key_len=${#key}
    
    # Process hex pairs
    while [ $i -lt ${#encrypted} ]; do
        local hex_pair="${encrypted:$i:2}"
        if [ ${#hex_pair} -eq 2 ]; then
            if [[ "$hex_pair" =~ ^[0-9A-Fa-f]{2}$ ]]; then
                local char_code=$((0x$hex_pair))
                local key_char="${key:$(((i/2) % key_len)):1}"
                local key_code=$(printf '%d' "'$key_char")
                local xor_result=$((char_code ^ key_code))
                decrypted="${decrypted}$(printf "\\$(printf %o $xor_result)")"
            else
                echo -e "${RED}✗ Invalid hex pair: '$hex_pair' in encrypted string${NC}" >&2
                return 1
            fi
        fi
        i=$((i + 2))
    done
    
    echo "$decrypted"
}

if [ ! -f "$PASSWORDS_FILE" ]; then
    echo -e "${RED}✗ Password file not found: $PASSWORDS_FILE${NC}"
    exit 1
fi

echo -e "${CYAN}================================================${NC}"
echo -e "${BLUE} 🔐 Silver Mail - Admin Password Decryption Tool${NC}"
echo -e "${CYAN}================================================${NC}"

if [ $# -eq 0 ]; then
    echo -e "\n${CYAN}Usage: $0 [email|all|encrypted_hex]${NC}"
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 alice@example.com        # Show password for specific user"
    echo -e "  $0 all                      # Show all passwords"
    echo -e "  $0 '1a2b3c4d...'            # Decrypt specific hex string"
    echo ""
    echo -e "${CYAN}Available users:${NC}"
    if grep -q "EMAIL:" "$PASSWORDS_FILE"; then
        grep "EMAIL:" "$PASSWORDS_FILE" | sed 's/EMAIL: /  📧 /' | sort
    else
        echo -e "${YELLOW}  No users found in password file${NC}"
    fi
    exit 0
fi

if [ "$1" = "all" ]; then
    echo -e "\n${CYAN}All User Passwords (Decrypted):${NC}"
    echo -e "${CYAN}================================${NC}"
    
    while IFS= read -r line; do
        if [[ $line =~ ^EMAIL:\ (.+)$ ]]; then
            EMAIL="${BASH_REMATCH[1]}"
            echo -e "\n${BLUE}📧 Email: ${GREEN}$EMAIL${NC}"
        elif [[ $line =~ ^ENCRYPTED:\ (.+)$ ]]; then
            ENCRYPTED="${BASH_REMATCH[1]}"
            PASSWORD=$(decrypt_password "$ENCRYPTED")
            if [ -n "$PASSWORD" ]; then
                echo -e "${BLUE}🔑 Password: ${YELLOW}$PASSWORD${NC}"
                echo -e "${BLUE}🔐 Encrypted: ${GREEN}$ENCRYPTED${NC}"
            else
                echo -e "${RED}✗ Failed to decrypt password${NC}"
            fi
        fi
    done < "$PASSWORDS_FILE"
elif [[ "$1" == *"@"* ]]; then
    # Treat as email address
    TARGET_EMAIL="$1"
    FOUND=false
    
    echo -e "\n${CYAN}Password for: ${GREEN}$TARGET_EMAIL${NC}"
    echo -e "${CYAN}=========================${NC}"
    
    while IFS= read -r line; do
        if [[ $line =~ ^EMAIL:\ (.+)$ ]]; then
            EMAIL="${BASH_REMATCH[1]}"
            if [ "$EMAIL" = "$TARGET_EMAIL" ]; then
                FOUND=true
                echo -e "${BLUE}📧 Email: ${GREEN}$EMAIL${NC}"
            else
                FOUND=false
            fi
        elif [[ $line =~ ^ENCRYPTED:\ (.+)$ ]] && [ "$FOUND" = true ]; then
            ENCRYPTED="${BASH_REMATCH[1]}"
            PASSWORD=$(decrypt_password "$ENCRYPTED")
            if [ -n "$PASSWORD" ]; then
                echo -e "${BLUE}🔑 Password: ${YELLOW}$PASSWORD${NC}"
                echo -e "${BLUE}🔐 Encrypted: ${GREEN}$ENCRYPTED${NC}"
            else
                echo -e "${RED}✗ Failed to decrypt password${NC}"
            fi
            exit 0
        fi
    done < "$PASSWORDS_FILE"
    
    if [ "$FOUND" = false ]; then
        echo -e "${RED}✗ User $TARGET_EMAIL not found${NC}"
        echo -e "${YELLOW}Available users:${NC}"
        grep "EMAIL:" "$PASSWORDS_FILE" | sed 's/EMAIL: /  📧 /' | sort
        exit 1
    fi
else
    # Treat as encrypted hex string
    ENCRYPTED_STRING="$1"
    echo -e "\n${CYAN}Decrypting provided hex string:${NC}"
    echo -e "${CYAN}===============================${NC}"
    echo -e "${BLUE}🔐 Encrypted: ${GREEN}$ENCRYPTED_STRING${NC}"
    
    PASSWORD=$(decrypt_password "$ENCRYPTED_STRING")
    if [ -n "$PASSWORD" ]; then
        echo -e "${BLUE}🔑 Decrypted: ${YELLOW}$PASSWORD${NC}"
    else
        echo -e "${RED}✗ Failed to decrypt the provided string${NC}"
        echo -e "${YELLOW}Make sure the encrypted string is valid hex.${NC}"
        exit 1
    fi
fi

echo -e "\n${CYAN}================================================${NC}"