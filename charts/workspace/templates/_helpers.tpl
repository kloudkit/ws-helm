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

{{- define "workspace.projectName" -}}
{{- $ws := .Values.workspace | default dict -}}
{{- $project := dig "project" nil $ws -}}
{{- if kindIs "string" $project -}}
  {{- $project -}}
{{- else if kindIs "map" $project -}}
  {{- dig "name" "" $project -}}
{{- end -}}
{{- end -}}

{{/* workspace.projectRef: resolves a boolean-or-string project resource reference.
     Args: dict "val" <bool|string|nil> "default" <string>
     Returns: the resource name, or empty string if val is falsy. */}}
{{- define "workspace.projectRef" -}}
{{- if .val -}}{{- kindIs "string" .val | ternary .val .default -}}{{- end -}}
{{- end -}}

{{- define "workspace.envFrom" -}}
{{- $ws := .Values.workspace | default dict -}}
{{- $project := dig "project" nil $ws -}}
{{- $projectName := include "workspace.projectName" . | trim -}}
{{- $entries := list -}}
{{- if kindIs "map" $project -}}
  {{- $cmName := include "workspace.projectRef" (dict "val" (dig "sharedEnvs" false $project) "default" (printf "%s-env" $projectName)) | trim -}}
  {{- if $cmName -}}
    {{- $entries = append $entries (dict "configMapRef" (dict "name" $cmName)) -}}
  {{- end -}}
  {{- $secretName := include "workspace.projectRef" (dict "val" (dig "sharedSecrets" false $project) "default" $projectName) | trim -}}
  {{- if $secretName -}}
    {{- $entries = append $entries (dict "secretRef" (dict "name" $secretName)) -}}
  {{- end -}}
{{- end -}}
{{- range (dig "envFrom" (list) $ws) -}}
  {{- $entries = append $entries . -}}
{{- end -}}
{{- if $entries -}}{{- toYaml $entries -}}{{- end -}}
{{- end -}}

{{- define "workspace.stripPort" -}}
  {{-
    $safe := .raw  | replace "{{`{{port}}`}}" "__PORT__"
      | replace "{{port}}" "__PORT__"
  -}}
  {{- regexReplaceAll "__PORT__-?" (tpl $safe .ctx) "" -}}
{{- end -}}
