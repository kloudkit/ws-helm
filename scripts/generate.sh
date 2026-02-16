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

# Properties promoted to top-level workspace.* keys — excluded from config generation
PROMOTED='["server.port", "server.root_dir", "server.proxy_domain", "metrics.enable", "metrics.port", "metrics.collectors", "secrets.master_key"]'

###############################################################################
# 1. Generate values.yaml workspace.config block
###############################################################################
generate_values_config() {
  local values_file="$CHART_DIR/values.yaml"
  local tmp_config
  tmp_config=$(mktemp)
  trap 'rm -f "${tmp_config:-}"' EXIT

  echo "  # config:" > "$tmp_config"

  echo "$REF_JSON" | jq -r --argjson promoted "$PROMOTED" '
    .envs | to_entries[] | .key as $group |
    # Skip groups where all properties are promoted
    (.value.properties | to_entries | map(
      "\($group).\(.key)" as $fk | select($promoted | index($fk) | not)
    )) as $non_promoted |
    if ($non_promoted | length) == 0 then empty else
    "    # \($group):",
    ($non_promoted[] |
      .key as $prop | .value as $v |
      ((($v.longDescription // "") + " " + ($v.example // "") + " " + ($v.description // ""))
        | test("space-delimited|semicolon-delimited|comma-delimited|comma-separated"; "i")) as $is_delimited |
      (if $is_delimited then " []" else "" end) as $suffix |
      "      # -- \($v.description)\n      # Maps to: WS_\($group | ascii_upcase)_\($prop | ascii_upcase)\n      # \($prop):\($suffix)\n")
    end
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

  echo "$REF_JSON" | jq --argjson promoted "$PROMOTED" '
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
      .value.properties | to_entries |
      map(select(("\($group).\(.key)" as $fk | $promoted | index($fk) | not))) |
      map({key: .key, value: (.value | prop_schema)}) | from_entries |
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
            "port": {
              "description": "Port on which the web server listens.",
              "type": ["integer", "null"]
            },
            "root": {
              "description": "Root directory for the workspace.",
              "type": ["string", "null"]
            },
            "metrics": {
              "type": "object",
              "properties": {
                "enabled": {
                  "description": "Enable Prometheus metrics exporter.",
                  "type": "boolean"
                },
                "port": {
                  "description": "Metrics endpoint port.",
                  "type": ["integer", "null"]
                },
                "interval": {
                  "description": "ServiceMonitor scrape interval.",
                  "type": ["string", "null"]
                },
                "scrapeTimeout": {
                  "description": "ServiceMonitor scrape timeout.",
                  "type": ["string", "null"]
                },
                "collectors": {
                  "description": "Comma-separated list of metric collectors to enable.",
                  "oneOf": [
                    { "type": "string" },
                    { "type": "array", "items": { "type": "string" } },
                    { "type": "null" }
                  ]
                }
              },
              "additionalProperties": false
            },
            "domains": {
              "type": "object",
              "properties": {
                "primary": {
                  "description": "Primary workspace access domain (generates exact + wildcard ingress hosts).",
                  "type": ["string", "null"]
                },
                "proxies": {
                  "description": "Additional proxy domain suffixes (contributes to WS_SERVER_PROXY_DOMAIN).",
                  "oneOf": [
                    { "type": "string" },
                    { "type": "array", "items": { "type": "string" } },
                    { "type": "null" }
                  ]
                }
              },
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
# Main
###############################################################################
echo "Generating from $REF ..."
generate_values_config
echo "Updated values.yaml config block"
generate_schema
echo "Generated schema"
echo "Done."
