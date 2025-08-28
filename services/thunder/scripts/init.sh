#!/bin/bash

if [ -f ./thunder/scripts/.env ]; then
  set -o allexport
  source ./thunder/scripts/.env
  set +o allexport
  echo "Environment variables loaded from .env file"
else
  echo ".env not found!"
  exit 1
fi

echo "Creating application..."
curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  https://$THUNDER_HOST:$THUNDER_PORT/applications \
  -d "{
    \"name\": \"$APP_NAME\",
    \"description\": \"$APP_DESCRIPTION\",
    \"client_id\": \"$APP_CLIENT_ID\",
    \"client_secret\": \"$APP_CLIENT_SECRET\",
    \"redirect_uris\": [\"https://localhost:3000\"],
    \"grant_types\": [\"client_credentials\"],
    \"token_endpoint_auth_method\": [\"client_secret_basic\", \"client_secret_post\"],
    \"auth_flow_graph_id\": \"auth_flow_config_basic\"
  }"

echo -e "\n\nCreating user..."
curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  https://$THUNDER_HOST:$THUNDER_PORT/users \
  -d "{
    \"organizationUnit\": \"456e8400-e29b-41d4-a716-446655440001\",
    \"type\": \"superhuman\",
    \"attributes\": {
      \"username\": \"$USER_USERNAME\",
      \"password\": \"$USER_PASSWORD\",
      \"email\": \"$USER_EMAIL\",
      \"firstName\": \"$USER_FIRST_NAME\",
      \"lastName\": \"$USER_LAST_NAME\",
      \"age\": $USER_AGE,
      \"address\": $USER_ADDRESS,
      \"mobileNumber\": \"$USER_PHONE\"
    }
  }"
