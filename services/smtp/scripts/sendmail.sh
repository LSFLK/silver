#!/bin/bash

# --- init ---
CONTAINER_NAME="smtp-test"
SPOOL_FILE="/var/mail/testuser"
RECIPIENT="testuser@localhost"
SENDER="admin@host.com"

UNIQUE_ID=$(date +%s)-$(uuidgen | cut -c-8)
SUBJECT="Test-ID: $UNIQUE_ID"

# --- Start test ---
echo "Starting test with unique ID: $UNIQUE_ID"

echo "-> Sending test email to the container..."
swaks --to "$RECIPIENT" \
      --from "$SENDER" \
      --server 127.0.0.1:2525 \
      --header "Subject: $SUBJECT" \
      --body "This is a test message."

# Check if swaks command itself failed, swaks will usually give a helpful error msg.
if [ $? -ne 0 ]; then
    echo "Test FAILED: swaks command failed to execute."
    exit 1
fi

# Give the mail server a moment to process and write the email.
sleep 2

# --- Test Verification ---
echo "-> Verifying email receipt inside the container..."

if docker exec "$CONTAINER_NAME" grep -q "$UNIQUE_ID" "$SPOOL_FILE"; then
    echo "Test PASSED: Email successfully received."
    exit 0
else
    echo "Test FAILED: Email with ID $UNIQUE_ID not found in $SPOOL_FILE."
    exit 1
fi