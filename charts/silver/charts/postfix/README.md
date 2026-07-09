# Postfix Helm Chart

Helm subchart deploying Postfix (via `ghcr.io/lsflk/silver-smtp`) into Kubernetes as part of the Silver mail platform umbrella chart.

---

## Changes Made (feat/postfix-charts)

### `.helmignore`
Removed `**/*.zip` / `**/*.tar.gz` glob patterns — Helm does not support `**` double-star syntax and refused to load the chart. Replaced with `*.zip` / `*.tar.gz`.

### `templates/configmap-postfix.yaml`
Added inline values override support. Previously the ConfigMap always embedded `old-config/postfix/main.cf` and `old-config/postfix/master.cf` via `.Files.Get`. Now:

- If `postfixConfig.mainCfContent` is set in values → use that string as `main.cf`
- Otherwise → fall back to the file at `old-config/postfix/main.cf`
- Same pattern for `master.cf`
- If `postfixConfig.silverYamlContent` is set → add `silver.yaml` key to the ConfigMap

This lets you supply a stripped-down standalone config via `values-dev.yaml` without modifying the checked-in config files.

### `templates/deployment.yaml`
Added `silver.yaml` mount: when `postfixConfig.silverYamlContent` is non-empty, mounts `silver.yaml` from the ConfigMap to `/etc/postfix/silver.yaml`. The container entrypoint (`/entrypoint.sh`) requires this file to extract the mail domain at startup.

### `charts/silver/values-dev.yaml`
New file for local k3d development. Overrides:
- `tls.enabled: false` — skips cert-manager `Certificate` CRD (not installed in k3d)
- `postfix.image` — points to `silver-smtp:local` with `pullPolicy: Never` (locally built ARM64 image)
- `postfix.postfixConfig.mainCfContent` — standalone `main.cf` (no TLS certs, no Raven, no milters)
- `postfix.postfixConfig.masterCfContent` — standalone `master.cf` (submission port without TLS/SASL requirements)
- `postfix.postfixConfig.silverYamlContent` — minimal `silver.yaml` with `domains: [{domain: silver-test.local}]`
- `opendkim.enabled: false`

---

## How It Works

### Architecture

```
                     ┌─────────────────────────────────────────┐
                     │           k8s cluster                    │
                     │                                          │
  Internet / MUA ───►│  Service: silver-postfix                 │
  port 25 / 587      │  ClusterIP, ports 25+587                 │
                     │        │                                  │
                     │        ▼                                  │
                     │  Pod: silver-postfix                      │
                     │  image: silver-smtp                       │
                     │  /entrypoint.sh                           │
                     │     └─ starts Postfix daemon              │
                     │                                           │
                     │  Mounted from ConfigMap:                  │
                     │    /etc/postfix/main.cf                   │
                     │    /etc/postfix/master.cf                 │
                     │    /etc/postfix/silver.yaml               │
                     └─────────────────────────────────────────┘
```

### Boot sequence

1. `helm install` renders ConfigMap from `postfixConfig.*` values (or falls back to `old-config/` files).
2. Deployment mounts ConfigMap keys as files under `/etc/postfix/`.
3. Container starts `/entrypoint.sh`:
   - Reads domain from `/etc/postfix/silver.yaml`
   - Writes domain to `/etc/mailname`
   - Copies DNS resolver files into Postfix chroot (`/var/spool/postfix/etc/`)
   - Runs `postconf` sanity checks
   - Starts Postfix via `service postfix start`
   - Sleeps to keep container alive
4. Postfix master daemon forks workers per `master.cf` — `smtpd` on port 25, `smtpd` on port 587 (submission).

### ConfigMap override logic

```
postfixConfig.enabled: true          # required — creates the ConfigMap
postfixConfig.mainCfContent: |       # optional — inline main.cf
  ...                                #   if absent, uses old-config/postfix/main.cf
postfixConfig.masterCfContent: |     # optional — inline master.cf
  ...                                #   if absent, uses old-config/postfix/master.cf
postfixConfig.silverYamlContent: |   # optional — if set, mounted at /etc/postfix/silver.yaml
  domains:
    - domain: example.com
```

### Image

`ghcr.io/lsflk/silver-smtp:main` is AMD64-only. On ARM64 (Apple Silicon) k3d clusters, build a local image:

```bash
# build for current arch (ARM64 on M-chip)
docker build --platform linux/arm64 \
  -t silver-smtp:local \
  -f services/smtp/Dockerfile \
  services/

# import into k3d
k3d image import silver-smtp:local -c <cluster-name>
```

Then set in values:
```yaml
postfix:
  image:
    repository: silver-smtp
    tag: local
    pullPolicy: Never
```

---

## Local k3d Quickstart

