{{/*
NovaPay Digital Bank — Helm Template Helpers
Provides standard naming conventions, label management, and selector helpers.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "novapay.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "novapay.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "novapay.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels — applied to every Kubernetes resource.
Includes compliance-tier for RBI audit traceability.
*/}}
{{- define "novapay.labels" -}}
helm.sh/chart: {{ include "novapay.chart" . }}
{{ include "novapay.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: novapay-digital-bank
compliance-tier: {{ .Values.labels.complianceTier | default "critical" | quote }}
owner: {{ .Values.labels.owner | default "sre-team" | quote }}
{{- end }}

{{/*
Selector labels — used for pod selectors in deployments and services.
*/}}
{{- define "novapay.selectorLabels" -}}
app.kubernetes.io/name: {{ include "novapay.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "novapay.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "novapay.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate container image reference from repository and tag.
*/}}
{{- define "novapay.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}
