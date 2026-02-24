# ritchie

Simple GitOps repo for the `neumann` k3s cluster.

## 1) How this system works (current state)

- Public traffic goes through Cloudflare Tunnel (not direct Hetzner IP access).
- Public hostnames:
  - `https://acestreamio.tonioriol.com` — Stremio addon
  - `https://ace.tonioriol.com` — Acexy stream proxy
  - `https://scraper.tonioriol.com` — Acestream-scraper web UI & API
  - `https://tv.tonioriol.com` — IPTV relay
  - `https://neumann.tonioriol.com` — ArgoCD UI
- Core services are internal ClusterIP; no public NodePorts for ArgoCD server / AceStream engine.

Cloudflare tunnel runs in credentials-file mode — routing config is in [`charts/cloudflared/values.yaml`](charts/cloudflared/values.yaml:1); DNS CNAMEs are managed automatically by **external-dns**.

## 2) How to access

### End users (normal days and ISP-block days)

Use the Cloudflare hostnames above. No WARP needed for normal app/stream usage.

### Cluster admin (`kubectl`)

- Normal path: [`clusters/neumann/kubeconfig`](clusters/neumann/kubeconfig:1)
- During ISP Hetzner blocking: turn on WARP and use [`clusters/neumann/kubeconfig.warp`](clusters/neumann/kubeconfig.warp:1)

Quick check (from workspace root):

```bash
KUBECONFIG=ritchie/clusters/neumann/kubeconfig kubectl get nodes -o wide
# During ISP blocking:
KUBECONFIG=ritchie/clusters/neumann/kubeconfig.warp kubectl get nodes -o wide
```

## 3) Main components

- ArgoCD app-of-apps root: [`apps/root.yaml`](apps/root.yaml:1)
- Cloudflare tunnel connector app: [`apps/cloudflared.yaml`](apps/cloudflared.yaml:1)
- Acestream-scraper (channel scraper + web UI): [`charts/acestream-scraper`](charts/acestream-scraper/Chart.yaml:1) — `default` ns
- Acestream engine: [`charts/acestream`](charts/acestream/Chart.yaml:1) — `media` ns (includes acestream-proxy sidecar)
- Acexy (Go stream proxy, token-gated): [`charts/acexy`](charts/acexy/Chart.yaml:1) — `media` ns
- Acestreamio Stremio addon: [`charts/acestreamio`](charts/acestreamio/Chart.yaml:1) — `media` ns
- IPTV relay: [`charts/iptv-relay`](charts/iptv-relay/Chart.yaml:1) — `media` ns

Also running in cluster:
- 1Password Connect + External Secrets Operator: [`apps/onepassword-connect.yaml`](apps/onepassword-connect.yaml:1), [`apps/external-secrets.yaml`](apps/external-secrets.yaml:1), [`apps/external-secrets-config.yaml`](apps/external-secrets-config.yaml:1)
- cert-manager: [`apps/cert-manager.yaml`](apps/cert-manager.yaml:1)
- external-dns (Cloudflare): [`apps/external-dns.yaml`](apps/external-dns.yaml:1)
- metrics-server: [`apps/metrics-server.yaml`](apps/metrics-server.yaml:1)
- vscode: [`apps/vscode.yaml`](apps/vscode.yaml:1)
- argocd image updater: [`apps/argocd-image-updater.yaml`](apps/argocd-image-updater.yaml:1)

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
   - Set `externalDns.enabled: true` + `hostname` + `target` in the chart's `values.yaml` (or in the ArgoCD Application `helm.values`) — external-dns will create the CNAME automatically.
4. Commit + push; ArgoCD deploys it.

## 6) Day-to-day maintenance (minimal)

- Check cluster/apps health:

```bash
KUBECONFIG=ritchie/clusters/neumann/kubeconfig kubectl get nodes -o wide
KUBECONFIG=ritchie/clusters/neumann/kubeconfig kubectl -n argocd get applications
```

- Common ops commands:

```bash
# all Argo apps with health/sync
KUBECONFIG=ritchie/clusters/neumann/kubeconfig kubectl -n argocd get applications.argoproj.io \
  -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status \
  --sort-by=.metadata.name

# services and exposure
kubectl get svc -A

# ingress hostnames
kubectl get ingress -A

# cloudflared connector health/logs
kubectl -n cloudflared get pods
kubectl -n cloudflared logs deploy/cloudflared --tail=100

# Argo app details (replace APP)
kubectl -n argocd describe application <APP>

# force one app refresh/sync from CLI (if needed)
argocd app get <APP>
argocd app sync <APP>
```

