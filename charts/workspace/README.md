# workspace

Helm chart for [KloudKIT Workspace](https://ws.kloudkit.com), a browser-based development environment.

## Install

```sh
# OCI (recommended)
helm install my-workspace oci://ghcr.io/kloudkit/charts/workspace

# Helm repository
helm repo add kloudkit https://charts.kloudkit.com
helm install my-workspace kloudkit/workspace
```

## Configuration

```sh
# Show all available values
helm show values oci://ghcr.io/kloudkit/charts/workspace
```

Full documentation at **[ws.kloudkit.com](https://ws.kloudkit.com)**.
