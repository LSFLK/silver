# Multi-Domain Certificate Setup for Silver Mail Server

## Overview

Silver Mail Server supports multi-domain SSL/TLS certificates using Let's Encrypt's HTTP-01 challenge. This allows you to secure multiple specific domains and subdomains with a single certificate.

## What Does a Multi-Domain Certificate Cover?

All domains configured in your `conf/silver.yaml` will be included in a single certificate.

For example, if your `silver.yaml` contains:

```yaml
domains:
  - domain: openmail.lk
    dkim-selector: mail
    dkim-key-size: 2048
  - domain: mail.openmail.lk
    dkim-selector: mail
    dkim-key-size: 2048
  - domain: silver.openmail.lk
    dkim-selector: mail
    dkim-key-size: 2048
  - domain: opendif.openmail.lk
    dkim-selector: mail
    dkim-key-size: 2048
```

✅ **The certificate will cover:**
- `openmail.lk`
- `mail.openmail.lk`
- `silver.openmail.lk`
- `opendif.openmail.lk`

## Prerequisites

1. **Domain ownership**: You must own and control all domains
2. **DNS configured**: All domains must point to your server's IP address
3. **Port 80 accessible**: The HTTP-01 challenge requires port 80 to be open
4. **No web server on port 80**: Certbot needs exclusive access to port 80 during certificate request

## Certificate Request Process

### Step 1: Configure Your Domains

Edit `conf/silver.yaml` and add all your domains:

```yaml
domains:
  - domain: openmail.lk
    dkim-selector: mail
    dkim-key-size: 2048
  - domain: mail.openmail.lk
    dkim-selector: mail
    dkim-key-size: 2048
  - domain: silver.openmail.lk
    dkim-selector: mail
    dkim-key-size: 2048
  - domain: opendif.openmail.lk
    dkim-selector: mail
    dkim-key-size: 2048
```

**Important**: The first domain in the list is the "primary domain" and will be used for:
- Certificate directory name
- Admin email address

### Step 2: Verify DNS Records

Before requesting a certificate, ensure all domains point to your server:

```bash
# Check each domain resolves to your server IP
dig openmail.lk +short
dig mail.openmail.lk +short
dig silver.openmail.lk +short
dig opendif.openmail.lk +short
```

All should return your server's IP address.

### Step 3: Run the Certificate Generation Script

```bash
cd services/config-scripts
./gen-certbot-certs.sh
```

### Step 4: Review and Confirm

The script will display:
- All domains to be covered
- That it will use HTTP-01 challenge (port 80)
- Certificate location

Press Enter to continue.

### Step 5: Certificate Issuance

The script will:
1. Start certbot in standalone mode
2. Listen on port 80
3. Complete the HTTP-01 challenge automatically
4. Download and install the certificate

**This is completely automatic!** No DNS records or manual steps required.

## Certificate Locations

After successful issuance, certificates are stored in:

```
services/silver-config/certbot/keys/etc/live/openmail.lk/
├── fullchain.pem   # Full certificate chain (use this for SSL config)
├── privkey.pem     # Private key (keep secure!)
├── cert.pem        # Certificate only
└── chain.pem       # Intermediate certificates
```

The certificate is automatically distributed to:
- **Postfix** (SMTP): `/etc/letsencrypt/live/openmail.lk/`
- **Raven** (IMAP): `silver-config/raven/certs/`
- **Thunder** (Auth): `silver-config/thunder/certs/`

## Certificate Renewal

Certificates from Let's Encrypt expire after 90 days. To renew:

### Manual Renewal

```bash
cd services/config-scripts
./gen-certbot-certs.sh
```

When prompted, choose to renew the existing certificate (y).

### Automated Renewal

Set up a cron job for automatic renewal:

```bash
# Edit crontab
crontab -e

# Add this line to check for renewal daily at 2 AM
0 2 * * * cd /path/to/silver/services/config-scripts && ./gen-certbot-certs.sh renew >> /var/log/certbot-renew.log 2>&1
```

Or use the built-in certbot renew command:

