#!/bin/bash
set -e

# This script is a placeholder for any first-run initializations.
# For this basic Dovecot setup, we primarily rely on Dovecot's
# own mechanisms and the CMD to start the service.

# Example: If you were to copy default configs only if /etc/dovecot is empty:
# if [ -z "$(ls -A /etc/dovecot)" ] && [ -d "/opt/default_config/dovecot" ]; then
#   echo "Populating empty /etc/dovecot with default configuration..."
#   cp -r /opt/default_config/dovecot/* /etc/dovecot/
# fi
# However, in this Dockerfile, we COPY configs directly, so the above is not needed.

echo "Executing command: $@"
exec "$@"