#!/usr/bin/env bash

release_pod() {
  local release="$1" ns="$2"
  kubectl get pod -n "$ns" \
    -l "app.kubernetes.io/instance=${release}" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}'
}

pod_ip() {
  local release="$1" ns="$2"
  kubectl get pod -n "$ns" \
    -l "app.kubernetes.io/instance=${release}" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].status.podIP}'
}

_check_connectivity() {  # exits 0 if connection succeeds
  local release="$1" ns="$2" target_ip="$3"
  kubectl exec -n "$ns" "$(release_pod "$release" "$ns")" -- \
    timeout 5 wget -q -O /dev/null "http://${target_ip}:8080/healthz" 2>/dev/null
}

_pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
_fail() { echo "[FAIL] $1 ($2)"; FAIL=$((FAIL + 1)); FAILURES+=("$1"); }

assert_allow() {
  local label="$1" release="$2" ns="$3" target_ip="$4"
  if _check_connectivity "$release" "$ns" "$target_ip"; then _pass "$label"
  else _fail "$label" "expected ALLOW, got connection failure"; fi
}

assert_deny() {
  local label="$1" release="$2" ns="$3" target_ip="$4"
  if ! _check_connectivity "$release" "$ns" "$target_ip"; then _pass "$label"
  else _fail "$label" "expected DENY, but connection succeeded"; fi
}

assert_dns() {
  local label="$1" release="$2" ns="$3"
  local pod; pod="$(release_pod "$release" "$ns")"
  if kubectl exec -n "$ns" "$pod" -- \
      nslookup kubernetes.default.svc.cluster.local 2>/dev/null | grep -q "Address"
  then _pass "$label"; else _fail "$label" "expected DNS to resolve"; fi
}

print_results() {
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed"
  if [[ ${FAIL} -gt 0 ]]; then
    echo "Failed scenarios:"
    for f in "${FAILURES[@]}"; do
      echo "  - ${f}"
    done
    return 1
  fi
  return 0
}
