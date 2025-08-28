#!/bin/bash

set -e

echo "INFO: Initializing Postfix configuration..."

# postfix config 
postconf -e "maillog_file = /dev/stdout"
postconf -e "myhostname = ${MYHOSTNAME}"
postconf -e "mydestination = ${MYDESTINATION}"
postconf -e "mydomain = ${URL}"
postconf -e "myorigin = ${URL}"
postconf -e "inet_interfaces = ${INET_INTERFACES}"
postconf -e "smtp_helo_name = ${MYHOSTNAME}"

# TLS
postconf -e "smtpd_tls_security_level = may" #implicit TLS, for explicit set to encrypt
postconf -e "smtp_tls_loglevel = 1" 
postconf -e "smtpd_tls_cert_file = /le-ssl/letsencrypt/live/${URL}/fullchain.pem"
postconf -e "smtpd_tls_key_file = /le-ssl/letsencrypt/live/${URL}/privkey.pem"
# SASL - This will break smtp tests for a bit until auth is sorted. Comment out to see passing results
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_sasl_security_options = noanonymous"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination"
postconf -e "broken_sasl_auth_clients = yes"
#mailbox settings
postconf -e "virtual_mailbox_domains = ${URL}"
postconf -e "virtual_transport = lmtp:unix:private/dovecot-lmtp"

#milter settings
postconf -e "milter_default_action = accept"
postconf -e "milter_protocol = 6"
#milters
postconf -e "smtpd_milters = inet:rspamd:11332 inet:opendkim:8891"
postconf -e "non_smtpd_milters = inet:rspamd:11332 inet:opendkim:8891"

#copy DNS files.
mkdir -p /var/spool/postfix/etc/
cp /etc/host.conf /etc/resolv.conf /etc/services /var/spool/postfix/etc/
cp /etc/host.conf /etc/resolv.conf /etc/services /var/spool/postfix/etc/
#chmod 1777 -R /var/spool/postfix/etc
#chmod o+r /etc/resolv.conf

echo "INFO: Running 'postfix check'..."
postfix check

echo "INFO: 'postfix check' completed successfully."

echo "INFO: Starting Postfix service..."
exec "$@"
