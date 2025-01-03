{{/*
Expand the name of the chart.
*/}}
{{- define "k8s-admission.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "k8s-admission.fullname" -}}
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
{{- define "k8s-admission.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "k8s-admission.labels" -}}
helm.sh/chart: {{ include "k8s-admission.chart" . }}
{{ include "k8s-admission.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "k8s-admission.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-admission.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Pod annotations
*/}}
{{- define "k8s-admission.pod.annotations" -}}
{{- range $k, $v := .Values.podAnnotations }}
{{- $k }}: {{ $v }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Service annotations
*/}}
{{- define "k8s-admission.service.annotations" -}}
prometheus/scrape: {{ .Values.service.prometheus.enabled | quote }}
{{- range $k, $v := .Values.service.annotations }}
{{- $k }}: {{ $v }}
{{- end }}
{{- if .Values.service.prometheus.enabled }}
prometheus.io/scheme: {{ .Values.service.prometheus.scheme | quote}}
prometheus.io/path: {{ .Values.service.prometheus.path | quote}}
prometheus.io/port: {{ .Values.service.prometheus.port | quote}}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "k8s-admission.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "k8s-admission.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Renders a value that contains template.
Usage:
{{ include "k8s-admission.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "k8s-admission.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}
