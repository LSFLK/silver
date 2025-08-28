# DKIM Configuration

This directory contains the configuration files for setting up DKIM (DomainKeys Identified Mail) signing using OpenDKIM.

## Quick Start
To set up DKIM signing, follow these steps:
1. Create a `conf` directory inside the `services/dkim` directory if it doesn't already exist.
2. Create an `.env.conf` file in the `conf` directory with the following content:

```bash
# Mail domain
MAIL_DOMAIN=<your_mail_domain>

# DKIM selector (can be any name, 'mail' is common)
DKIM_SELECTOR=<your_dkim_selector>

# Optional: Key size (default is 2048, can be 1024 or 2048)
DKIM_KEY_SIZE=2048
```

3. Create a `KeyTable` file in the `conf` directory with the following content:

```bash
<DKIM_SELECTOR>._domainkey.<MAIL_DOMAIN> <MAIL_DOMAIN>:<DKIM_SELECTOR>:/etc/opendkim/keys/<MAIL_DOMAIN>/<DKIM_SELECTOR>.private
```

4. Create a `SigningTable` file in the `conf` directory with the following content:

```bash
```*@<MAIL_DOMAIN> <DKIM_SELECTOR>._domainkey.<MAIL_DOMAIN>
```

5. Create a `TrustedHosts` file in the `conf` directory with the following content:

```bash
127.0.0.1
localhost
<MAIL_DOMAIN>