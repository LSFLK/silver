#!/bin/bash
set -e

CONFIG_FILE="/etc/postfix/silver.yaml"

export MAIL_DOMAIN=$(yq -e '.domain' "$CONFIG_FILE")

# -------------------------------
# Environment variables
# -------------------------------
MAIL_DOMAIN=${MAIL_DOMAIN:-example.org}
MAIL_HOSTNAME=${MAIL_HOSTNAME:-mail.$MAIL_DOMAIN}
RELAYHOST=${RELAYHOST:-}

# Path for vmail
VMAIL_DIR="/var/mail/vmail"

# -------------------------------
# Basic Postfix configuration
# -------------------------------
echo "$MAIL_DOMAIN" > /etc/mailname
postconf -e "myhostname = $MAIL_HOSTNAME"
postconf -e "myorigin = /etc/mailname"
postconf -e "mydomain = $MAIL_DOMAIN"
postconf -e "mydestination = localhost.localdomain, localhost"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
postconf -e "mynetworks = 127.0.0.0/8"
postconf -e "relayhost = $RELAYHOST"

# Logging to stdout for Docker
postconf -e "maillog_file = /var/log/mail.log"

# -------------------------------
# TLS / SSL
# -------------------------------
postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem"
postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/$MAIL_DOMAIN/privkey.pem"
postconf -e "smtpd_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
postconf -e "smtpd_use_tls = yes"
postconf -e "smtpd_tls_security_level = may"

# -------------------------------
# SASL authentication via Dovecot
# -------------------------------
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_sasl_security_options = noanonymous"
postconf -e "broken_sasl_auth_clients = yes"

# -------------------------------
# MySQL virtual domains/users/aliases
# -------------------------------
postconf -e "virtual_mailbox_domains = hash:/etc/postfix/virtual-domains"
postconf -e "virtual_mailbox_maps = hash:/etc/postfix/virtual-users"
postconf -e "virtual_alias_maps = hash:/etc/postfix/virtual-aliases"

# Compile hash maps
postmap /etc/postfix/virtual-domains || true
postmap /etc/postfix/virtual-users || true
postmap /etc/postfix/virtual-aliases || true

# LMTP delivery to Dovecot
postconf -e "virtual_transport = lmtp:unix:private/dovecot-lmtp"
postconf -e "virtual_minimum_uid = 5000"
postconf -e "virtual_uid_maps = static:5000"
postconf -e "virtual_gid_maps = static:8"

# -------------------------------
# Submission service overrides
# -------------------------------
postconf -M submission/inet="submission inet n - y - - smtpd"
postconf -P submission/inet/syslog_name="postfix/submission"
postconf -P submission/inet/smtpd_tls_security_level="encrypt"
postconf -P submission/inet/smtpd_sasl_auth_enable="yes"
postconf -P submission/inet/smtpd_tls_auth_only="yes"
postconf -P submission/inet/smtpd_relay_restrictions="permit_sasl_authenticated,reject"
postconf -P submission/inet/smtpd_milters="inet:rspamd-server:11332,inet:opendkim-server:8891"

# -------------------------------
# Milter (Rspamd + DKIM)
# -------------------------------
postconf -e "milter_protocol = 6"
postconf -e "milter_default_action = accept"
postconf -e "smtpd_milters = inet:rspamd-server:11332,inet:opendkim-server:8891"
postconf -e "non_smtpd_milters = inet:rspamd-server:11332,inet:opendkim-server:8891"

# -------------------------------
# Throttling / Abuse control
# -------------------------------
postconf -e "smtpd_client_connection_rate_limit = 10"       # Number of new connections a client (IP) can make per time unit(60s).
postconf -e "smtpd_client_message_rate_limit = 100"         # Number of messages a client can send per time unit.
postconf -e "smtpd_client_recipient_rate_limit = 200"       # Number of recipients a client can send to per time unit.
postconf -e "smtpd_recipient_limit = 50"                    # Max number of recipients per message.
postconf -e "anvil_rate_time_unit = 60s"                    # Time unit for rate limiting.
postconf -e "smtpd_client_connection_count_limit = 20"      # Number of simultaneous connections a client can make.

# -------------------------------
# vmail user/group and directories
# -------------------------------

if ! getent group mail >/dev/null; then
    groupadd -g 8 mail
fi

if ! id "vmail" &>/dev/null; then
    useradd -r -u 5000 -g 8 -d "$VMAIL_DIR" -s /sbin/nologin -c "Virtual Mail User" vmail
fi

mkdir -p "$VMAIL_DIR"

# Create maildirs from virtual-users map
if [ -f /etc/postfix/virtual-users ]; then
    cut -f1 /etc/postfix/virtual-users | while read email; do
        local_part=$(echo "$email" | cut -d'@' -f1)
        mkdir -p "$VMAIL_DIR/$local_part"/{new,cur,tmp}
        chown -R vmail:mail "$VMAIL_DIR/$local_part"
        chmod -R 755 "$VMAIL_DIR/$local_part"
    done
fi

echo "=== Maildirs created for all virtual users ==="

# -------------------------------
# Fix for DNS resolution in chroot
# -------------------------------
mkdir -p /var/spool/postfix/etc
cp /etc/host.conf /etc/resolv.conf /etc/services /var/spool/postfix/etc/
chmod 644 /var/spool/postfix/etc/*

# -------------------------------
# Start Postfix
# -------------------------------
echo "=== Starting Postfix ==="
service postfix start

# Keep container running
sleep infinity