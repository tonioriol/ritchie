{{- define "clickhouse.labels" -}}
app.kubernetes.io/name: clickhouse
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
