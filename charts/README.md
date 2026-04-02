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
