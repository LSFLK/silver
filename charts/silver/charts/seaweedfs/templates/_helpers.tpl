{{/* Chart name, optionally overridden. */}}
{{- define "seaweedfs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Release-qualified name for owned objects (StatefulSet, Secret). */}}
{{- define "seaweedfs.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "seaweedfs.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Stable, release-independent Service name so Raven's vendored config resolves the
S3 endpoint. Defaults to the compose name `seaweedfs-s3`; override via
global.serviceNames.s3.
*/}}
{{- define "seaweedfs.serviceName" -}}
{{- (((.Values.global).serviceNames).s3) | default "seaweedfs-s3" }}
{{- end }}

{{- define "seaweedfs.secretName" -}}
{{- printf "%s-s3" (include "seaweedfs.fullname" .) }}
{{- end }}

{{- define "seaweedfs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "seaweedfs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "seaweedfs.labels" -}}
{{ include "seaweedfs.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Resolve the S3 secretKey. Priority: global.s3.secretKey > local s3.secretKey >
a value DERIVED deterministically from the release name. Derivation (not random
+ lookup) is what lets the raven subchart compute the SAME key on a fresh
one-command `helm install` — lookup can't see a Secret the same install hasn't
applied yet. Override global.s3.secretKey in prod. Hex from sha256sum, so it is
JSON/URL-safe (no escaping needed).
*/}}
{{- define "seaweedfs.secretKey" -}}
{{- (((.Values.global).s3).secretKey) | default .Values.s3.secretKey | default (printf "%s-silver-seaweedfs-s3" .Release.Name | sha256sum | trunc 40) }}
{{- end }}