```bash
# 1. create cluster
k3d cluster create silver-dev --agents 1

# 2. build ARM64 image and import (Apple Silicon only)
docker build --platform linux/arm64 -t silver-smtp:local -f services/smtp/Dockerfile services/
k3d image import silver-smtp:local -c silver-dev

# 3. build helm deps
helm dependency build charts/silver

# 4. install
kubectl create namespace postfix-dev
helm install silver charts/silver \
  -f charts/silver/values-dev.yaml \
  -n postfix-dev

# 5. verify
kubectl get pods -n postfix-dev
kubectl logs -n postfix-dev -l app.kubernetes.io/name=postfix

# 6. smoke test SMTP from inside cluster
kubectl exec -n postfix-dev deploy/silver-postfix -- \
  bash -c "timeout 3 bash -c 'exec 3<>/dev/tcp/localhost/25; cat <&3 & echo QUIT >&3; sleep 1'"
# expect: 220 silver-test.local ESMTP Postfix
```

---

## Connecting an MDA (Dovecot)

Postfix delivers mail to an MDA via LMTP or virtual transport. In production, Silver uses Raven (a custom LMTP server). To swap in Dovecot:

### 1. Deploy Dovecot

Add Dovecot as a pod/service in the same namespace. It needs:
- LMTP listener on port 24 (or a Unix socket — but sockets don't cross pod boundaries, so use TCP)
- Maildir or Mailbox storage (PVC recommended)

Minimal Dovecot LMTP config:
```
# /etc/dovecot/conf.d/10-master.conf
service lmtp {
  inet_listener lmtp {
    address = 0.0.0.0
    port = 24
  }
}
```

Kubernetes Service for Dovecot (example):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: dovecot
  namespace: postfix-dev
spec:
  selector:
    app: dovecot
  ports:
    - name: lmtp
      port: 24
      targetPort: 24
    - name: imap
      port: 143
      targetPort: 143
```

### 2. Wire Postfix → Dovecot via LMTP

In `postfixConfig.mainCfContent` (or `old-config/postfix/main.cf`):

```
# tell Postfix to use Dovecot's LMTP for virtual mailbox delivery
virtual_transport = lmtp:inet:dovecot:24

# Dovecot owns the mailbox lookup — point postfix at it
# Option A: static list of domains
virtual_mailbox_domains = example.com

# Option B: query Dovecot's userdb via socketmap (requires Dovecot auth-userdb)
# virtual_mailbox_domains = socketmap:inet:dovecot:9100:virtual-domains
# virtual_mailbox_maps    = socketmap:inet:dovecot:9100:user-exists

# Mailbox base (Postfix uses this for reject_unlisted_recipient checks)
virtual_mailbox_base = /var/mail/virtual
```

In `smtpd_recipient_restrictions`, keep `reject_unlisted_recipient` only if `virtual_mailbox_maps` is configured and queryable.

### 3. Wire SASL Auth → Dovecot

For submission port (587) authentication, Dovecot exposes a SASL socket. Over TCP in Kubernetes:

```
# main.cf
smtpd_sasl_type           = dovecot
smtpd_sasl_path           = inet:dovecot:12345
smtpd_sasl_auth_enable    = yes
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients  = yes
```

Dovecot side (`10-master.conf`):
```
service auth {
  inet_listener {
    port = 12345
  }
}
```

### 4. Update submission entry in master.cf

Re-enable SASL and relay restriction on port 587:
```
submission inet  n       -       y       -       -       smtpd
    -o syslog_name=postfix/submission
    -o smtpd_tls_security_level=encrypt     # require STARTTLS in production
    -o smtpd_sasl_auth_enable=yes
    -o smtpd_tls_auth_only=yes
    -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
```

### 5. Full integration checklist

| Component | What to configure |
|-----------|-------------------|
| Dovecot LMTP | `service lmtp { inet_listener { port = 24 } }` |
| Dovecot SASL | `service auth { inet_listener { port = 12345 } }` |
| Dovecot passdb/userdb | point at your user store (SQL, LDAP, passwd-file) |
| Postfix `main.cf` | `virtual_transport`, `virtual_mailbox_domains`, `smtpd_sasl_path` |
| Postfix `master.cf` | re-enable SASL + TLS on submission |
| TLS certs | mount cert/key into both Postfix and Dovecot pods (cert-manager Secret) |
| PVC | Dovecot needs persistent storage for Maildir |

---

## Production Checklist (deferred from dev bring-up)

- [ ] Enable TLS: mount cert-manager Secret; set `smtpd_tls_security_level = may` and restore cert/key paths
- [ ] Enable SASL: point `smtpd_sasl_path` at Dovecot or Raven
- [ ] Enable milters: restore `smtpd_milters = inet:rspamd-server:11332,inet:opendkim-server:8891`
- [ ] Set `mynetworks` to a restricted range (not `0.0.0.0/0`)
- [ ] Add TCP socket liveness probe on port 25
- [ ] Add PVC for `/var/spool/postfix` (mail queue durability)
- [ ] Switch `imagePullPolicy` back to `IfNotPresent` using the published image
