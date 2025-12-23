# How to setup Mail User Agent (MUA) for Silver Mail Server

This guide will help you set up a Mail User Agent (MUA) to interact with your Silver Mail Server. A MUA is an application that allows users to send, receive, and manage their email.

**Note:** For enhanced security, we recommend using port 993 (IMAPS with SSL/TLS) for incoming mail instead of port 143 (STARTTLS).

## Thunderbird Setup

1. Download and install [Mozilla Thunderbird](https://www.thunderbird.net/).
2. Open Thunderbird and go to `Account Settings` from the menu.
3. Click on `New Account` and select `Mail Account`.
4. Enter your name, email address.
5. Click on `Continue`. Thunderbird will attempt to automatically configure the account settings.
6. If automatic configuration passes, click `Continue` and then enter your password when prompted and click `Continue`.
7. If automatic configuration fails, click on `Manual config` and enter the following settings:
    - **Incoming:** IMAP, `mail.yourdomain.com`, Port: **993**, SSL: **SSL/TLS**, Authentication: Normal password
    - **Outgoing:** SMTP, `mail.yourdomain.com`, Port: 587, SSL: STARTTLS, Authentication: Normal password
    - *Alternative (less secure):* For incoming, you can use Port: 143 with SSL: STARTTLS
8. Click on `Re-test` to verify the settings.
9. Once verified, click on `Continue` to finish the setup.

## Apple Mail Setup (macOS)

1. Open Apple Mail application.
2. Go to `Mail` → `Add Account` (or `Accounts` in System Settings for macOS Ventura+).
3. Select `Other Mail Account` and click `Continue`.
4. Enter your name, email address, and password, then click `Sign In`.
5. If automatic configuration fails, enter the following settings:
    - **Incoming Mail Server (IMAP):**
      - Hostname: `mail.yourdomain.com`
      - Port: **993** (recommended) or 143
      - Use SSL: **SSL/TLS** (for port 993) or STARTTLS (for port 143)
      - Username: your full email address
    - **Outgoing Mail Server (SMTP):**
      - Hostname: `mail.yourdomain.com`
      - Port: 587
      - Use SSL: STARTTLS
      - Username: your full email address
6. Click `Sign In` to complete the setup.

## Outlook Setup (Windows/Mac)

1. Open Microsoft Outlook.
2. Go to `File` → `Add Account`.
3. Enter your email address and click `Connect`.
4. Choose `IMAP/POP` when prompted.
5. Enter your password and configure the following settings:
    - **Incoming Mail (IMAP):**
      - Server: `mail.yourdomain.com`
      - Port: **993** (recommended) or 143
      - Encryption: **SSL/TLS** (for port 993) or STARTTLS (for port 143)
      - Authentication: Normal password
    - **Outgoing Mail (SMTP):**
      - Server: `mail.yourdomain.com`
      - Port: 587
      - Encryption: STARTTLS
      - Authentication: Normal password
6. Click `Next` and then `Finish` to complete the setup.

## Gmail App (Mobile)

### iOS
1. Open the Gmail app.
2. Tap on your profile icon → `Add another account`.
3. Select `Other`.
4. Enter your email address and tap `Next`.
5. Select `IMAP` as the account type.
6. Enter your password and tap `Next`.
7. Configure the incoming server:
    - Server: `mail.yourdomain.com`
    - Port: **993** (recommended) or 143
    - Security type: **SSL/TLS** (for port 993) or STARTTLS (for port 143)
8. Configure the outgoing server:
    - Server: `mail.yourdomain.com`
    - Port: 587
    - Security type: STARTTLS
9. Tap `Next` to complete the setup.

### Android
1. Open the Gmail app.
2. Tap the menu icon → `Settings` → `Add account`.
3. Select `Other`.
4. Enter your email address and tap `Manual setup`.
5. Select `Personal (IMAP)`.
6. Enter your password and tap `Next`.
7. Configure the incoming server:
    - Server: `mail.yourdomain.com`
    - Port: **993** (recommended) or 143
    - Security type: **SSL/TLS** (for port 993) or STARTTLS (for port 143)
8. Configure the outgoing server:
    - Server: `mail.yourdomain.com`
    - Port: 587
    - Security type: STARTTLS
9. Tap `Next` to complete the setup.

## Common Server Settings

Use these settings for any email client:

| Setting | Value |
|---------|-------|
| **IMAP Server** | mail.yourdomain.com |
| **IMAP Port** | **993 (SSL/TLS)** ✅ Recommended<br>143 (STARTTLS) |
| **SMTP Server** | mail.yourdomain.com |
| **SMTP Port** | 587 (STARTTLS) ✅ Recommended<br>465 (SSL/TLS) |
| **Username** | Your full email address |
| **Authentication** | Normal password |

**Security Recommendation:** Always use port 993 with SSL/TLS for IMAP connections to ensure your email is encrypted from the start of the connection.

## Troubleshooting

- Ensure your firewall allows connections on ports 143, 587, **993**, and 465.
- Verify your email address and password are correct.
- Check that your mail server's SSL certificate is valid.
- **If you experience connection issues with port 993, verify that:**
  - Your SSL certificate is properly configured
  - Port 993 is not blocked by your firewall or ISP
  - Your email client supports SSL/TLS connections
- For legacy systems that don't support SSL/TLS properly, you can fall back to port 143 with STARTTLS, but this is less secure.
