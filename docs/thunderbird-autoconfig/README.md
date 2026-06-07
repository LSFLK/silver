# Thunderbird Autoconfiguration for openmail.lk

This directory contains the files needed to register **openmail.lk** as a verified mail provider in Mozilla Thunderbird's ISPDB (Internet Service Provider Database).

Once listed, Thunderbird will automatically detect and configure email accounts for `@openmail.lk` addresses — no manual server settings required by end users.

---

## 📁 Files

| File | Purpose |
|------|---------|
| `config-v1.1.xml` | Thunderbird ISPDB autoconfig XML — the core configuration file |
| `config-v1.1.xml` | Self-hosted fallback (`https://autoconfig.openmail.lk/mail/config-v1.1.xml`) |
| `../thunderbird-oauth-example/manifest.json` | OAuth2 provider extension template (future) |

---

## 🎯 ISPDB Submission Process

### Step 1: Verify the autoconfig XML

Validate the XML structure:

```bash
xmllint --noout docs/thunderbird-autoconfig/config-v1.1.xml
```

Test with Thunderbird:
1. Open Thunderbird
2. Go to `Account Settings` → `New Account` → `Mail Account`
3. Enter a test `@openmail.lk` address
4. Thunderbird should read the config and auto-fill server settings

### Step 2: Self-host the autoconfig file (quick path)

Thunderbird first checks for a self-hosted config before falling back to the ISPDB.

Serve the file at:
```
https://autoconfig.openmail.lk/mail/config-v1.1.xml
```

**Nginx example:**
```nginx
server {
    server_name autoconfig.openmail.lk;
    root /var/www/autoconfig;
    
    location /mail/ {
        alias /var/www/autoconfig/;
        default_type text/xml;
        add_header Content-Type "text/xml; charset=utf-8";
    }
}
```

**DNS record required:**
```
autoconfig.openmail.lk.  IN  A  <your-server-ip>
```

### Step 3: Submit to Mozilla Thunderbird ISPDB (official listing)

1. **Create a Bugzilla account** at [bugzilla.mozilla.org](https://bugzilla.mozilla.org)
2. **File a new bug** under:
   - **Product:** `Webtools`
   - **Component:** `ISPDB`
3. **Attach the validated `config-v1.1.xml`** to the bug
4. **Include this information in the bug description:**
   - Provider name: OpenMail Sri Lanka
   - Domain: openmail.lk
   - Confirmation that `openmail.lk` is a live email service
   - IMAP/SMTP server hostnames and ports
   - Link to support documentation
   - Confirmation that SSL/TLS certificates are valid
5. **Wait for Mozilla review** — typically 1–4 weeks
6. **Once approved**, Thunderbird (~128+) will auto-configure `@openmail.lk` accounts

**Reference:** [Thunderbird:Autoconfiguration — Mozilla Wiki](https://wiki.mozilla.org/Thunderbird:Autoconfiguration)

---

## 🔧 How Thunderbird Autoconfig Works

Thunderbird attempts to find configuration in this order:

1. **ISPDB** — Central database at `autoconfig.thunderbird.net` (requires Bugzilla submission)
2. **Self-hosted autoconfig** — `https://autoconfig.<domain>/mail/config-v1.1.xml`
3. **Exchange AutoDiscover** — For Microsoft Exchange servers
4. **Guess** — Thunderbird probes common hostnames and ports

**Priority:** File the ISPDB bug AND set up the self-hosted URL. The self-hosted option works immediately while the ISPDB submission is under review.

---

## 📋 openmail.lk Mail Server Settings

| Setting | Primary | Fallback |
|---------|---------|----------|
| **IMAP Server** | `mail.openmail.lk:993` | `mail.openmail.lk:143` |
| **IMAP Security** | SSL/TLS | STARTTLS |
| **SMTP Server** | `mail.openmail.lk:587` | `mail.openmail.lk:465` |
| **SMTP Security** | STARTTLS | SSL/TLS |
| **Username** | Full email address | Full email address |
| **Authentication** | Normal password (cleartext over TLS) | — |

---

## 🔮 Future: OAuth2 Support

Once Thunder IDP OAuth2 is fully deployed for mail authentication:

1. Update `docs/thunderbird-oauth-example/manifest.json` with real endpoints
2. Uncomment the `<oAuth2>` block in `config-v1.1.xml`
3. Package and distribute the Thunderbird OAuth extension
4. Update the ISPDB submission to include OAuth2 configuration

---

## 📚 References

- [Thunderbird Autoconfiguration (Mozilla Wiki)](https://wiki.mozilla.org/Thunderbird:Autoconfiguration)
- [ISPDB Configuration Format](https://wiki.mozilla.org/Thunderbird:Autoconfiguration:ConfigFileFormat)
- [Thunderbird Bugzilla — ISPDB Component](https://bugzilla.mozilla.org/enter_bug.cgi?product=Webtools&component=ISPDB)
