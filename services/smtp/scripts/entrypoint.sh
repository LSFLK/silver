#!/bin/bash
set -e

CONFIG_FILE="/etc/postfix/silver.yaml"
export MAIL_DOMAIN=$(yq -e '.domain' "$CONFIG_FILE")

# Fallback values
MAIL_DOMAIN=${MAIL_DOMAIN:-example.org}
MAIL_HOSTNAME=${MAIL_HOSTNAME:-mail.$MAIL_DOMAIN}
RELAYHOST=${RELAYHOST:-}

echo "$MAIL_DOMAIN" > /etc/mailname

# # vmail directories and user/group
# VMAIL_DIR="/var/mail/vmail"
# mkdir -p "$VMAIL_DIR"
# chown -R vmail:mail "$VMAIL_DIR"
# chmod 755 "$VMAIL_DIR"

# if ! getent group mail >/dev/null; then
#     groupadd -g 8 mail
# fi

# if ! id "vmail" &>/dev/null; then
#     useradd -r -u 5000 -g 8 -d "$VMAIL_DIR" -s /sbin/nologin -c "Virtual Mail User" vmail
# fi

# SQLite database path
DB_FILE="/app/data/databases/shared.db"

echo "=== Waiting for SQLite database to exist: $DB_FILE ==="
while [ ! -f "$DB_FILE" ]; do
    echo "Database not found, sleeping 1s..."
    sleep 1
done

# Set proper permissions
chown postfix:postfix "$DB_FILE"
chmod 640 "$DB_FILE"

# Fix DNS resolution in Postfix chroot
mkdir -p /var/spool/postfix/etc
cp /etc/host.conf /etc/resolv.conf /etc/services /var/spool/postfix/etc/
chmod 644 /var/spool/postfix/etc/*

# Verify Postfix configuration (optional)
echo "=== Postfix virtual settings ==="
postconf virtual_mailbox_domains
postconf virtual_mailbox_maps
postconf virtual_mailbox_base
postconf virtual_transport

# Start Postfix in foreground (recommended for Docker)
echo "=== Starting Postfix in foreground ==="
exec postfix start-fg
