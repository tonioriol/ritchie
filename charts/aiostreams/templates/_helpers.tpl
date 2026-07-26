{{- define "aiostreams.name" -}}
aiostreams
{{- end -}}

{{- define "aiostreams.labels" -}}
app.kubernetes.io/name: {{ include "aiostreams.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
