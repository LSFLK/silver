{{- define "raven.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "raven.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "raven.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/* Stable Service name so Postfix / delivery.yaml resolve raven's socketmap. */}}
{{- define "raven.serviceName" -}}
{{- (((.Values.global).serviceNames).raven) | default "raven" }}
{{- end }}

{{- define "raven.selectorLabels" -}}
app.kubernetes.io/name: {{ include "raven.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "raven.labels" -}}
{{ include "raven.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Primary domain + derived mail hostname (single source: global.domain). */}}
{{- define "raven.domain" -}}
{{- required "global.domain is required (e.g. --set global.domain=example.com)" ((.Values.global).domain) }}
{{- end }}

{{- define "raven.mailHostname" -}}
{{- (.Values.global).mailHostname | default (printf "mail.%s" (include "raven.domain" .)) }}
{{- end }}

{{/* S3 endpoint (defaults to the in-cluster seaweedfs Service). */}}
{{- define "raven.s3Endpoint" -}}
{{- if .Values.blobStorage.endpoint }}
{{- .Values.blobStorage.endpoint }}
{{- else }}
{{- printf "http://%s:8333" ((((.Values.global).serviceNames).s3) | default "seaweedfs-s3") }}
{{- end }}
{{- end }}

{{/*
S3 secretKey. Priority: explicit value > the seaweedfs Secret (looked up by
name) > "". The lookup resolves on upgrade (seaweedfs already deployed) — deploy
seaweedfs before/with raven so its Secret exists.
*/}}
{{- define "raven.s3SecretKey" -}}
{{- if .Values.blobStorage.secretKey }}
{{- .Values.blobStorage.secretKey }}
{{- else }}
{{- $name := .Values.blobStorage.existingSecret | default (printf "%s-seaweedfs-s3" .Release.Name) }}
{{- $s := lookup "v1" "Secret" .Release.Namespace $name }}
{{- if and $s (index ($s.data | default dict) "secretKey") }}
{{- index $s.data "secretKey" | b64dec }}
{{- else }}
{{- "" }}
{{- end }}
{{- end }}
{{- end }}

{{/* Thunder public host for OAuth issuer/JWKS (defaults to mail.<domain>). */}}
{{- define "raven.thunderPublicHost" -}}
{{- .Values.thunder.publicHost | default (include "raven.mailHostname" .) }}
{{- end }}

{{/* Secret holding the rendered raven.yaml + delivery.yaml (contain S3 key). */}}
{{- define "raven.configSecretName" -}}
{{- printf "%s-config" (include "raven.fullname" .) }}
{{- end }}

{{/* Secret mounted at /certs (generated self-signed, or a provided one). */}}
{{- define "raven.certSecretName" -}}
{{- .Values.tls.existingSecret | default (printf "%s-certs" (include "raven.fullname" .)) }}
{{- end }}
