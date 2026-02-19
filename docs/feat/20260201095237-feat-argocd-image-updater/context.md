# feat-argocd-image-updater Argo CD Image Updater (no git commits)

## TASK

Configure the cluster to automatically roll out new `ghcr.io` image tags via Argo CD Image Updater, without committing any image tag changes back into this GitOps repo.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/apps/argocd-image-updater.yaml`
* `/Users/tr0n/Code/ritchie/apps/root.yaml`
* `/Users/tr0n/Code/ritchie/apps/acestreamio.yaml`

## PLAN

Goal: when a new image is pushed to GHCR, the cluster updates the running `Deployment` automatically **without committing anything to this repo**.

This repo deploys apps GitOps-style with ArgoCD “app-of-apps” via [`apps/root.yaml`](apps/root.yaml:1). By default, that means any in-cluster mutation of `Application` objects would get reverted by ArgoCD.

To allow Argo CD Image Updater to work with write-back method `argocd` (i.e. it patches `Application.spec.source.helm.parameters`), [`apps/root.yaml`](apps/root.yaml:1) is configured to ignore diffs on:

- `Application` → `/spec/source/helm/parameters`

### 1) Install the controller

The controller is installed via ArgoCD as [`apps/argocd-image-updater.yaml`](apps/argocd-image-updater.yaml:1).

It also installs an [`ImageUpdater`](apps/argocd-image-updater.yaml:1) CR that targets the `acestreamio` ArgoCD Application.

### 2) Provide GHCR credentials (not committed)

If `ghcr.io/tonioriol/acestreamio` is private, Image Updater must authenticate to GHCR to list tags and/or inspect manifests.

Create a docker-registry secret in the `argocd` namespace:

```bash
export KUBECONFIG=./clusters/neumann/kubeconfig

kubectl -n argocd create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=tonioriol \
  --docker-password="$GHCR_PAT"
```

Notes:

- Do not commit tokens. Keep them in local `.env` or a secret manager.
- This secret is separate from (but can contain the same credentials as) `media/ghcr-pull` used by workloads.

### 3) How an automated deploy happens

1. CI in the addon repo builds and pushes images to GHCR.
2. Argo CD Image Updater detects a newer tag and patches the ArgoCD `Application` (`acestreamio`) by setting Helm parameter overrides.
3. ArgoCD notices the `Application` now renders different manifests (new image tag) and rolls the Deployment.

### 4) Recommended tagging strategy (release-only)

Best practice is to deploy **only official releases**, not every commit.

Use SemVer tags and push matching images:

- `ghcr.io/tonioriol/acestreamio:v1.0.0`

Argo CD Image Updater is configured to:

- use `semver` update strategy
- only allow tags matching `^v?\d+\.\d+\.\d+$`

See [`apps/argocd-image-updater.yaml`](apps/argocd-image-updater.yaml:1) and the `Application` annotations in [`apps/acestreamio.yaml`](apps/acestreamio.yaml:1).

## EVENT LOG

## Next Steps

- [ ] Create/update `argocd/ghcr-pull` secret (if GHCR is private)
- [ ] Push a new SemVer tag/image in the addon repo and verify Image Updater rolls the deployment