- For IPTV upstream/token changes, edit the `iptv-relay` Secret in-cluster (ArgoCD is configured to ignore secret value drift in [`apps/iptv-relay.yaml`](apps/iptv-relay.yaml:15)).
- `argocd-ingress` health is kept green by publishing a fixed Ingress endpoint IP from Traefik (`providers.kubernetesIngress.ingressEndpoint.ip`) in [`apps/traefik.yaml`](apps/traefik.yaml:13), so Ingress gets a non-empty `.status.loadBalancer`.
- Keep secrets local. Never commit `.env` or kubeconfigs (see [`.gitignore`](.gitignore:1)).

## 7) Secrets management (1Password + ESO)

All application secrets are stored in the **1Password vault `neumann`** and synced to Kubernetes via **External Secrets Operator (ESO)** → **1Password Connect**.

### Architecture

```
1Password vault "neumann"
  └─ item "acestream-scraper"
       ├─ username   → AUTH_USERNAME  (acestream-scraper)
       └─ password   → AUTH_PASSWORD  (acestream-scraper)
                     → ACEXY_TOKEN    (acexy)
                     → STREAM_TOKEN   (acestreamio)
```

All three services share the **same password** from the single 1Password item. This simplifies rotation — change one field, everything updates.

### 1Password account

The `neumann` vault lives on the **personal** 1Password account:
- **Account**: `my.1password.com` (`tonioriol@gmail.com`)
- **Account UUID**: `PRBEZ6ELGNCMDIK6YVMRW5TTXQ`
- **Vault**: `neumann` (ID `xuk2fqgwzzf3iqybuq7pidwgnq`)

When using `op` CLI, always pass `--account PRBEZ6ELGNCMDIK6YVMRW5TTXQ` (or `--account my.1password.com`).

### 1Password items

| 1P Item | Vault | Fields | Used By |
|---------|-------|--------|---------|
| `acestream-scraper` (ID `hthexfrtih57dr5gf2dighfa4e`) | `neumann` | `username`, `password` | acestream-scraper (Basic Auth + `?token=`), acexy (`ACEXY_TOKEN`), acestreamio (`STREAM_TOKEN`) |

> **Note**: The `password` field is used as the token everywhere — the `?token=` param in M3U URLs, `ACEXY_TOKEN`, and `STREAM_TOKEN` all use this same value. The `stream token` field in 1P is a legacy leftover and is **not** read by any ExternalSecret.

### Kubernetes Secrets (created by ESO)

| Secret Name | Namespace | Keys | Source |
|-------------|-----------|------|--------|
| `acestream-scraper-auth` | `default` | `AUTH_USERNAME`, `AUTH_PASSWORD` | 1P `acestream-scraper` → `username`, `password` |
| `acexy-auth` | `media` | `ACEXY_TOKEN` | 1P `acestream-scraper` → `password` |

### ExternalSecret definitions

- [`charts/acestream-scraper/templates/externalsecret.yaml`](charts/acestream-scraper/templates/externalsecret.yaml:1) — refreshes every 1h
- [`charts/acexy/templates/externalsecret.yaml`](charts/acexy/templates/externalsecret.yaml:1) — refreshes every 1h

### Auto-reload on secret change

[Stakater Reloader](https://github.com/stakater/Reloader) is deployed via [`apps/reloader.yaml`](apps/reloader.yaml:1). Both Deployments carry `secret.reloader.stakater.com/reload` annotations — when ESO syncs a new secret value from 1Password, Reloader triggers a rolling restart automatically.

### Credential rotation

1. Open **1Password** → vault `neumann` → item `acestream-scraper`
2. Edit the `password` field (and/or `username`)
3. Wait up to **1 hour** for ESO to sync (or force: `kubectl annotate externalsecret <name> force-sync=$(date +%s) --overwrite`)
4. Stakater Reloader will automatically restart affected pods
5. Update your M3U player URL with the new `?token=<password>` value

### Out-of-band secrets (not in ESO)

| Secret | Namespace | How to create |
|--------|-----------|---------------|
| `op-credentials` | `kube-system` | `kubectl -n kube-system create secret generic op-credentials --from-literal=1password-credentials.json="$(base64 < creds.json)"` |
| `onepassword-connect-token` | `kube-system` | `kubectl -n kube-system create secret generic onepassword-connect-token --from-literal=token=<ESO_TOKEN>` |
| `ghcr-pull` | `default`, `media`, `argocd` | Docker registry secret for GHCR |
| `cloudflared-credentials` | `cloudflared` | Cloudflare Tunnel credentials JSON |

## 8) Detailed runbook

Full Cloudflare + WARP operational notes: [`docs/feat/2026-02-08-23-33-44-feat-cloudflare-neumann-cli-runbook/context.md`](docs/feat/2026-02-08-23-33-44-feat-cloudflare-neumann-cli-runbook/context.md:1)
