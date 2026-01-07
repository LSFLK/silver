#!/bin/bash
#
# This script initializes the postfix config files

# --- Sanity Checks & Configuration ---
set -euo pipefail

# Define constant paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly SILVER_YAML_FILE="${ROOT_DIR}/conf/silver.yaml"
readonly CONFIGS_PATH="${ROOT_DIR}/services/silver-config/postfix"
readonly DKIM_SELECTOR=mail

# --- Main Logic ---
# Extract primary (first) domain from the domains list in silver.yaml
readonly MAIL_DOMAIN=$(grep -m 1 '^\s*-\s*domain:' "${SILVER_YAML_FILE}" | sed 's/.*domain:\s*//' | xargs)
#export RELAYHOST=$(yq -e '.relayhost' "$SILVER_YAML_FILE" || echo "")

# --- Derived variables ---
MAIL_HOSTNAME=${MAIL_HOSTNAME:-mail.$MAIL_DOMAIN}

mkdir -p ${CONFIGS_PATH}

# Note: Using SQLite database instead of virtual files
# SQLite configuration files are in silver-config/postfix/sqlite-*.cf

echo -e "SMTP configuration will use SQLite database"
echo " - Database: /app/data/databses/shared.db"
echo " - SQLite configs: $CONFIGS_PATH/sqlite-*.cf"

# --- Generate main.cf content ---
cat >"${CONFIGS_PATH}/main.cf" <<EOF
# See /usr/share/postfix/main.cf.dist for a commented, more complete version


# Debian specific:  Specifying a file name will cause the first
# line of that file to be used as the name.  The Debian default
# is /etc/mailname.
#myorigin = /etc/mailname


biff = no

# appending .domain is the MUA's job.
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

readme_directory = no

# See http://www.postfix.org/COMPATIBILITY_README.html -- default to 3.6 on
# fresh installs.
compatibility_level = 3.6



# TLS parameters - Enhanced Security Configuration
# Certificate configuration
smtpd_tls_cert_file = /etc/letsencrypt/live/${MAIL_DOMAIN}/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/${MAIL_DOMAIN}/privkey.pem
smtpd_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_tls_note_starttls_offer = yes

# TLS Security Level - 'may' allows opportunistic encryption
# Use 'encrypt' to enforce TLS for all connections (may break compatibility with old servers)
smtpd_tls_security_level = may
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# Cipher Configuration - Only AEAD ciphers (GCM, CHACHA20-POLY1305) to prevent LUCKY13
# Excludes all CBC ciphers which are vulnerable to timing attacks
smtpd_tls_mandatory_ciphers = high
smtpd_tls_ciphers = high
smtpd_tls_exclude_ciphers = aNULL, eNULL, EXPORT, DES, RC4, MD5, PSK, aECDH, EDH-DSS-DES-CBC3-SHA, EDH-RSA-DES-CBC3-SHA, KRB5-DES, CBC3-SHA, AES128-SHA, AES256-SHA, AES128-SHA256, AES256-SHA256, ECDHE-RSA-AES128-SHA, ECDHE-RSA-AES256-SHA, ECDHE-RSA-AES128-SHA256, ECDHE-RSA-AES256-SHA384, DHE-RSA-AES128-SHA, DHE-RSA-AES256-SHA, DHE-RSA-AES128-SHA256, DHE-RSA-AES256-SHA256, CAMELLIA128-SHA256, CAMELLIA256-SHA256, DHE-RSA-CAMELLIA128-SHA256, DHE-RSA-CAMELLIA256-SHA256

# TLS session cache and logging
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtpd_tls_loglevel = 1
smtpd_tls_received_header = yes
smtpd_use_tls = yes

# Outbound SMTP TLS settings
smtp_tls_CApath = /etc/ssl/certs
smtp_tls_security_level = may
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_ciphers = high
smtp_tls_exclude_ciphers = aNULL, eNULL, EXPORT, DES, RC4, MD5, PSK, CBC3-SHA, AES128-SHA, AES256-SHA, AES128-SHA256, AES256-SHA256
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtp_tls_loglevel = 1


smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
myhostname = ${MAIL_HOSTNAME}
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
mydestination = localhost.localdomain, localhost
relayhost = 
mynetworks = 127.0.0.0/8
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = ipv4
myorigin = /etc/mailname
mydomain = ${MAIL_DOMAIN}
maillog_file = /var/log/mail.log

# SASL authentication provided by Raven server via Unix socket
smtpd_sasl_type = dovecot
smtpd_sasl_path = inet:raven:12345
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes
virtual_mailbox_domains = sqlite:/etc/postfix/sqlite-virtual-domains.cf
virtual_mailbox_maps = sqlite:/etc/postfix/sqlite-virtual-users.cf
virtual_alias_maps = sqlite:/etc/postfix/sqlite-virtual-aliases.cf
virtual_transport = lmtp:raven:24
milter_protocol = 6
milter_default_action = accept
smtpd_milters = inet:rspamd-server:11332,inet:opendkim-server:8891
non_smtpd_milters = inet:rspamd-server:11332,inet:opendkim-server:8891
smtpd_client_connection_rate_limit = 10
smtpd_client_message_rate_limit = 100
smtpd_client_recipient_rate_limit = 200
smtpd_recipient_limit = 50
anvil_rate_time_unit = 60s
smtpd_client_connection_count_limit = 20
EOF

echo Postfix configuration successfully generated
