{{- define "ws-project.name" -}}
{{- required "project.name is required" ((.Values.project | default dict).name) -}}
{{- end }}

{{- define "ws-project.namespace" -}}
{{- $p := .Values.project | default dict -}}
{{- if $p.namespace }}
  {{- $p.namespace -}}
{{- else }}
  {{- printf "ws-%s" (include "ws-project.name" .) -}}
{{- end }}
{{- end }}
