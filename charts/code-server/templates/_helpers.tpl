{{- define "code-server.name" -}}
vscode
{{- end -}}

{{- define "code-server.labels" -}}
app.kubernetes.io/name: {{ include "code-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
