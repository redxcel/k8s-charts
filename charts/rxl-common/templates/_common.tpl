{{/*
Expand the name of the chart.
*/}}
{{- define "rxl-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "rxl-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "rxl-common.fullname" -}}
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
Create a container name.
*/}}
{{- define "rxl-common.containerName" -}}
{{- default .Chart.Name .Values.containerName | trunc 63 | trimSuffix "-" }}
{{- end }}


{{- /*
Common labels

*app.kubernetes.io/<labels>*
https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/

*version*
Istio recommends a generic "version" label, but we also think its just
a nice generic label to add on top of the standard app.kubernetes.io/version
label.

*/}}
{{- define "rxl-common.labels" -}}
{{- $_tag := include "rxl-common.imageTag" . }}
{{- $tag  := $_tag | replace "@" "_" | replace ":" "_" | trunc 63 | quote -}}
helm.sh/chart: {{ include "rxl-common.chart" . }}
app.kubernetes.io/version: {{ $tag }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "rxl-common.selectorLabels" . }}
{{- end }}

{{/*
Selector labels - two functions here:
  * one for "matchLabels"
  * one for "matchExpressions"
*/}}
{{- define "rxl-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rxl-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "rxl-common.selectorLabelsExpression" -}}
- key: app.kubernetes.io/name
  operator: In
  values: [{{ include "rxl-common.name" . }}]
- key: app.kubernetes.io/instance
  operator: In
  values: [{{ .Release.Name }}]
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "rxl-common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "rxl-common.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*

Gathers the application image tag. This allows overriding the tag with a master
`forceTag` setting, as well as the more common mechanism of setting the `tag`
setting.

*/}}
{{- define "rxl-common.imageTag" -}}
{{- if .Values.image -}}
{{- default .Chart.AppVersion (default .Values.image.tag .Values.image.forceTag) }}
{{- else -}}
{{ .Chart.AppVersion }}
{{- end -}}
{{- end -}}

{{/*

Generates a fully qualified Docker image name.

*/}}
{{- define "rxl-common.imageFqdn" -}}
{{- $tag := include "rxl-common.imageTag" . }}
{{- if hasPrefix "sha256:" $tag }}
{{- .Values.image.repository }}@{{ $tag }}
{{- else }}
{{- .Values.image.repository }}:{{ $tag }}
{{- end }}
{{- end }}
