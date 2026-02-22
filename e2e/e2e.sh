#!/usr/bin/env bash

# Usage: e2e.sh [setup|run|teardown|all]
#   setup    — create kind cluster, install charts, wait for pods
#   run      — execute network policy scenarios
#   teardown — delete kind cluster and temp kubeconfig
#   all      — setup + run; teardown always runs on exit (default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLUSTER_NAME="ws-e2e"

export KUBECONFIG="${TMPDIR:-/tmp}/ws-e2e-kubeconfig"

# ── helpers ─────────────────────────────────────────────────────────────────

setup() {
  echo "==> Creating kind cluster..."
  kind create cluster --config "${SCRIPT_DIR}/kind-config.yaml" --name "${CLUSTER_NAME}"
  kubectl wait node --all --for=condition=Ready --timeout=120s

  # Free up resources: local-path-provisioner is not used in e2e tests
  kubectl scale deployment local-path-provisioner -n local-path-storage --replicas=0 &

  echo "==> Building chart dependencies..."
  helm repo add bjw-s https://bjw-s-labs.github.io/helm-charts --force-update &
  helm repo add traefik https://traefik.github.io/charts --force-update &
  wait
  helm dependency build "${REPO_ROOT}/charts/workspace-system/" &
  helm dependency build "${REPO_ROOT}/charts/workspace/" &
  wait

  echo "==> Installing system and project charts..."
  helm install workspace-system "${REPO_ROOT}/charts/workspace-system/" \
    --namespace workspace-system --create-namespace &
  helm install alpha "${REPO_ROOT}/charts/workspace-project/" \
    --namespace ws-alpha --create-namespace \
    --values "${SCRIPT_DIR}/manifests/project-alpha-values.yaml" &
  helm install beta "${REPO_ROOT}/charts/workspace-project/" \
    --namespace ws-beta --create-namespace \
    --values "${SCRIPT_DIR}/manifests/project-beta-values.yaml" &
  wait

  echo "==> Applying test pods and installing workspace releases..."
  ws_install() {
    helm install "$1" "${REPO_ROOT}/charts/workspace/" \
      --namespace "$2" --set workspace.zone="$3" --set workspace.persistence.enabled=false
  }
  kubectl apply -f "${SCRIPT_DIR}/manifests/test-pods.yaml" &
  ws_install e2e-alpha-isolated-a ws-alpha isolated &
  ws_install e2e-alpha-isolated-b ws-alpha isolated &
  ws_install e2e-alpha-project-a  ws-alpha project  &
  ws_install e2e-alpha-project-b  ws-alpha project  &
  ws_install e2e-beta-isolated-a  ws-beta  isolated &
  ws_install e2e-beta-project-a   ws-beta  project  &
  wait

  echo "==> Waiting for deployments..."
  local deployments=(
    workspace-system/e2e-global-a
    workspace-system/e2e-global-b
    ws-alpha/e2e-alpha-nginx-project
    ws-alpha/e2e-alpha-isolated-a-workspace
    ws-alpha/e2e-alpha-isolated-b-workspace
    ws-alpha/e2e-alpha-project-a-workspace
    ws-alpha/e2e-alpha-project-b-workspace
    ws-beta/e2e-beta-isolated-a-workspace
    ws-beta/e2e-beta-project-a-workspace
  )
  for nd in "${deployments[@]}"; do
    kubectl rollout status deployment/"${nd#*/}" -n "${nd%/*}" --timeout=120s &
  done
  wait

  echo "==> Setup complete."
}

run() {
  # shellcheck source=helpers.sh
  source "${SCRIPT_DIR}/helpers.sh"
  # shellcheck disable=SC2034
  PASS=0
  # shellcheck disable=SC2034
  FAIL=0
  # shellcheck disable=SC2034
  FAILURES=()

  echo "==> Running e2e network policy tests..."
  echo ""

  for scenario in "${SCRIPT_DIR}"/scenarios/*.sh; do
    echo "--- $(basename "$scenario" .sh) ---"
    # shellcheck disable=SC1090
    source "$scenario"
    echo ""
  done

  print_results
}

teardown() {
  echo "==> Tearing down..."
  kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null || true
  rm -f "${KUBECONFIG}"
  echo "==> Teardown complete."
}

# ── dispatch ─────────────────────────────────────────────────────────────────

cmd="${1:-all}"

case "$cmd" in
  setup)    setup ;;
  run)      run ;;
  teardown) teardown ;;
  all)
    trap teardown EXIT
    setup
    run
    ;;
  *)
    echo "Usage: $0 [setup|run|teardown|all]" >&2
    exit 1
    ;;
esac
