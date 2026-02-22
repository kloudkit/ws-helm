{{- define "workspace-system.validate" -}}
  {{- if ne .Release.Namespace "workspace-system" -}}
    {{- fail (printf "workspace-system must be installed into namespace 'workspace-system' (got '%s').\nUse: helm install --namespace workspace-system --create-namespace" .Release.Namespace) -}}
  {{- end -}}
{{- end -}}
