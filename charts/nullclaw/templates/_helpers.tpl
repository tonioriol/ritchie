{{- define "nullclaw.name" -}}
nullclaw
{{- end -}}

{{- define "nullclaw.labels" -}}
app.kubernetes.io/name: {{ include "nullclaw.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
