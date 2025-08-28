#!/bin/bash

# Default values
MAIL_DOMAIN=${MAIL_DOMAIN:-aravindahwk.org}
DKIM_SELECTOR=${DKIM_SELECTOR:-mail}
DKIM_KEY_SIZE=${DKIM_KEY_SIZE:-2048}

# Create key directory
mkdir -p /etc/opendkim/keys/$MAIL_DOMAIN

# Generate DKIM keys if they don't exist
if [ ! -f /etc/opendkim/keys/$MAIL_DOMAIN/$DKIM_SELECTOR.private ]; then
    echo "Generating DKIM keys for $MAIL_DOMAIN..."
    
    # Generate the keys
    if opendkim-genkey -b $DKIM_KEY_SIZE -s $DKIM_SELECTOR -d $MAIL_DOMAIN -D /etc/opendkim/keys/$MAIL_DOMAIN/; then
        echo "DKIM keys generated successfully."
        
        # Set proper permissions
        chown -R opendkim:opendkim /etc/opendkim/keys
        chmod 600 /etc/opendkim/keys/$MAIL_DOMAIN/$DKIM_SELECTOR.private
        chmod 644 /etc/opendkim/keys/$MAIL_DOMAIN/$DKIM_SELECTOR.txt
        
        echo "DKIM keys generated. Add this TXT record to your DNS:"
        echo "Record name: $DKIM_SELECTOR._domainkey.$MAIL_DOMAIN"
        echo "Record value:"
        cat /etc/opendkim/keys/$MAIL_DOMAIN/$DKIM_SELECTOR.txt
        echo ""
    else
        echo "ERROR: Failed to generate DKIM keys. Check if openssl is installed."
        echo "Attempting to install openssl..."
        apt-get update && apt-get install -y openssl
        
        # Retry key generation
        echo "Retrying key generation..."
        if opendkim-genkey -b $DKIM_KEY_SIZE -s $DKIM_SELECTOR -d $MAIL_DOMAIN -D /etc/opendkim/keys/$MAIL_DOMAIN/; then
            chown -R opendkim:opendkim /etc/opendkim/keys
            chmod 600 /etc/opendkim/keys/$MAIL_DOMAIN/$DKIM_SELECTOR.private
            chmod 644 /etc/opendkim/keys/$MAIL_DOMAIN/$DKIM_SELECTOR.txt
            echo "DKIM keys generated on retry."
        else
            echo "ERROR: Still failed to generate DKIM keys. Exiting."
            exit 1
        fi
    fi
fi

# Update configuration files with dynamic domain
sed -i "s/$MAIL_DOMAIN/$MAIL_DOMAIN/g" /etc/opendkim/TrustedHosts
sed -i "s/$MAIL_DOMAIN/$MAIL_DOMAIN/g" /etc/opendkim/KeyTable
sed -i "s/$MAIL_DOMAIN/$MAIL_DOMAIN/g" /etc/opendkim/SigningTable
sed -i "s/$DKIM_SELECTOR/$DKIM_SELECTOR/g" /etc/opendkim/KeyTable
sed -i "s/$DKIM_SELECTOR/$DKIM_SELECTOR/g" /etc/opendkim/SigningTable

# Start OpenDKIM
echo "Starting OpenDKIM..."
exec opendkim -f