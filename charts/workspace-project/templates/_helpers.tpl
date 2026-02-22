{{- define "workspace-project.name" -}}
{{- required "project.name is required" ((.Values.project | default dict).name) -}}
{{- end }}

{{- define "workspace-project.validate" -}}
  {{- $expected := printf "ws-%s" (include "workspace-project.name" .) -}}
  {{- if ne .Release.Namespace $expected -}}
    {{- fail (printf "Release namespace '%s' must match project namespace '%s'.\nUse: helm install --namespace %s --create-namespace" .Release.Namespace $expected $expected) -}}
  {{- end -}}
{{- end -}}
