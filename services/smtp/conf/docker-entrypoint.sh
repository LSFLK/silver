#!/bin/bash

set -e

echo "INFO: Initializing Postfix configuration..."

# postfix config 
postconf -e "myhostname=${MYHOSTNAME}"
postconf -e "mydestination=${MYDESTINATION}"
postconf -e "inet_interfaces=${INET_INTERFACES}"

echo "INFO: Running 'postfix check'..."

if ! postfix check; then
    echo "ERROR: 'postfix check' found errors. Exiting." >&2
    exit 1
fi

echo "INFO: 'postfix check' completed successfully."

echo "INFO: Starting Postfix service..."
exec "$@"
