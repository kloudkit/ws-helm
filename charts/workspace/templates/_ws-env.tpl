{{- define "workspace.wsEnv" -}}
  {{- $config := dig "config" dict (.Values.workspace | default dict) -}}

  {{- $promoted := list
  "server.port" "server.root_dir" "server.proxy_domain"
  "metrics.enable" "metrics.port" "metrics.collectors"
  "secrets.master_key_file"
  "features.store_url"
  -}}

  {{- $delims := dict
  "apt.additional_repos" ";"
  "metrics.collectors" ","
  -}}

  {{- range $group, $groupVals := $config }}
    {{- if not (kindIs "map" $groupVals) }}{{- continue }}{{- end }}
    {{- range $key, $val := $groupVals }}
      {{- if kindIs "invalid" $val }}{{- continue }}{{- end }}
      {{- $fullKey := printf "%s.%s" $group $key -}}
      {{- if has $fullKey $promoted }}{{- continue }}{{- end }}
      {{- $delimiter := index $delims $fullKey | default " " -}}
WS_{{ $group | upper }}_{{ $key | upper }}:
      {{- if kindIs "map" $val }}
{{ $val | toYaml | nindent 8 }}
      {{- else if kindIs "slice" $val }}
  {{ $val | join $delimiter | quote }}
      {{- else }}
  {{ $val | toString | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}
