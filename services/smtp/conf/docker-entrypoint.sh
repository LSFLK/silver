#!/bin/bash

set -e

echo "INFO: Initializing Postfix configuration..."

# postfix config 
postconf -e "myhostname = ${MYHOSTNAME}"
postconf -e "mydestination = ${MYDESTINATION}"
postconf -e "inet_interfaces = ${INET_INTERFACES}"
# TLS
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtp_tls_loglevel = 1"
postconf -e "smtpd_tls_cert_file = ${TLSPATH}/${URL}/fullchain.pem"
postconf -e "smtpd_tls_key_file = ${TLSPATH}/${URL}/privkey.pem"
# SASL
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination"

echo "INFO: Running 'postfix check'..."
postfix check

echo "INFO: 'postfix check' completed successfully."

echo "INFO: Starting Postfix service..."
exec "$@"
