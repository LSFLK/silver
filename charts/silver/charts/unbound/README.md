# Unbound Helm Chart

Unbound DNS resolver for rspamd DNS queries and recursive resolution.

## Installation

```bash
helm install unbound ./unbound \
  --set persistence.enabled=true \
  --set persistence.size=512Mi
```

## Configuration

Key values:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `replicaCount` | int | `1` | Number of replicas |
| `image.repository` | string | `mvance/unbound` | Image repository |
| `image.tag` | string | `latest` | Image tag |
| `persistence.enabled` | bool | `true` | Enable persistent volume for cache |
| `persistence.size` | string | `512Mi` | Cache volume size |
| `service.port` | int | `53` | Service port (UDP) |
| `configuration` | string | Full unbound.conf | Custom unbound configuration |

## Usage

Unbound is configured for recursive DNS resolution. Access from within cluster:

```bash
dig @<release-name>-unbound example.com
```

For port-forward:

```bash
kubectl port-forward svc/<release-name>-unbound 53:53/udp
dig @127.0.0.1 -p 53 example.com
```

## Persistence

Cache data is stored via `volumeClaimTemplates` in `/var/lib/unbound`. The PVC persists across pod restarts.

## Dependencies

Unbound chart has no external dependencies.
