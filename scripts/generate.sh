#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/../src" && pwd)"
REF="$SCRIPT_DIR/env.reference.yaml"

if [[ ! -f "$REF" ]]; then
  echo "ERROR: $REF not found" >&2
  exit 1
fi

for cmd in yq jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is required but not found" >&2
    exit 1
  fi
done

# Pre-extract all data as JSON for fast access (single yq call)
REF_JSON=$(yq -r '.' "$REF")

###############################################################################
# 1. Generate values.yaml workspace.config block
###############################################################################
generate_values_config() {
  local values_file="$CHART_DIR/values.yaml"
  local tmp_config
  tmp_config=$(mktemp)
  trap 'rm -f "${tmp_config:-}"' EXIT

  echo "  # config:" > "$tmp_config"

  echo "$REF_JSON" | jq -r '
    .envs | to_entries[] | .key as $group |
    "    # \($group):",
    (.value.properties | to_entries[] |
      .key as $prop | .value as $v |
      ((($v.longDescription // "") + " " + ($v.example // "") + " " + ($v.description // ""))
        | test("space-delimited|semicolon-delimited|comma-delimited|comma-separated"; "i")) as $is_delimited |
      (if $is_delimited then " []" else "" end) as $suffix |
      "      # -- \($v.description)\n      # Maps to: WS_\($group | ascii_upcase)_\($prop | ascii_upcase)\n      # \($prop):\($suffix)\n")
  ' >> "$tmp_config"

  # Splice into values.yaml between markers
  local before after
  before=$(sed -n '1,/# @generated:begin/p' "$values_file")
  after=$(sed -n '/# @generated:end/,$p' "$values_file")

  {
    echo "$before"
    cat "$tmp_config"
    echo ""
    echo "$after"
  } > "$values_file"
}

###############################################################################
# 2. Generate values.schema.json
###############################################################################
generate_schema() {
  local schema_file="$CHART_DIR/values.schema.json"

  echo "$REF_JSON" | jq '
    # Build config properties from envs
    def prop_schema:
      .type as $t |
      .description as $desc |
      (if $t == "boolean" then "boolean"
       elif $t == "integer" then "integer"
       else "string" end) as $jtype |
      # Check if field is delimited (allow array)
      (if $jtype == "string" then
        ((.longDescription // "") + " " + (.example // "") + " " + (.description // "")) |
        test("space-delimited|semicolon-delimited|comma-delimited|comma-separated"; "i")
       else false end) as $is_delimited |
      {
        "description": $desc,
        "oneOf": (
          [{ "type": $jtype },
           { "type": "object",
             "properties": { "valueFrom": { "type": "object" } },
             "required": ["valueFrom"],
             "additionalProperties": false },
           { "type": "null" }]
          + (if $is_delimited then [{"type": "array", "items": {"type": "string"}}] else [] end)
        )
      };

    .envs | to_entries | map(
      .key as $group |
      .value.properties | to_entries | map({key: .key, value: (.value | prop_schema)}) | from_entries |
      {($group): { "type": "object", "properties": ., "additionalProperties": false }}
    ) | add // {} |

    # Wrap in full schema
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "workspace": {
          "type": "object",
          "properties": {
            "owner": {
              "description": "Owner of this workspace (applied as ws.kloudkit.com/owner global label).",
              "type": ["string", "null"]
            },
            "project": {
              "description": "Project this workspace belongs to (applied as ws.kloudkit.com/project global label).",
              "type": ["string", "null"]
            },
            "labels": {
              "description": "Additional labels applied to all chart resources.",
              "type": ["object", "null"],
              "additionalProperties": { "type": "string" }
            },
            "annotations": {
              "description": "Additional annotations applied to all chart resources.",
              "type": ["object", "null"],
              "additionalProperties": { "type": "string" }
            },
            "timezone": {
              "description": "IANA timezone for the workspace (sets the TZ environment variable).",
              "type": ["string", "null"]
            },
            "image": { "type": "object" },
            "hostname": { "type": ["string", "null"] },
            "metrics": {
              "type": "object",
              "properties": { "enabled": { "type": "boolean" } },
              "additionalProperties": false
            },
            "persistence": { "type": "object" },
            "ingress": { "type": "object" },
            "env": { "type": "array" },
            "envFrom": { "type": "array" },
            "config": {
              "type": "object",
              "properties": .,
              "additionalProperties": false
            },
            "sidecars": { "type": "object" },
            "initContainers": { "type": "object" },
            "extraVolumes": { "type": "array" },
            "extraVolumeMounts": { "type": "array" },
            "nodeSelector": { "type": "object" },
            "tolerations": { "type": "array" },
            "affinity": { "type": "object" }
          }
        }
      }
    }
  ' > "$schema_file"

  echo "Generated $schema_file"
}

###############################################################################
# 3. Generate templates/_ws-env.tpl
###############################################################################
generate_env_tpl() {
  local tpl_file="$CHART_DIR/templates/_ws-env.tpl"

  # Build the registry: one (dict ...) entry per env var
  local registry
  registry=$(echo "$REF_JSON" | jq -r '
    def delimiter:
      ((.longDescription // "") + " " + (.description // "") + " " + (.example // "")) as $text |
      if ($text | test("semicolon-delimited"; "i")) then ";"
      elif ($text | test("space-delimited"; "i")) then " "
      elif ($text | test("comma-delimited|comma-separated"; "i")) then ","
      else "" end;

    [.envs | to_entries[] |
     .key as $group |
     .value.properties | to_entries[] |
     .key as $prop |
     .value | delimiter as $delim |
     "  (dict \"g\" \"\($group)\" \"k\" \"\($prop)\"" +
     (if $delim != "" then " \"d\" \"\($delim)\"" else "" end) +
     ")"
    ] | join("\n")
  ')

  {
    cat <<'HEADER'
{{- define "workspace.wsEnv" -}}
{{- $config := dig "config" dict (.Values.workspace | default dict) -}}
{{- $vars := list
HEADER
    echo "$registry"
    cat <<'FOOTER'
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
FOOTER
  } > "$tpl_file"

  echo "Generated $tpl_file"
}

###############################################################################
# Main
###############################################################################
echo "Generating from $REF ..."
generate_values_config
echo "Updated values.yaml config block"
generate_schema
echo "Generated schema"
generate_env_tpl
echo "Done."
