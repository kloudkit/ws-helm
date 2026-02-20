{{- define "workspace-system.namespace" -}}
{{- $s := .Values.system | default dict -}}
{{- dig "namespace" "workspace-system" $s -}}
{{- end }}
