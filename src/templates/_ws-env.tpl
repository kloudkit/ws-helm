{{- define "workspace.wsEnv" -}}
{{- $config := dig "config" dict (.Values.workspace | default dict) -}}
{{- $vars := list
  (dict "g" "apt" "k" "additional_gpg_keys" "d" " ")
  (dict "g" "apt" "k" "additional_insecure_gpg_keys" "d" " ")
  (dict "g" "apt" "k" "additional_packages" "d" " ")
  (dict "g" "apt" "k" "additional_repos" "d" ";")
  (dict "g" "apt" "k" "disable_repos" "d" " ")
  (dict "g" "apt" "k" "update_cache")
  (dict "g" "auth" "k" "disable_sudo")
  (dict "g" "auth" "k" "password")
  (dict "g" "auth" "k" "password_hashed")
  (dict "g" "ca" "k" "additional_cert_endpoints" "d" " ")
  (dict "g" "ca" "k" "additional_cert_insecure_endpoints" "d" " ")
  (dict "g" "docker" "k" "enable_client")
  (dict "g" "editor" "k" "additional_vs_extensions" "d" " ")
  (dict "g" "editor" "k" "additional_vs_extensions_dir")
  (dict "g" "editor" "k" "comments_disable_font")
  (dict "g" "editor" "k" "scrollbar_size")
  (dict "g" "editor" "k" "settings_merge")
  (dict "g" "editor" "k" "settings_merge_file")
  (dict "g" "editor" "k" "settings_override")
  (dict "g" "editor" "k" "settings_override_file")
  (dict "g" "features" "k" "additional_features" "d" " ")
  (dict "g" "features" "k" "dir")
  (dict "g" "features" "k" "store_url")
  (dict "g" "git" "k" "clear_notebook_output")
  (dict "g" "git" "k" "clone_repo")
  (dict "g" "git" "k" "credential_cache_timeout")
  (dict "g" "helm" "k" "preload_cache")
  (dict "g" "logging" "k" "dir")
  (dict "g" "logging" "k" "disable_console_output")
  (dict "g" "logging" "k" "main_file")
  (dict "g" "metrics" "k" "collectors" "d" ",")
  (dict "g" "metrics" "k" "enable")
  (dict "g" "metrics" "k" "port")
  (dict "g" "secrets" "k" "master_key")
  (dict "g" "secrets" "k" "master_key_file")
  (dict "g" "secrets" "k" "vault")
  (dict "g" "server" "k" "port")
  (dict "g" "server" "k" "proxy_domain" "d" " ")
  (dict "g" "server" "k" "root_dir")
  (dict "g" "server" "k" "ssl_cert")
  (dict "g" "server" "k" "ssl_hosts" "d" " ")
  (dict "g" "server" "k" "ssl_key")
  (dict "g" "startup" "k" "fail_on_error")
  (dict "g" "terminal" "k" "prompt_hide_docker_context")
  (dict "g" "terminal" "k" "prompt_hide_hostname")
  (dict "g" "terminal" "k" "prompt_hide_kubernetes_context")
  (dict "g" "terminal" "k" "prompt_hide_nodejs_version")
  (dict "g" "terminal" "k" "prompt_hide_python_version")
  (dict "g" "terminal" "k" "prompt_hide_user")
  (dict "g" "zsh" "k" "additional_plugins")
  (dict "g" "zsh" "k" "fzf_history_args")
  (dict "g" "zsh" "k" "fzf_history_bind")
  (dict "g" "zsh" "k" "fzf_history_dates_in_search")
  (dict "g" "zsh" "k" "fzf_history_end_of_line")
  (dict "g" "zsh" "k" "fzf_history_event_numbers")
  (dict "g" "zsh" "k" "fzf_history_extra_args")
  (dict "g" "zsh" "k" "fzf_history_query_prefix")
  (dict "g" "zsh" "k" "fzf_history_remove_duplicates")
  (dict "g" "zsh" "k" "plugins")
-}}
{{- range $vars }}
{{- $val := dig .g .k nil $config }}
{{- if not (kindIs "invalid" $val) }}
- name: WS_{{ .g | upper }}_{{ .k | upper }}
{{- if kindIs "map" $val }}
  valueFrom: {{- $val.valueFrom | toYaml | nindent 4 }}
{{- else if and (kindIs "slice" $val) (hasKey . "d") }}
  value: {{ $val | join .d | quote }}
{{- else }}
  value: {{ $val | toString | quote }}
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
{{- dig "config" "server" "root_dir" "/workspace" (.Values.workspace | default dict) -}}
{{- end -}}
