{{- define "vscode.name" -}}
vscode
{{- end -}}

{{- define "vscode.labels" -}}
app.kubernetes.io/name: {{ include "vscode.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
