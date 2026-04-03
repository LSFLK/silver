# OpenDKIM Helm Chart

This chart deploys OpenDKIM for Silver with configuration rendered from Helm values.

## Features

- Stateful OpenDKIM workload with persistent DKIM keys.
- `silver.yaml` generated from Helm values (`domains`).
- Generated `TrustedHosts`, `SigningTable`, and `KeyTable`.
- Security defaults aligned with compose (`cap_drop: all`, no privilege escalation).

## Install

```bash
helm upgrade --install silver charts/silver -f charts/silver/values-dev.yaml -n mail --create-namespace
```

## Required Values

Set at least one domain:

```yaml
domains:
  - domain: example.com
    dkimSelector: mail
    dkimKeySize: 2048
```

## Persistence

- Default path: `/etc/dkimkeys`
- Configure `persistence.storageClass` to your cluster class.
- Use `persistence.existingClaim` if you manage PVC externally.

## Notes

- OpenDKIM container entrypoint still generates missing DKIM keys at startup.
- Config changes trigger rolling restart through checksum annotations.

## Local Testing (Step-by-Step)

Use this sequence to test OpenDKIM locally (for example with Minikube).

### 1. Go to project folder

```bash
cd silver
```

### 2. Create namespace (safe to run once)

```bash
kubectl create namespace mail
```

If it already exists, Kubernetes will print `AlreadyExists`. That is fine.

### 3. Deploy OpenDKIM chart

```bash
helm upgrade --install silver ./charts/silver -n mail \
  --set opendkim.enabled=true \
  --set 'opendkim.domains[0].domain=example.test' \
  --set 'opendkim.domains[0].dkimSelector=mail' \
  --set 'opendkim.domains[0].dkimKeySize=2048' \
  --set opendkim.persistence.enabled=true \
  --wait --timeout 5m
```

What this does:

- Installs or upgrades Helm release `silver`.
- Deploys OpenDKIM resources.
- Sets one test domain (`example.test`).
- Waits for resources to become ready.

### 4. Check resources

```bash
kubectl get all -n mail
kubectl get pvc -n mail
```

Expected:

- Pod is `Running`.
- StatefulSet is ready.
- Service exists.
- PVC is `Bound`.

### 5. Check OpenDKIM logs

```bash
kubectl logs -n mail statefulset/silver-opendkim -c opendkim --tail=200
```

You should see startup and key-generation output.

### 6. Run Helm connectivity test

```bash
helm test silver -n mail
```

Expected: test suite succeeds.

### 7. Manual port check from inside cluster

```bash
kubectl run -n mail dkim-probe --rm -it --restart=Never --image=busybox:1.36 -- \
  sh -c "nc -zvw5 silver-opendkim 8891"
```

Expected: port `8891` is open.

### 8. Verify key generation

Get pod name:

```bash
POD=$(kubectl get pod -n mail -l app.kubernetes.io/name=opendkim -o jsonpath='{.items[0].metadata.name}')
echo "$POD"
```

List generated key files:

```bash
kubectl exec -n mail "$POD" -- sh -c "find /etc/dkimkeys -maxdepth 3 -type f | sort"
```

Show generated DNS TXT record file:

```bash
kubectl exec -n mail "$POD" -- sh -c "cat /etc/dkimkeys/example.test/mail.txt"
```

### 9. Test key persistence

Delete pod to force restart:

```bash
kubectl delete pod -n mail "$POD"
```

Wait for StatefulSet to recover:

```bash
kubectl rollout status statefulset/silver-opendkim -n mail --timeout=180s
```

Get new pod name:

```bash
NEWPOD=$(kubectl get pod -n mail -l app.kubernetes.io/name=opendkim -o jsonpath='{.items[0].metadata.name}')
echo "$NEWPOD"
```

Verify keys still exist:

```bash
kubectl exec -n mail "$NEWPOD" -- sh -c "find /etc/dkimkeys -maxdepth 3 -type f | sort"
```

If key files are still present, persistence is working.

### 10. Cleanup (optional)

```bash
helm uninstall silver -n mail
kubectl delete namespace mail
```
