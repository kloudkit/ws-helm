{{- define "workspace-project.name" -}}
{{- required "project.name is required" ((.Values.project | default dict).name) -}}
{{- end }}

{{- define "workspace-project.namespace" -}}
{{- $p := .Values.project | default dict -}}
{{- if $p.namespace }}
  {{- $p.namespace -}}
{{- else }}
  {{- printf "ws-%s" (include "workspace-project.name" .) -}}
{{- end }}
{{- end }}
