{{- define "ccx.name" -}}
ccx
{{- end -}}

{{- define "ccx.labels" -}}
app.kubernetes.io/name: {{ include "ccx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
