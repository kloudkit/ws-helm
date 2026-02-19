# Generates values.schema.json from env.reference.yaml JSON input.
# Expects $promoted as an --argjson binding.

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
        "firewall": {
          "description": "Firewall policy label applied to all resources (used by external NetworkPolicies). Currently recognized value: isolated.",
          "type": ["string", "null"],
          "enum": ["isolated", null]
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
        "project": {
          "description": "Project this workspace belongs to. String: sets ws.kloudkit.com/project label. Object: also enables auto-mounting shared project resources.",
          "oneOf": [
            { "type": "string" },
            {
              "type": "object",
              "properties": {
                "name": { "type": "string", "description": "Project name (sets ws.kloudkit.com/project label)." },
                "sharedEnvs": {
                  "description": "Mount project shared env ConfigMap as envFrom. true uses <project.name>-env; string overrides the ConfigMap name.",
                  "oneOf": [{"type": "boolean"}, {"type": "string"}, {"type": "null"}]
                },
                "sharedSecrets": {
                  "description": "Mount project shared Secret as envFrom. true uses <project.name>; string overrides the Secret name.",
                  "oneOf": [{"type": "boolean"}, {"type": "string"}, {"type": "null"}]
                }
              },
              "required": ["name"],
              "additionalProperties": false
            },
            { "type": "null" }
          ]
        },
        "timezone": {
          "description": "IANA timezone for the workspace (sets the TZ environment variable).",
          "type": ["string", "null"]
        },
        "image": {
          "type": "object",
          "properties": {
            "repository": {
              "description": "Container image repository.",
              "type": "string"
            },
            "tag": {
              "description": "Container image tag (defaults to Chart.AppVersion).",
              "type": "string"
            },
            "pullPolicy": {
              "description": "Image pull policy.",
              "type": "string",
              "enum": ["Always", "IfNotPresent", "Never"]
            }
          },
          "additionalProperties": false
        },
        "hostname": {
          "description": "Hostname assigned to the workspace pod (supports Helm templating).",
          "type": ["string", "null"]
        },
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
        "persistence": {
          "type": "object",
          "properties": {
            "enabled": {
              "description": "Enable persistent volume claim.",
              "type": "boolean"
            },
            "type": {
              "description": "Volume type.",
              "type": "string"
            },
            "existingClaim": {
              "description": "Use an existing PVC instead of creating a new one.",
              "type": ["string", "null"]
            },
            "storageClass": {
              "description": "StorageClass name (null uses the cluster default).",
              "type": ["string", "null"]
            },
            "size": {
              "description": "Requested storage size.",
              "type": "string"
            },
            "accessMode": {
              "description": "PVC access mode.",
              "type": "string"
            },
            "additionalPaths": {
              "description": "Additional paths mounted from the same PVC (each gets its own subPath).",
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "name": { "type": "string" },
                  "path": { "type": "string" }
                },
                "required": ["name", "path"]
              }
            },
            "extra": {
              "description": "Additional bjw-s persistence entries (emptyDir, configMap, secret, etc.) rendered alongside the main workspace PVC.",
              "type": "object",
              "additionalProperties": {
                "type": "object"
              }
            }
          },
          "additionalProperties": false
        },
        "ingress": {
          "type": "object",
          "properties": {
            "enabled": {
              "description": "Create an Ingress resource.",
              "type": "boolean"
            },
            "className": {
              "description": "Ingress class name.",
              "type": ["string", "null"]
            },
            "tls": {
              "description": "TLS configuration (list of secrets).",
              "type": "array"
            },
            "annotations": {
              "description": "Additional ingress annotations.",
              "type": ["object", "null"],
              "additionalProperties": { "type": "string" }
            }
          },
          "additionalProperties": false
        },
        "secrets": {
          "type": "object",
          "properties": {
            "masterKey": {
              "description": "User-provided master key. When set, takes priority over auto-generation.",
              "type": ["string", "null"]
            },
            "autoGenerateMasterKey": {
              "description": "Auto-generate a 64-char cryptographic key on first install.",
              "type": "boolean"
            }
          },
          "additionalProperties": false
        },
        "env": {
          "description": "Additional env vars passed directly to the container.",
          "type": ["object", "array"]
        },
        "envFrom": {
          "description": "Additional envFrom sources (secrets/configmaps).",
          "type": "array"
        },
        "securityContext": {
          "description": "Security context for the main container.",
          "type": ["object", "null"]
        },
        "resources": {
          "description": "Container resource requests and limits.",
          "type": ["object", "null"],
          "properties": {
            "requests": {
              "type": "object",
              "properties": {
                "cpu": { "type": ["string", "number", "null"] },
                "memory": { "type": ["string", "null"] }
              }
            },
            "limits": {
              "type": "object",
              "properties": {
                "cpu": { "type": ["string", "number", "null"] },
                "memory": { "type": ["string", "null"] }
              }
            }
          }
        },
        "config": {
          "type": "object",
          "properties": .,
          "additionalProperties": false
        },
        "sidecars": { "type": "object" },
        "initContainers": { "type": "object" },
        "nodeSelector": { "type": "object" },
        "tolerations": { "type": "array" },
        "affinity": { "type": "object" }
      }
    }
  }
}
