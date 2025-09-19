#!/bin/bash
set -e

CONFIG_FILE="/etc/dovecot/silver.yaml"

export MAIL_DOMAIN=$(yq -e '.domain' "$CONFIG_FILE")

MAIL_DOMAIN=${MAIL_DOMAIN:-example.org}

# Generate Lua authentication script
echo "Generating Lua authentication script..."
/generate_lua.sh

# Generate Dovecot configuration dynamically
cat > /etc/dovecot/dovecot.conf <<EOF
plugin {
  # Enable quota for Maildir
  quota = maildir:User quota
  quota_rule = *:storage=1G
  quota_warning = storage=90%% warning

  # POP3-specific settings
  pop3_client_workarounds = outlook-no-nuls oe-ns-eoh
  pop3_uidl_format = %n
  pop3_read_only = yes
}

# POP3-specific protocol settings
protocol pop3 {
  mail_plugins = $mail_plugins
  pop3_deleted_flag = Deleted
}

protocol lmtp {
  mail_plugins = $mail_plugins quota
}

protocol imap {
  mail_plugins = $mail_plugins quota
}

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}

disable_plaintext_auth = no

mail_location = maildir:/var/mail/vmail/%n
mail_uid = 5000
mail_gid = 8

auth_mechanisms = plain login oauthbearer xoauth2
protocols = imap lmtp pop3

ssl = required
ssl_cert = </etc/letsencrypt/live/${MAIL_DOMAIN}/fullchain.pem
ssl_key  = </etc/letsencrypt/live/${MAIL_DOMAIN}/privkey.pem

ssl_protocols = !SSLv2 !SSLv3
ssl_min_protocol = TLSv1.2
ssl_cipher_list = HIGH:!aNULL:!MD5

passdb {
  driver = lua
  args = file=/etc/dovecot/auth_api.lua blocking=yes
}

userdb {
  driver = lua
  args = file=/etc/dovecot/auth_api.lua blocking=yes
}

service imap-login {
  inet_listener imap {
    port = 143
  }

  inet_listener imaps {
    port = 993
    ssl = yes
  }
}

service pop3-login {
  inet_listener pop3 {
    port = 110
  }

  inet_listener pop3s {
    port = 995
    ssl = yes
  }
}

log_path = /dev/stderr
info_log_path = /dev/stderr
debug_log_path = /dev/stderr

auth_debug = yes
auth_debug_passwords = yes
auth_verbose = yes
auth_verbose_passwords = yes
mail_debug = yes
EOF

# Start Dovecot
echo "Starting Dovecot..."
exec dovecot -F