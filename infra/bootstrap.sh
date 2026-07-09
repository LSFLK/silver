#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# cert-manager bootstrap script
# Creates Cloudflare API token Secret and Let's Encrypt ClusterIssuers
# ------------------------------------------------------------------------------

# --- Colours ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Prerequisites ------------------------------------------------------------
command -v kubectl >/dev/null 2>&1 || error "kubectl not found"
command -v helm    >/dev/null 2>&1 || error "helm not found"

# --- Inputs -------------------------------------------------------------------
read -rp "Enter your domain (e.g. example.com): "        DOMAIN
read -rp "Enter your Let's Encrypt email: "              LE_EMAIL
read -rsp "Enter your Cloudflare API token: "            CF_TOKEN
echo

# --- Validate -----------------------------------------------------------------
[[ -z "$DOMAIN"   ]] && error "Domain cannot be empty"
[[ -z "$LE_EMAIL" ]] && error "Email cannot be empty"
[[ -z "$CF_TOKEN" ]] && error "Cloudflare API token cannot be empty"

info "Domain:   $DOMAIN"
info "Email:    $LE_EMAIL"
info "Token:    ****${CF_TOKEN: -4}"
echo

# --- Namespace ----------------------------------------------------------------
info "Ensuring cert-manager namespace exists..."
kubectl get namespace cert-manager >/dev/null 2>&1 \
  || kubectl create namespace cert-manager

# --- Cloudflare Secret --------------------------------------------------------
info "Creating Cloudflare API token secret..."
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token="$CF_TOKEN" \
  --namespace cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -

info "Secret created: cloudflare-api-token (namespace: cert-manager)"

# --- ClusterIssuer: Staging ---------------------------------------------------
info "Applying ClusterIssuer: le-staging..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: le-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${LE_EMAIL}
    privateKeySecretRef:
      name: le-staging-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
        selector:
          dnsZones:
            - "${DOMAIN}"
EOF

# --- ClusterIssuer: Prod ------------------------------------------------------
info "Applying ClusterIssuer: le-prod..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: le-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${LE_EMAIL}
    privateKeySecretRef:
      name: le-prod-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
        selector:
          dnsZones:
            - "${DOMAIN}"
EOF

# --- Verify -------------------------------------------------------------------
info "Waiting for ClusterIssuers to become ready (up to 60s)..."
sleep 5

for ISSUER in le-staging le-prod; do
  READY=$(kubectl get clusterissuer "$ISSUER" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
  if [[ "$READY" == "True" ]]; then
    info "✅ $ISSUER is Ready"
  else
    warn "⏳ $ISSUER not ready yet — run: kubectl describe clusterissuer $ISSUER"
  fi
done

echo
info "Bootstrap complete."
info "Next step: kubectl get clusterissuer"