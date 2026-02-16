{{- define "workspace.wsEnv" -}}
{{- $config := dig "config" dict (.Values.workspace | default dict) -}}

{{- /* Delimiter exceptions — all other delimited fields default to space */ -}}
{{- $delims := dict
  "apt.additional_repos" ";"
  "metrics.collectors" ","
-}}

{{- range $group, $groupVals := $config }}
  {{- if not (kindIs "map" $groupVals) }}{{- continue }}{{- end }}
  {{- range $key, $val := $groupVals }}
    {{- if kindIs "invalid" $val }}{{- continue }}{{- end }}
    {{- $fullKey := printf "%s.%s" $group $key }}
    {{- $delimiter := index $delims $fullKey | default " " }}
WS_{{ $group | upper }}_{{ $key | upper }}:
    {{- if kindIs "map" $val }}
  {{- $val | toYaml | nindent 2 }}
    {{- else if kindIs "slice" $val }}
  {{ $val | join $delimiter | quote }}
    {{- else }}
  {{ $val | toString | quote }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "workspace.serverPort" -}}
{{- $ws := .Values.workspace | default dict -}}
{{- dig "config" "server" "port" 8080 $ws -}}
{{- end -}}

{{- define "workspace.metricsPort" -}}
{{- $ws := .Values.workspace | default dict -}}
{{- dig "config" "metrics" "port" 9100 $ws -}}
{{- end -}}

{{- define "workspace.serverRoot" -}}
{{- $ws := .Values.workspace | default dict -}}
{{- dig "config" "server" "root_dir" "/workspace" $ws -}}
{{- end -}}
