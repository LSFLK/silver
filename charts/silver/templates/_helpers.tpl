{{/*
Expand the name of the chart.
*/}}
{{- define "silver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "silver.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "silver.labels" -}}
helm.sh/chart: {{ include "silver.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "silver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "silver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "silver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Mail domain (single source of truth).
*/}}
{{- define "silver.domain" -}}
{{- required "global.domain is required (e.g. --set global.domain=example.com)" .Values.global.domain -}}
{{- end }}

{{/*
Mail hostname, defaults to mail.<domain>.
*/}}
{{- define "silver.mailHostname" -}}
{{- default (printf "mail.%s" (include "silver.domain" .)) .Values.global.mailHostname -}}
{{- end }}

{{/*
cert-manager TLS Secret name, defaults to the mail.<domain> cert minted by certificate.yaml
(<domain-dashed>-tls).
*/}}
{{- define "silver.tlsSecretName" -}}
{{- default (printf "%s-tls" (include "silver.mailHostname" . | replace "." "-")) .Values.global.tlsSecretName -}}
{{- end }}

{{/*
Issuer reference helper
*/}}
{{- define "silver.issuerRef" -}}
name: {{ .Values.global.tls.issuer }}
kind: ClusterIssuer
{{- end }}