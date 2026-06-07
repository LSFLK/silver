# TODO — Thunderbird Verified Mail Provider Submission for openmail.lk

**Issue:** [#52](https://github.com/LSFLK/silver/issues/52)  
**PR:** [#340](https://github.com/LSFLK/silver/pull/340)  
**Target:** Get `@openmail.lk` recognized as a verified mail provider in Mozilla Thunderbird

---

## Phase 1: Self-Hosted Autoconfig (Immediate — No External Approval Needed)

Thunderbird checks `https://autoconfig.<domain>/mail/config-v1.1.xml` first, before falling back to the ISPDB. This works immediately once deployed.

### 1.1 DNS Configuration

- [ ] **Add A record for `autoconfig.openmail.lk`**
  ```
  autoconfig.openmail.lk.  IN  A  72.61.149.137
  ```
  - Owner: DNS admin
  - Verify: `host autoconfig.openmail.lk` → should resolve to `72.61.149.137`

### 1.2 TLS Certificate

- [ ] **Provision TLS certificate for `autoconfig.openmail.lk`**
  ```bash
  # Using certbot (if already deployed in the stack)
  docker compose -f services/docker-compose.yaml run --rm certbot \
    certonly --standalone -d autoconfig.openmail.lk

  # Or expand existing certificate
  docker compose -f services/docker-compose.yaml run --rm certbot \
    certonly --expand -d mail.openmail.lk -d autoconfig.openmail.lk
  ```
  - Owner: Infrastructure admin
  - Verify: `curl -I https://autoconfig.openmail.lk/` → TLS handshake succeeds

### 1.3 Web Server Configuration

- [ ] **Serve the autoconfig XML over HTTPS**
  ```nginx
  server {
      listen 443 ssl;
      server_name autoconfig.openmail.lk;

      ssl_certificate     /etc/letsencrypt/live/openmail.lk/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/openmail.lk/privkey.pem;

      root /var/www/autoconfig;

      location /mail/ {
          alias /var/www/autoconfig/;
          default_type text/xml;
          add_header Content-Type "text/xml; charset=utf-8";
          add_header Access-Control-Allow-Origin "*";
      }

      # Also handle HTTP → HTTPS redirect
      error_page 497 =301 https://$host$request_uri;
  }

  server {
      listen 80;
      server_name autoconfig.openmail.lk;
      return 301 https://$host$request_uri;
  }
  ```
  - Owner: Infrastructure admin
  - Verify: `curl https://autoconfig.openmail.lk/mail/config-v1.1.xml` → returns XML

### 1.4 Deploy the XML File

- [ ] **Copy config-v1.1.xml to the web server**
  ```bash
  scp docs/thunderbird-autoconfig/config-v1.1.xml \
      user@mail.openmail.lk:/var/www/autoconfig/config-v1.1.xml
  ```
  - Owner: Infrastructure admin
  - Verify: `curl -s https://autoconfig.openmail.lk/mail/config-v1.1.xml | grep openmail.lk`

### 1.5 End-to-End Test

- [ ] **Test with Thunderbird**
  1. Open Thunderbird (version 128+)
  2. `File` → `New` → `Existing Mail Account`
  3. Enter: `test@openmail.lk`
  4. Thunderbird should auto-detect IMAP/SMTP settings
  5. Complete setup and send a test email
  - Owner: QA / Developer
  - Verify: Account auto-configures without manual server entry

---

## Phase 2: Mozilla ISPDB Submission (Official Listing — 1–4 Weeks)

This is the official path to get listed in Thunderbird's central ISPDB. Once approved, ALL Thunderbird users worldwide get auto-configuration for `@openmail.lk`.

### 2.1 Pre-Submission Checklist

- [ ] Self-hosted autoconfig is live and verified (Phase 1 complete)
- [ ] `mail.openmail.lk` has valid TLS certificate (not self-signed)
- [ ] IMAP port 993 reachable from the public internet
- [ ] SMTP port 587 reachable from the public internet
- [ ] Support documentation page exists at `https://openmail.lk/support`
- [ ] Setup instructions page exists at `https://openmail.lk/setup`

### 2.2 File Bugzilla Bug

- [ ] **Create Bugzilla account** at [bugzilla.mozilla.org](https://bugzilla.mozilla.org)
  - Owner: Developer

- [ ] **File a new bug**
  - Product: `Webtools`
  - Component: `ISPDB`
  - Summary: `Add OpenMail Sri Lanka (openmail.lk) to ISPDB`
  - Owner: Developer

- [ ] **Bug description must include:**
  ```
  Provider Name: OpenMail Sri Lanka
  Domain: openmail.lk

  This is a live, production email service based in Sri Lanka.

  Mail Server Configuration:
  - Incoming (IMAP): mail.openmail.lk, Port 993, SSL/TLS
  - Outgoing (SMTP): mail.openmail.lk, Port 587, STARTTLS
  - Authentication: Normal password (cleartext over TLS)
  - Username: Full email address

  Self-hosted autoconfig is live at:
    https://autoconfig.openmail.lk/mail/config-v1.1.xml

  Support documentation: https://openmail.lk/support
  Setup instructions: https://openmail.lk/setup

  TLS certificates are provisioned via Let's Encrypt with auto-renewal.
  ```
  - Owner: Developer

- [ ] **Attach `config-v1.1.xml`** to the Bugzilla bug
  - Owner: Developer

### 2.3 Monitor and Respond

- [ ] Wait for Mozilla volunteer review (typically 1–4 weeks)
- [ ] Respond to any questions or change requests
- [ ] Once approved, the config is merged into `autoconfig.thunderbird.net`
- [ ] Owner: Developer

### 2.4 Post-Approval Verification

- [ ] **Wait 24–48 hours** for ISPDB CDN propagation
- [ ] **Test from a clean Thunderbird profile:**
  ```bash
  thunderbird -P --new-instance
  ```
- [ ] Create a new account with `test@openmail.lk` — should auto-configure from ISPDB
- [ ] Owner: QA

---

## Phase 3: OAuth2 Integration (Future Enhancement)

### 3.1 Thunder IDP Configuration

- [ ] **Register OAuth2 client in Thunder IDP**
  - Client ID: (to be generated by IDP admin)
  - Redirect URI: `http://localhost`
  - Grant types: Authorization Code + PKCE
  - Scopes: `openid email profile`
  - Owner: IDP admin

- [ ] **Update `manifest.json` with real client ID**
  ```json
  "clientId": "<REAL_CLIENT_ID_FROM_IDP>"
  ```
  - Owner: Developer

### 3.2 Package Thunderbird OAuth Extension

- [ ] Build the `.xpi` package:
  ```bash
  cd docs/thunderbird-oauth-example
  zip -r thunderbird-oauth-provider.xpi manifest.json
  ```
  - Owner: Developer

- [ ] Sign the extension through Mozilla Add-on Developer Hub
- [ ] Distribute to users or submit to Thunderbird Add-ons
  - Owner: Developer

### 3.3 Update ISPDB Config for OAuth2

- [ ] Uncomment the `<oAuth2>` block in `config-v1.1.xml`
- [ ] Update self-hosted autoconfig
- [ ] File a follow-up Bugzilla bug to update the ISPDB entry with OAuth2 config
  - Owner: Developer

---

## Phase 4: Documentation & Communication

- [ ] **Update `docs/Mail-User-Agent-Setup.md`** — add note that Thunderbird now auto-configures
- [ ] **Create user-facing announcement** — blog post or email to users about easier Thunderbird setup
- [ ] **Update `openmail.lk/setup`** page with Thunderbird-specific instructions reflecting auto-config
- [ ] **Update `openmail.lk/support`** page with troubleshooting for auto-config issues
  - Owner: Documentation / Community

---

## Summary

| Phase | Task | Owner | Priority | Effort |
|-------|------|-------|----------|--------|
| 1.1 | DNS A record | DNS admin | 🔴 High | 5 min |
| 1.2 | TLS certificate | Infra admin | 🔴 High | 10 min |
| 1.3 | Web server config | Infra admin | 🔴 High | 20 min |
| 1.4 | Deploy XML | Infra admin | 🔴 High | 5 min |
| 1.5 | End-to-end test | QA | 🔴 High | 15 min |
| 2.1 | Pre-submission checklist | Developer | 🔴 High | 10 min |
| 2.2 | File Bugzilla bug | Developer | 🟡 Medium | 30 min |
| 2.3 | Monitor & respond | Developer | 🟡 Medium | Ongoing |
| 2.4 | Post-approval test | QA | 🟢 Low | 15 min |
| 3.1 | OAuth2 client registration | IDP admin | 🟢 Low | 30 min |
| 3.2 | Package OAuth extension | Developer | 🟢 Low | 20 min |
| 3.3 | Update ISPDB for OAuth2 | Developer | 🟢 Low | 30 min |
| 4.x | Documentation updates | Docs team | 🟡 Medium | 1 hr |

**Total estimated effort:** ~3–4 hours (excluding Bugzilla review wait time)

---

## Blockers & Dependencies

| Blocker | Blocks | Resolution |
|---------|--------|------------|
| DNS admin access | Phase 1.1 | Obtain credentials or submit DNS change request |
| Server access (SSH) | Phase 1.3, 1.4 | Ensure dev team has access to production web server |
| TLS cert provisioning | Phase 1.2 | certbot container already in docker-compose stack |
| Thunder IDP OAuth2 readiness | Phase 3 | IDP team roadmap |

---

*Last updated: 2026-06-07*
