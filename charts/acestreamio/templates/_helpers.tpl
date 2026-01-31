{{- define "acestreamio.name" -}}
acestreamio
{{- end -}}

{{- define "acestreamio.labels" -}}
app.kubernetes.io/name: {{ include "acestreamio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

