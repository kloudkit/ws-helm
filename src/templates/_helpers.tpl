{{- define "workspace.proxyDomains" -}}
  {{- $ws := .Values.workspace | default dict -}}
  {{- $primary := dig "domains" "primary" nil $ws -}}
  {{- $proxies := dig "domains" "proxies" nil $ws -}}

  {{- if kindIs "string" $proxies -}}
    {{- $proxies = list $proxies -}}
  {{- end -}}

  {{- $all := list -}}
  {{- if $primary -}}
    {{- $all = append $all $primary -}}
  {{- end -}}
  {{- if kindIs "slice" $proxies -}}
    {{- $all = concat $all $proxies -}}
  {{- end -}}

  {{- $all | toJson -}}
{{- end -}}

{{- define "workspace.stripPort" -}}
  {{-
    $safe := .raw  | replace "{{`{{port}}`}}" "__PORT__"
      | replace "{{port}}" "__PORT__"
  -}}
  {{- regexReplaceAll "__PORT__-?" (tpl $safe .ctx) "" -}}
{{- end -}}
