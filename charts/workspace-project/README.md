# workspace-project

Helm chart for KloudKIT Workspace project namespaces.
Provisions namespace, network policies, resource quotas, and shared storage for multi-workspace environments.

## Install

```sh
# OCI (recommended)
helm install my-project oci://ghcr.io/kloudkit/charts/workspace-project

# Helm repository
helm repo add kloudkit https://charts.kloudkit.com
helm install my-project kloudkit/workspace-project
```

## Configuration

```sh
# Show all available values
helm show values oci://ghcr.io/kloudkit/charts/workspace-project
```

Full documentation at **[ws.kloudkit.com](https://ws.kloudkit.com)**.
