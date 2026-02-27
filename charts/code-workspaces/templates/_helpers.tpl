{{- define "code-workspaces.name" -}}
code-workspaces
{{- end -}}

{{- define "code-workspaces.labels" -}}
app.kubernetes.io/name: {{ include "code-workspaces.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
