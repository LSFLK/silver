# ClamAV Helm Subchart

This chart deploys a ClamAV daemon service used by rspamd antivirus scanning.

## Features

- StatefulSet-based deployment for stable identity
- Persistent signature database at `/var/lib/clamav`
- Internal ClusterIP service on TCP 3310
- Freshclam updates enabled by default via `CLAMAV_NO_FRESHCLAMD=false`
- Ephemeral logs in v1 (`/var/log/clamav` via `emptyDir`)

## Install via umbrella chart

```bash
helm upgrade --install silver ./charts/silver -n mail --create-namespace \
  --set clamav.enabled=true
```

## Common overrides

```bash
helm upgrade --install silver ./charts/silver -n mail \
  --set clamav.enabled=true \
  --set clamav.resources.requests.memory=1Gi \
  --set clamav.resources.limits.memory=2867Mi \
  --set clamav.persistence.size=2Gi
```

## Notes

- Keep `clamav.enabled=true` when `rspamd.enabled=true` if antivirus is enabled in rspamd.
- If running on low-memory clusters, lower memory limits/requests and monitor for OOM kills.
