# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Stack & repo layout (non-obvious)

- Tooling is provided via Devbox + direnv: [`.envrc`](.envrc:1) loads `devbox` and `dotenv_if_exists`, then exports `KUBECONFIG=${PWD}/clusters/neumann/kubeconfig`.
- Secrets live in [`.env`](.env:1) (gitignored by [`.gitignore`](.gitignore:1)); generated kubeconfigs are also ignored (`clusters/*/kubeconfig` and top-level `kubeconfig`).
- GitOps “app-of-apps”: [`apps/root.yaml`](apps/root.yaml:1) points ArgoCD at this repo (`path: apps`) and auto-syncs (`prune` + `selfHeal`). Each file in `apps/` is an ArgoCD `Application`.
- Helm charts live in `charts/` and are referenced by ArgoCD `Application.spec.source.path` (e.g. [`apps/acestream.yaml`](apps/acestream.yaml:1) -> `charts/acestream`).

## Commands / validation (there is no unit-test suite)

- Enter the toolchain (installs `kubectl`, `helm`, `argocd`): `devbox shell` (or `direnv allow` if using direnv).
- Validate Helm charts locally:
  - `helm lint charts/acestream`
  - `helm lint charts/argocd-ingress`
  - (render check) `helm template test charts/acestream | kubectl apply --dry-run=server -f -`
- Apply GitOps manifests (when needed): `kubectl apply -f apps/root.yaml` (ArgoCD will reconcile the rest).

## Acestreamio release process (addon repo)

- The addon repo (`tonioriol/acestreamio`) uses semantic-release on every push to `main`.
- Use Conventional Commits (e.g. `fix:`/`feat:`) so semantic-release can compute SemVer.
- The `Release` workflow creates the tag/release and builds `ghcr.io/tonioriol/acestreamio:vX.Y.Z`.
- ArgoCD Image Updater in this repo detects the new SemVer tag and rolls the deployment automatically.

## Cluster/provisioning gotchas

- `hetzner-k3s` uses `HCLOUD_TOKEN` (not `HETZNER_TOKEN`) per the event log in [`docs/feat/k3-cluster-hetzner/context.md`](docs/feat/k3-cluster-hetzner/context.md:333).
- Single-node cluster scheduling relies on `schedule_workloads_on_masters: true` in [`clusters/neumann/cluster.yaml`](clusters/neumann/cluster.yaml:24).

## ArgoCD ingress/TLS redirect-loop fix

- TLS is terminated at Traefik; ArgoCD server must run “insecure” to avoid redirect loops: [`manifests/argocd/argocd-cmd-params-cm.yaml`](manifests/argocd/argocd-cmd-params-cm.yaml:1) sets `server.insecure: "true"`.
- That config is kept in sync via [`apps/argocd-config.yaml`](apps/argocd-config.yaml:1).

## Metrics-server (k3s TLS)

- `kubectl top …` works because [`apps/metrics-server.yaml`](apps/metrics-server.yaml:1) injects `--kubelet-insecure-tls` (k3s kubelet certs are often not verifiable in-cluster).
