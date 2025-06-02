#!/bin/bash

set -e

echo "INFO: Initializing Postfix configuration..."

# TODO remove current defaults,  only for localhost setup
postconf -e "myhostname=${MYHOSTNAME:-mail.local.com}"
postconf -e "mydestination=${MYDESTINATION:-localhost.localdomain, localhost}"
postconf -e "inet_interfaces=${INET_INTERFACES:-all}"

echo "INFO: Running 'postfix check'..."

if ! postfix check; then
    echo "ERROR: 'postfix check' found errors. Exiting." >&2
    exit 1
fi
echo "INFO: 'postfix check' completed successfully."

echo "INFO: Starting Postfix service..."
exec "$@"
