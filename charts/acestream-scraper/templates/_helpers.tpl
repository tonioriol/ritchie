{{- define "acestream-scraper.labels" -}}
app.kubernetes.io/name: acestream-scraper
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
