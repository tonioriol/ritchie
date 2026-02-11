# ritchie

Simple GitOps repo for the `neumann` k3s cluster.

## 1) How this system works (current state)

- Public traffic goes through Cloudflare Tunnel (not direct Hetzner IP access).
- Public hostnames:
  - `https://acestreamio.tonioriol.com`
  - `https://ace.tonioriol.com`
  - `https://tv.tonioriol.com`
  - `https://neumann.tonioriol.com` (ArgoCD UI)
- Core services are internal ClusterIP; no public NodePorts for ArgoCD server / AceStream engine.

Cloudflare tunnel config is managed in [`charts/cloudflared/values.yaml`](charts/cloudflared/values.yaml:1).

## 2) How to access

### End users (normal days and ISP-block days)

Use the Cloudflare hostnames above. No WARP needed for normal app/stream usage.

### Cluster admin (`kubectl`)

- Normal path: [`clusters/neumann/kubeconfig`](clusters/neumann/kubeconfig:1)
- During ISP Hetzner blocking: turn on WARP and use [`clusters/neumann/kubeconfig.warp`](clusters/neumann/kubeconfig.warp:1)

Quick check:

```bash
KUBECONFIG=./clusters/neumann/kubeconfig.warp kubectl get nodes -o wide
```

## 3) Main components

- ArgoCD app-of-apps root: [`apps/root.yaml`](apps/root.yaml:1)
- Cloudflare tunnel connector app: [`apps/cloudflared.yaml`](apps/cloudflared.yaml:1)
- AceStream proxy chart: [`charts/acestream`](charts/acestream/Chart.yaml:1)
- Acestreamio addon chart: [`charts/acestreamio`](charts/acestreamio/Chart.yaml:1)
- IPTV relay chart: [`charts/iptv-relay`](charts/iptv-relay/Chart.yaml:1)

## 4) How deploy works (GitOps)

1. Edit manifests/charts in this repo.
2. Commit and push to `main`.
3. ArgoCD auto-sync applies changes.

ArgoCD `Application` definitions live in [`apps/`](apps/root.yaml:1). Helm charts live in [`charts/`](charts/acestream/Chart.yaml:1).

## 5) How to add a new service

1. Create a new chart in `charts/<service>/`.
2. Create `apps/<service>.yaml` ArgoCD `Application`.
3. If service must be public:
   - Add hostname route in [`charts/cloudflared/values.yaml`](charts/cloudflared/values.yaml:1)
   - Add matching Cloudflare DNS record to the tunnel.
4. Commit + push; ArgoCD deploys it.

## 6) Day-to-day maintenance (minimal)

- Check cluster/apps health:

```bash
export KUBECONFIG=./clusters/neumann/kubeconfig
kubectl get nodes -o wide
kubectl -n argocd get applications
```

- For IPTV upstream/token changes, edit the `iptv-relay` Secret in-cluster (ArgoCD is configured to ignore secret value drift in [`apps/iptv-relay.yaml`](apps/iptv-relay.yaml:15)).
- Keep secrets local. Never commit `.env` or kubeconfigs (see [`.gitignore`](.gitignore:1)).

## 7) Detailed runbook

Full Cloudflare + WARP operational notes: [`docs/feat/2026-02-08-23-33-44-feat-cloudflare-neumann-cli-runbook/context.md`](docs/feat/2026-02-08-23-33-44-feat-cloudflare-neumann-cli-runbook/context.md:1)