```bash
# Renew all certificates that are close to expiration
docker run --rm \
  -p 80:80 \
  -v "/path/to/silver/services/silver-config/certbot/keys/etc:/etc/letsencrypt" \
  -v "/path/to/silver/services/silver-config/certbot/keys/lib:/var/lib/letsencrypt" \
  certbot/certbot \
  renew --quiet
```

## Adding More Domains

To add additional domains to your certificate:

1. **Update `conf/silver.yaml`** with the new domain:
   ```yaml
   domains:
     - domain: openmail.lk
       dkim-selector: mail
       dkim-key-size: 2048
     - domain: api.openmail.lk  # New domain
       dkim-selector: mail
       dkim-key-size: 2048
   ```

2. **Ensure DNS is configured** for the new domain

3. **Re-run the certificate script**:
   ```bash
   cd services/config-scripts
   ./gen-certbot-certs.sh
   ```

The `--expand` flag in the certbot command will automatically expand your existing certificate to include the new domain.

## Advantages of HTTP-01 Challenge

✅ **Fully automated**: No manual DNS record creation
✅ **Quick**: Certificate issued in seconds
✅ **Easy renewal**: Simple `certbot renew` command
✅ **No third-party dependencies**: Works with any DNS provider
✅ **Explicit domain control**: Only covers domains you specify

## Limitations

❌ **Not a wildcard**: Doesn't cover `*.openmail.lk`
❌ **Requires port 80**: Must have port 80 accessible
❌ **Explicit domains**: Must list each subdomain individually

## Comparison with Wildcard Certificates

| Feature | HTTP-01 Multi-Domain | DNS-01 Wildcard |
|---------|---------------------|------------------|
| Coverage | Specific domains only | All subdomains |
| Setup | Automatic | Manual DNS records |
| Port 80 Required | Yes | No |
| DNS Provider | Any | Any |
| Renewal | Automatic | Manual DNS each time |
| Complexity | Low | Medium |

## Troubleshooting

### Port 80 Already in Use

**Symptom**: Error about port 80 being already bound

**Solution**: Stop any web server running on port 80 temporarily:
```bash
# Stop nginx
sudo systemctl stop nginx

# Or stop apache
sudo systemctl stop apache2

# Run certificate script
cd services/config-scripts
./gen-certbot-certs.sh

# Restart web server
sudo systemctl start nginx
```

### Domain Doesn't Resolve

**Symptom**: "Failed to connect to domain for HTTP-01 challenge"

**Solution**:
- Verify DNS: `dig yourdomain.com +short`
- Wait for DNS propagation (can take up to 48 hours)
- Ensure your server's IP is correct in DNS records

### Certificate Already Exists

**Symptom**: "Certificate already exists for domain"

**Solution**: Choose to renew when prompted, or manually remove old certificates:
```bash
rm -rf services/silver-config/certbot/keys/etc/live/yourdomain.com
```

### Rate Limit Exceeded

**Symptom**: "Too many certificates already issued"

**Solution**: Let's Encrypt has rate limits (50 certificates per domain per week). Wait a week or use their staging environment for testing:

Add `--staging` flag to test:
```bash
# In gen-certbot-certs.sh, add --staging to the certbot command
certbot certonly --staging --standalone ...
```

## Security Best Practices

1. **Keep private keys secure**: Never commit `privkey.pem` to version control
2. **Set proper permissions**:
   ```bash
   chmod 600 services/silver-config/certbot/keys/etc/live/*/privkey.pem
   chmod 644 services/silver-config/certbot/keys/etc/live/*/fullchain.pem
   ```
3. **Monitor expiration**: Set up monitoring for certificate expiration
4. **Use strong keys**: The scripts default to RSA 2048-bit keys
5. **Keep certbot updated**: Use latest certbot Docker image

## Firewall Configuration

Ensure port 80 is accessible from the internet:

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 80/tcp

# firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --reload

# iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```

## Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [HTTP-01 Challenge](https://letsencrypt.org/docs/challenge-types/#http-01-challenge)
- [Rate Limits](https://letsencrypt.org/docs/rate-limits/)
