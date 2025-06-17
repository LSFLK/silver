#!/bin/bash

CONTAINER_NAME="smtp-test"
SPOOL_FILE="/var/mail/testuser"
RECIPIENT="testuser@localhost"
SENDER="admin@host.com"

UNIQUE_ID=$(date +%s)-$(uuidgen | cut -c-8)
SUBJECT="Test-ID: $UNIQUE_ID"

echo "Starting test with unique ID: $UNIQUE_ID"

echo "-> Sending test email to the container..."
swaks --to "$RECIPIENT" \
      --from "$SENDER" \
      --server 127.0.0.1:2525 \
      --header "Subject: $SUBJECT" \
      --body "This is a test message."

# Check if swaks command itself failed
if [ $? -ne 0 ]; then
    echo "Test FAILED: swaks command failed to execute."
    exit 1
fi

# Give the mail server a moment to process and write the email.
sleep 2

# --- Test Verification ---
# 3. Check if the email was received inside the container.
echo "-> Verifying email receipt inside the container..."

# We use 'docker exec' to run 'grep -q' inside the container.
# 'grep -q' is "quiet". It doesn't print output, it just returns
# an exit code: 0 if the text is found, 1 if it's not.
if docker exec "$CONTAINER_NAME" grep -q "$UNIQUE_ID" "$SPOOL_FILE"; then
    # Exit code was 0, so grep found the unique ID.
    echo "Test PASSED: Email successfully received."
    exit 0
else
    # Exit code was not 0, so grep did not find the ID.
    echo "Test FAILED: Email with ID $UNIQUE_ID not found in $SPOOL_FILE."
    exit 1
fi