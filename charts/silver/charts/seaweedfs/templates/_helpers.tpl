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
Resolve the S3 secretKey once so the Secret is the single source of truth.
Priority: explicit value > existing in-cluster Secret (preserved on upgrade) >
freshly generated. randAlphaNum is JSON/URL-safe (no escaping needed).
*/}}
{{- define "seaweedfs.secretKey" -}}
{{- if .Values.s3.secretKey }}
{{- .Values.s3.secretKey }}
{{- else }}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "seaweedfs.secretName" .) }}
{{- if and $existing (index ($existing.data | default dict) "secretKey") }}
{{- index $existing.data "secretKey" | b64dec }}
{{- else }}
{{- randAlphaNum 40 }}
{{- end }}
{{- end }}
{{- end }}
