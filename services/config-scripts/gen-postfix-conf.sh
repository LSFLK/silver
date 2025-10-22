#!/bin/bash
#
# This script initializes the postfix config files

# --- Sanity Checks & Configuration ---
set -euo pipefail

# Define constant paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly SILVER_YAML_FILE="${ROOT_DIR}/conf/silver.yaml"
readonly CONFIGS_PATH="${ROOT_DIR}/services/silver-config/gen/postfix"
readonly DKIM_SELECTOR=mail

# --- Main Logic ---
readonly MAIL_DOMAIN=$(grep -m 1 '^domain:' "${SILVER_YAML_FILE}" | sed 's/domain: //' | xargs)
#export RELAYHOST=$(yq -e '.relayhost' "$SILVER_YAML_FILE" || echo "")

# --- Derived variables ---
MAIL_HOSTNAME=${MAIL_HOSTNAME:-mail.$MAIL_DOMAIN}
VMAIL_DIR="/var/mail/vmail"

mkdir -p ${CONFIGS_PATH}

# Create required files
echo "${MAIL_DOMAIN} OK" >"$CONFIGS_PATH/virtual-domains"
: >"$CONFIGS_PATH/virtual-aliases"
: >"$CONFIGS_PATH/virtual-users"

echo -e "SMTP configuration files prepared"
echo " - $CONFIGS_PATH/virtual-domains (with '${MAIL_DOMAIN} OK')"
echo " - $CONFIGS_PATH/virtual-aliases (empty)"
echo " - $CONFIGS_PATH/virtual-users (empty)"

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



# TLS parameters
smtpd_tls_cert_file = /etc/letsencrypt/live/${MAIL_DOMAIN}/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/${MAIL_DOMAIN}//privkey.pem
smtpd_tls_security_level = may

smtp_tls_CApath=/etc/ssl/certs
smtp_tls_security_level=may
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache


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
maillog_file = /dev/stdout
smtpd_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtpd_use_tls = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes
virtual_mailbox_domains = hash:/etc/postfix/virtual-domains
virtual_mailbox_maps = hash:/etc/postfix/virtual-users
virtual_alias_maps = hash:/etc/postfix/virtual-aliases
virtual_mailbox_base = "${VMAIL_DIR}"
virtual_transport = lmtp:raven:24
virtual_minimum_uid = 5000
virtual_uid_maps = static:5000
virtual_gid_maps = static:8
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
