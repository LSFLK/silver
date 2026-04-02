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
