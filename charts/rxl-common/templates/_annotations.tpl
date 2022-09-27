{{/*

The "podAnnotations" function includes a number of broadly useful annotations
that should be applied to Pod resources created by our charts.

*/}}
{{- define "rxl-common.podAnnotations" -}}
kubectl.kubernetes.io/default-container: {{ include "rxl-common.containerName" . }}
{{- with .Values.secrets }}
checksum/secrets: {{ toYaml . | sha256sum }}
{{- end }}
{{ include "rxl-common.istioAnnotations" . }}
{{- end }}
