# Dovecot IMAP Server in Docker

This project provides a Dockerized Dovecot IMAP server based on Ubuntu 22.04, allowing you to run an IMAP email server locally for testing and development.

## Adding environment variables
Create a `.env.conf` file in the `conf` directory with the following content:

```bash
MAIL_DOMAIN=
AZP=<your_azp>
KEY_ID=<your_key_id>
```

## Adding the PEM file
- Create a `PEM` file in the `services/imap` directory and add the public key in PEM format. This key is used to verify JWT tokens issued by the Thunder server.

## Adding the certificate file
- Add your TLS certificate files in the `cert` directory. You need to add `cert.pem`, `privkey.pem`, and `chain.pem` files for enabling TLS in Dovecot.

## Testing the IMAP Server with Thunderbird

To test your Dovecot IMAP server:

1. Open **Thunderbird** and add a new email account.

2. Enter the following details:
   - **Your Name:** Any display name you prefer (e.g., "Test User")
   - **Email Address:** `testuser@example.com` (or the email you set)
   - **Password:** `testpass` (default from the Dockerfile)

3. When Thunderbird cannot auto-configure, click **Manual Config**.

4. Enter these manual settings:

| Setting | Value |
|---------|-------|
| Incoming Protocol | IMAP |
| Server Hostname | localhost |
| Port | 143 |
| SSL | None |
| Authentication | Normal password |
| Username | ###### |

5. Complete the setup. Thunderbird will connect to your IMAP server running inside Docker.

- Refresh your Thunderbird inbox to see the new mail.