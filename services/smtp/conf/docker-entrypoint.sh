#!/bin/bash

set -e

echo "INFO: Initializing Postfix configuration..."

# postfix config 
postconf -e "myhostname = ${MYHOSTNAME}"
postconf -e "mydestination = ${MYDESTINATION}"
postconf -e "inet_interfaces = ${INET_INTERFACES}"
postconf -e "smtpd_tls_cert_file = /etc/postfix/tls/fullchain.pem"
postconf -e "smtpd_tls_key_file = /etc/postfix/tls/privkey.pem"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination"

echo "INFO: Running 'postfix check'..."

if ! postfix check; then
    echo "ERROR: 'postfix check' found errors. Exiting." >&2
    exit 1
fi

echo "INFO: 'postfix check' completed successfully."

echo "INFO: Starting Postfix service..."
exec "$@"
