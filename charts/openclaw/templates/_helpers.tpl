{{- define "openclaw.name" -}}
openclaw
{{- end -}}

{{- define "openclaw.labels" -}}
app.kubernetes.io/name: {{ include "openclaw.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
