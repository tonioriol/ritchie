{{- define "code.name" -}}
code
{{- end -}}

{{- define "code.labels" -}}
app.kubernetes.io/name: {{ include "code.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
