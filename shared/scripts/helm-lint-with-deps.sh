#!/usr/bin/env bash
set -euo pipefail

chart="$1"

helm repo add bjw-s https://bjw-s-labs.github.io/helm-charts --force-update
helm repo add traefik https://traefik.github.io/charts --force-update
helm dependency build "$chart"
helm lint "$chart"
