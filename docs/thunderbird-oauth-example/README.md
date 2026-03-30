# Thunderbird OAuth Extension (Example)

This folder contains a sample `manifest.json` for a Thunderbird OAuth provider extension.

## 1. Update placeholders

Edit [manifest.json](manifest.json) and replace all placeholders:

- `<YOUR_PROVIDER_NAME>`
- `<your-domain>`
- `<ISSUER_URL>`
- `<CLIENT_ID>`
- `<AUTHORIZATION_ENDPOINT>`
- `<TOKEN_ENDPOINT>`
- `<MAIL_DOMAIN>`

## 2. Create the extension package

From this folder, run:

```bash
zip -r thunderbird-oauth-provider.xpi manifest.json
```

This creates `thunderbird-oauth-provider.xpi`.

## 3. Install in Thunderbird

1. Open Thunderbird.
2. Go to **Add-ons and Themes**.
3. Click the gear icon and choose **Install Add-on From File...**.
4. Select `thunderbird-oauth-provider.xpi`.
5. Confirm prompts and restart Thunderbird if asked.

## 4. Verify

- Set account authentication to OAuth2.
- Trigger sign-in and complete the OAuth login flow.
- Confirm send/receive works.
