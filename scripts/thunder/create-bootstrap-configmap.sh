#!/usr/bin/env bash
# Create the Thunder bootstrap ConfigMap from the scripts in this directory.
#
# The Thunder Helm chart's setup job is a Helm pre-install hook, so the
# ConfigMap it references (thunder.bootstrap.configMap.name in the silver
# umbrella values) must already exist in the namespace *before* you run
# `helm install`. This script creates/refreshes it directly from the canonical
# scripts here, so they are never duplicated into the chart.
#
# Usage:
#   scripts/thunder/create-bootstrap-configmap.sh [namespace] [configmap-name]
#
# Defaults: namespace=silver, configmap-name=thunder-bootstrap
set -euo pipefail

NAMESPACE="${1:-silver}"
CONFIGMAP_NAME="${2:-thunder-bootstrap}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Keep this list in sync with thunder.bootstrap.configMap.files in
# charts/silver/values.yaml. common.sh is intentionally omitted — it ships with
# the Thunder image and is preserved because we mount individual files.
FILES=(
  "01-default-resources.sh"
  "02-sample-resources.sh"
)

FROM_FILE_ARGS=()
for f in "${FILES[@]}"; do
  if [[ ! -f "${SCRIPT_DIR}/${f}" ]]; then
    echo "error: ${SCRIPT_DIR}/${f} not found" >&2
    exit 1
  fi
  FROM_FILE_ARGS+=(--from-file="${f}=${SCRIPT_DIR}/${f}")
done

# Best-effort namespace creation. Ignore failures (already exists, or the caller
# only has namespace-scoped permissions) — if the namespace is truly missing the
# ConfigMap creation below fails with a clear error anyway.
kubectl create namespace "${NAMESPACE}" 2>/dev/null || true

# --dry-run|apply so the command is idempotent (safe to re-run to update scripts).
kubectl create configmap "${CONFIGMAP_NAME}" \
  --namespace "${NAMESPACE}" \
  "${FROM_FILE_ARGS[@]}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ConfigMap '${CONFIGMAP_NAME}' created/updated in namespace '${NAMESPACE}'."
