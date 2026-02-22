# workspace-system

Helm chart for KloudKIT Workspace cluster-wide system resources.
Provisions network policies, optional feature store, and optional Traefik ingress controller.

## Install

```sh
# OCI (recommended)
helm install workspace-system oci://ghcr.io/kloudkit/charts/workspace-system \
  --namespace workspace-system --create-namespace

# Helm repository
helm repo add kloudkit https://charts.kloudkit.com
helm install workspace-system kloudkit/workspace-system \
  --namespace workspace-system --create-namespace
```

## Configuration

```sh
# Show all available values
helm show values oci://ghcr.io/kloudkit/charts/workspace-system
```

Full documentation at **[ws.kloudkit.com](https://ws.kloudkit.com)**.
