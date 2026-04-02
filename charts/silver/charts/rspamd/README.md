# Rspamd Helm Chart

Rspamd spam/malware filtering engine with antivirus (ClamAV), Bayes classifier, and metrics exporter.

## Dependencies

This chart requires:
- Redis: for learning/caching backend
- Unbound: for DNS queries
- ClamAV: for virus scanning (optional but recommended)

## Installation

Basic installation with all dependencies:

```bash
helm upgrade --install silver ./charts/silver \
  --set redis.enabled=true \
  --set unbound.enabled=true \
  --set rspamd.enabled=true \
  --set 'rspamd.webui.password=mypassword'
```

## Configuration

Key values:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `replicaCount` | int | `1` | Number of replicas |
| `image.repository` | string | `rspamd/rspamd` | Image repository |
| `image.tag` | string | `latest` | Image tag |
| `persistence.enabled` | bool | `true` | Enable persistent volume for state |
| `persistence.size` | string | `1Gi` | Persistent volume size |
| `dependencies.redis.host` | string | `silver-redis` | Redis service hostname |
| `dependencies.redis.port` | int | `6379` | Redis port |
| `dependencies.unbound.host` | string | `silver-unbound` | Unbound DNS hostname |
| `dependencies.unbound.port` | int | `53` | Unbound DNS port |
| `dependencies.clamav.host` | string | `clamav-server` | ClamAV service hostname |
| `dependencies.clamav.port` | int | `3310` | ClamAV port |
| `dependencies.strictInitChecks` | bool | `true` | Fail-fast on dependency unavailability |
| `dependencies.initCheckTimeout` | string | `60s` | Init check timeout duration |
| `modules.antivirus.enabled` | bool | `true` | Enable antivirus scanning |
| `modules.antivirus.clamav_action` | string | `add_header` | Action on virus: add_header, reject, discard |
| `modules.classifier_bayes.enabled` | bool | `true` | Enable Bayes spam classifier |
| `modules.classifier_bayes.backend` | string | `redis` | Backend for classifier storage |
| `modules.metrics_exporter.enabled` | bool | `true` | Enable Prometheus metrics export |
| `service.milter.port` | int | `11332` | SMTP milter port |
| `service.webui.port` | int | `11334` | Web UI port |
| `service.webui.enabled` | bool | `true` | Enable web UI service |
| `webui.password` | string | `` | Web UI password (empty = disabled) |

## Override Dependency Hosts

For custom dependency endpoints:

```bash
helm upgrade --install silver ./charts/silver \
  --set rspamd.enabled=true \
  --set 'rspamd.dependencies.redis.host=custom-redis' \
  --set 'rspamd.dependencies.unbound.host=custom-unbound' \
  --set 'rspamd.dependencies.clamav.host=external-clamav'
```

## Web UI Access

Port-forward to rspamd web UI:

```bash
kubectl port-forward -n mail svc/silver-rspamd 11334:11334
```

Then access: `http://localhost:11334/` with configured password.

## Testing

Run Helm test:

```bash
helm test silver -n mail
```

Verify milter connectivity from postfix:

```bash
kubectl exec -n mail -it <postfix-pod> -- nc -zv silver-rspamd 11332
```

## Init Checks

If `dependencies.strictInitChecks=true`, rspamd will not start until:
- Redis is reachable on configured host:port
- Unbound DNS is responding on configured host:port

If init checks fail, inspect pod logs:

```bash
kubectl logs -n mail <rspamd-pod> -c check-redis
kubectl logs -n mail <rspamd-pod> -c check-unbound
```

## Persistence

Rspamd state (learning data, UCL files, ML models) is stored in `/var/lib/rspamd` via `volumeClaimTemplates`. The PVC persists across pod restarts.

## Scaling

v1 supports single replica only (`replicaCount: 1`). Multi-replica support requires shared Redis + distributed learning (future scope).
