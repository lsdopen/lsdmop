# Argo CD

This Helm chart deploys Argo CD through the official [`argo-cd`](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd) chart.

- Wrapper chart version: `0.1.0`
- Argo CD chart version: `10.9.4`
- Argo CD application version: `v3.5.3`
- Kubernetes: `1.25` or later

## Install

Build the pinned dependency and install the chart into an `argocd` namespace:

```bash
helm dependency build .
helm upgrade --install argocd . --namespace argocd --create-namespace
```

## Configure

All upstream chart settings are nested beneath the `argo-cd` key. For example:

```yaml
argo-cd:
  enabled: true
  server:
    service:
      type: LoadBalancer
```

Do not commit credentials or other sensitive values. Supply secrets through an appropriate external secret-management mechanism.

See the [upstream values](https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml) for available settings.

## Validate

```bash
helm dependency build .
helm lint .
helm template argocd . --namespace argocd --include-crds
helm template argocd . --namespace argocd --set argo-cd.enabled=false
```

The final command should render no manifests because it disables the dependency.

## Update

Change the exact dependency version in `Chart.yaml`, then regenerate the lock file and packaged dependency:

```bash
helm dependency update .
```

Review the upstream release notes and rendered manifests before deploying an update.
