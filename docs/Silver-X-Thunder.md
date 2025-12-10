# Intergrating WSO2 Thunder into LSF Silver

### This document outlines the steps to integrate WSO2 Thunder(Identity Provider) into LSF Silver(Email Service).

## Integration of OAUTH2 as Success/Failure Database

### 1. Configure Thunder as an Identity Provider
- Set up WSO2 Thunder by downloading the release artifact or using the official Docker image. Refer to the [WSO2 Thunder README](https://github.com/asgardeo/thunder/blob/main/README.md)
- Create a new application in Thunder. The example curl command below demonstrates how to create an application using the Thunder API:

```bash
curl -kL -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' https://localhost:8090/applications \
-d '{
    "name": "Test Sample App",
    "description": "Initial testing App",
    "client_id": "test-sample-app",        
    "client_secret": "test-sample-app-secret",         
    "redirect_uris": [
        "https://localhost:3000"
    ],
    "grant_types": [
        "client_credentials"
    ],
    "token_endpoint_auth_method": [
        "client_secret_basic",
        "client_secret_post"
    ],
    "auth_flow_graph_id": "auth_flow_config_basic"
}'
```
- Then create a new user in Thunder. The example curl command below demonstrates how to create a user using the Thunder API:

```bash
curl -k --location 'https://localhost:8090/users' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--data-raw '{
 "organizationUnit": "456e8400-e29b-41d4-a716-446655440001",
 "type": "superhuman",
 "attributes": {
   "username": "testuser",
   "password": "testuser123",
   "email": "testuser@example.com",
   "firstName": "Test",
   "lastName": "User",
   "age": 1234,
   "address": {
     "city": "Colombo",
     "zip": "00100"
   },
   "mobileNumber": "+94712345678"
 }
}'
```
- Seed (populate) initial data into the database.(If you are using the Docker image with basic configuration, run the following command to seed the database inside the container). 
```bash
docker exec -it <container_name> /bin/bash
```
```bash
sh scripts/seed_data.sh \
  -type sqlite \
  -seed dbscripts/thunderdb/seed_data_sqlite.sql \
  -path repository/database/thunderdb.db
```
- Then, try to log using the user created above. The example curl command below demonstrates how to log in using the Thunder API:

```bash
curl -kL -H 'Accept: application/json' -H 'Content-Type: application/json' \
https://localhost:8090/flow/execute \
-d '{
 "applicationId": "f8e7046a-7968-4769-9b70-9552b3b98c38",
 "flowType": "AUTHENTICATION",
 "inputs": {
   "username": "testuser",
   "password": "testuser123"
 }
}'
```
- For testing purposes, you need to get the "assertion" from the response of the above command. This assertion part can be used as JWT token for OAUTH2 authentication.
- You need to create the PEM file for the public key of the Thunder server. Get the public key from the below curl command:

```bash
curl -k https://localhost:8090/oauth2/jwks
```
- Use the first value in the "keys" array to create a PEM file. You can use this website to convert the JWK key to PEM format: [JWK to PEM Converter](https://8gwifi.org/jwkconvertfunctions.jsp).


### 2. Configure Raven to use Thunder for authentication
Raven is now the IMAP/LMTP/SASL server for Silver, replacing Dovecot. Raven integrates with Thunder for user authentication.

- Raven is configured via the `delivery.yaml` configuration file mounted in the docker-compose setup
- The configuration allows Raven to authenticate users against Thunder's API
- Raven provides:
  - **SASL authentication** for Postfix SMTP (via Unix socket at `/var/spool/postfix/private/auth`)
  - **LMTP service** for mail delivery (on port 24)
  - **IMAP service** for mail retrieval (on ports 143 and 993)

### 3. Test the authentication
- Use a mail client to connect to the IMAP server and test authentication with Thunder-created users
- Configure your mail client with:
  - IMAP server: your domain (port 143 for STARTTLS or 993 for SSL/TLS)
  - Username: the email address created in Thunder (e.g., `testuser@example.com`)
  - Password: the password set when creating the user in Thunder