# Silver Helm Charts

This directory contains Helm charts for Silver services.

## Structure

- `silver/`: Umbrella chart that aggregates service subcharts.
- `silver/charts/opendkim/`: OpenDKIM service chart (first migrated service).

## Conventions

- Service charts live under `silver/charts/<service-name>/`.
- Every service chart should include:
  - `values.yaml` with safe defaults.
  - `templates/` for Kubernetes resources.
  - `README.md` with install and operations guidance.
- Environment overlays should be kept in umbrella chart values files (`values-dev.yaml`, `values-prod.yaml`).

## Next Services

When adding future services (smtp, rspamd, raven, etc.), repeat the OpenDKIM chart pattern and add them as dependencies in the umbrella chart.

## Install cert-manager (once per cluster)

cert-manager is cluster infrastructure. Install it once, outside of Silver.

```bash
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.20.0 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Verify:

```bash
kubectl get pods -n cert-manager
# All pods should be Running
```

---

## Step 2 — Bootstrap ClusterIssuers (once per cluster)

The bootstrap script creates:
- A Cloudflare API token Secret in the `cert-manager` namespace
- `le-staging` ClusterIssuer (Let's Encrypt staging — untrusted, no rate limits)
- `le-prod` ClusterIssuer (Let's Encrypt prod — trusted, rate limited)

You will need:
- A Cloudflare API token scoped to `Zone:Read` and `DNS:Edit` for your domain
- An email address for Let's Encrypt notifications

Run from the repo root:

```bash
bash infra/bootstrap.sh
```

Verify:

```bash
kubectl get clusterissuer
# Both le-staging and le-prod should show READY=True
```

---

## Step 3 — Configure values.yaml

Before installing Silver, ensure your `values.yaml` includes TLS configuration:

```yaml
tls:
  enabled: true
  issuer: le-staging    # use le-staging first, switch to le-prod once verified
  renewBefore: "720h"   # renew 30 days before expiry
  domains:
    - yourdomain.com
```

Each domain will receive a certificate covering:
- `yourdomain.com`
- `*.yourdomain.com`

### Staging vs Production

Always test with `le-staging` first. Staging issues real but **untrusted** certificates —
browsers will show a warning, but the full DNS challenge and issuance flow is verified.

Once the staging certificate shows `READY=True`, switch to `le-prod`:

```yaml
tls:
  issuer: le-prod
```

Let's Encrypt prod has a rate limit of **5 certificates per domain per week**.
Burning through this with misconfigured charts is a common mistake — staging prevents it.

---

## Step 4 — Install Silver

From the repo root:

```bash
helm upgrade --install silver ./charts/silver \
  --namespace silver \
  --create-namespace
```

With a values overlay (e.g. dev):

```bash
helm upgrade --install silver ./charts/silver \
  -f charts/silver/values-dev.yaml \
  --namespace silver \
  --create-namespace
```

Verify certificates:

```bash
kubectl get certificate -n silver
# maneesha-xyz-tls should show READY=True
```

If not ready yet, check progress:

```bash
kubectl describe certificate <name> -n silver
```
---