# Redis Helm Chart

Redis in-memory data store for rspamd backend storage.

## Installation

```bash
helm install redis ./redis \
  --set persistence.enabled=true \
  --set persistence.size=1Gi
```

## Configuration

Key values:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `replicaCount` | int | `1` | Number of replicas (always 1 for StatefulSet) |
| `image.repository` | string | `redis` | Image repository |
| `image.tag` | string | `7-alpine` | Image tag |
| `persistence.enabled` | bool | `true` | Enable persistent volume |
| `persistence.size` | string | `1Gi` | Persistent volume size |
| `service.port` | int | `6379` | Service port |
| `securityContext.fsGroup` | int | `999` | Redis user UID |

## Usage

Access Redis within the cluster:

```bash
redis-cli -h <release-name>-redis -p 6379
```

For port-forward:

```bash
kubectl port-forward svc/<release-name>-redis 6379:6379
redis-cli -h localhost -p 6379
```

## Persistence

Redis data is stored in `/data` via `volumeClaimTemplates`. The PVC persists across pod restarts.

## Dependencies

Redis chart has no external dependencies.
