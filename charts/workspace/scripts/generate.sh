#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
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
# mikefarah/yq (Go) needs -o=json; Python yq (kislyuk) outputs JSON natively with -r
if yq --version 2>&1 | grep -q 'mikefarah'; then
  REF_JSON=$(yq -o=json '.' "$REF")
else
  REF_JSON=$(yq -r '.' "$REF")
fi

# Properties promoted to top-level workspace.* keys — excluded from config generation
PROMOTED='["server.port", "server.root_dir", "server.proxy_domain", "metrics.enable", "metrics.port", "metrics.collectors", "secrets.master_key_file"]'

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

  echo "$REF_JSON" | jq --argjson promoted "$PROMOTED" \
    -f "$SCRIPT_DIR/schema.jq" > "$schema_file"

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
