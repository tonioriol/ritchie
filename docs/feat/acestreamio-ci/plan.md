# Acestreamio CI (SemVer releases) → GHCR → Argo CD Image Updater

Goal: fully automated deploys **only on releases**, without committing image bumps into this GitOps repo.

## How deploy is triggered

1) Addon repo CI builds + pushes a new image tag to GHCR (e.g. `ghcr.io/tonioriol/acestreamio:v1.2.3`).
2) Argo CD Image Updater watches GHCR and updates the `acestreamio` ArgoCD `Application` in-cluster.
3) ArgoCD re-renders the Helm chart and rolls the Deployment.

Cluster-side pieces live in this repo:
- Image Updater install: [`apps/argocd-image-updater.yaml`](apps/argocd-image-updater.yaml:1)
- App mutation allowance: [`apps/root.yaml`](apps/root.yaml:1)
- Workload chart: [`charts/acestreamio`](charts/acestreamio/Chart.yaml:1)

## Recommended “modern” SemVer generator (no manual tagging)

Use **semantic-release** in the addon repo to:
- compute next version from Conventional Commits
- create the git tag `vX.Y.Z`
- create a GitHub Release

Then a Docker workflow builds/pushes the image for that tag.

### A) Release workflow (semantic-release)

In the addon repo:

1) Add a config file (example):

```json
{
  "branches": ["main"],
  "tagFormat": "v${version}",
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    ["@semantic-release/github", {"assets": []}],
    ["@semantic-release/git", {"assets": ["CHANGELOG.md"], "message": "chore(release): ${nextRelease.version}"}]
  ]
}
```

2) Add a GitHub Actions workflow that runs on pushes to `main`.
It needs `contents: write` to push tags/releases.

## Image tag policy

Argo CD Image Updater is configured to only deploy tags that match SemVer:

- `^v?\d+\.\d+\.\d+$`

See:
- allow-tags + `semver` strategy in [`apps/argocd-image-updater.yaml`](apps/argocd-image-updater.yaml:1)

## Where the Dockerfile should live

Best practice:
- keep the Dockerfile and CI in the **addon repo** (the thing being built)
- keep Helm/ArgoCD manifests in this **GitOps repo**

This repo currently contains a bootstrap Dockerfile at [`docker/acestreamio/Dockerfile`](docker/acestreamio/Dockerfile:1), but long-term it’s cleaner to move that into the addon repo so code + build definition evolve together.

