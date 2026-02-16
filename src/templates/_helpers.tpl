{{- define "workspace.proxyDomains" -}}
  {{- $ws := .Values.workspace | default dict -}}
  {{- $all := list -}}
  {{- with (dig "domains" "primary" nil $ws) -}}
  {{- $all = append $all . -}}
  {{- end -}}
  {{- $proxies := dig "domains" "proxies" nil $ws -}}
  {{- if kindIs "string" $proxies -}}
  {{- $all = append $all $proxies -}}
  {{- else if kindIs "slice" $proxies -}}
  {{- $all = concat $all $proxies -}}
  {{- end -}}
{{- $all | toJson -}}
{{- end -}}

{{- /*
workspace.stripPort strips {{port}} / {{`{{port}}`}} placeholders
(and an optional trailing dash) from a domain string, after running tpl.
Accepts a dict with keys "raw" (the domain string) and "ctx" (root context).
*/ -}}
{{- define "workspace.stripPort" -}}
  {{- $lp := printf "%s" "{{" -}}
  {{- $rp := printf "%s" "}}" -}}
  {{- $backtickForm := printf "%s`%sport%s`%s" $lp $lp $rp $rp -}}
  {{- $plainForm := printf "%sport%s" $lp $rp -}}
  {{- $safe := .raw | replace $backtickForm "__PORT__" | replace $plainForm "__PORT__" -}}
{{- regexReplaceAll "__PORT__-?" (tpl $safe .ctx) "" -}}
{{- end -}}
