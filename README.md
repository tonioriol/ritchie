# ritchie

GitOps repo for the **neumann** k3s cluster (Hetzner). Includes minimal notes for the legacy **ritchie** server (DigitalOcean).

---

## neumann (k3s)

| Item | Value |
|------|-------|
| Node IP | `5.75.129.215` |
| KUBECONFIG | `./clusters/neumann/kubeconfig` |

### Access

| Service | URL |
|---------|-----|
| ArgoCD UI | `https://5.75.129.215:31796` |
| AceStream proxy (HTTPS) | `https://ace.neumann.tonioriol.com` |
| AceStream engine (NodePort) | `http://5.75.129.215:30878` |
| Acestreamio addon | `https://acestreamio.neumann.tonioriol.com/manifest.json` |

### Cloudflare DNS + Tunnel (workaround for ISP Hetzner blocks)

If your ISP blocks Hetzner IP ranges (observed during football matches), put Cloudflare in front so clients connect to Cloudflare anycast IPs.

- Cloudflare zone: `tonioriol.com`
- **Registrar nameservers (set at registrar when ready to cut over):**
  - `aisha.ns.cloudflare.com`
  - `elijah.ns.cloudflare.com`
- Cloudflare Tunnel connector runs in-cluster via ArgoCD: [`apps/cloudflared.yaml`](apps/cloudflared.yaml:1) (chart: [`charts/cloudflared`](charts/cloudflared:1))
- Tunnel routes:
  - `acestreamio.neumann.tonioriol.com` → `acestreamio` service
  - `ace.neumann.tonioriol.com` → `acestream-proxy` service
  - `neumann.tonioriol.com` → `argocd-server` service

Runbook: [`plans/cloudflare-neumann-cli-runbook.md`](plans/cloudflare-neumann-cli-runbook.md:1)

### Common commands

```bash
export KUBECONFIG=./clusters/neumann/kubeconfig
kubectl get nodes -o wide
kubectl -n argocd get applications
```

---

## How deploy works (GitOps)

- Root app-of-apps: `apps/root.yaml`
- Each file in `apps/*.yaml` is an ArgoCD `Application`
- Helm charts live in `charts/*` and are referenced by those `Application` objects

Deploying changes:

1) edit `apps/*.yaml` and/or `charts/*`
2) commit + push to `main`
3) ArgoCD auto-syncs (`prune` + `selfHeal`)

### Image updates (no git commits)

`acestreamio` uses **Argo CD Image Updater** to roll out new images without committing image bumps into this repo.

- It tracks `ghcr.io/tonioriol/acestreamio:vX.Y.Z` (SemVer tags)
- When a new SemVer image is published, it patches the in-cluster ArgoCD `Application`, then ArgoCD rolls the `Deployment`

### Acestreamio release process (addon repo)

The addon repo (`tonioriol/acestreamio`) uses semantic-release on every push to `main`:

1) Commit using Conventional Commits (e.g. `fix:`/`feat:`)
2) GitHub Actions `Release` workflow computes SemVer, creates tag/release, and builds/pushes `ghcr.io/tonioriol/acestreamio:vX.Y.Z`
3) ArgoCD Image Updater detects the new tag and rolls the deployment automatically

---

## legacy ritchie (DO)

Ubuntu 16.04 server (Laravel Forge). Keep minimal changes.

| Item | Value |
|------|-------|
| Host | `ritchie.tonioriol.com` |
| IP | `188.226.140.165` |
| SSH | `ssh forge@ritchie.tonioriol.com` |

Legacy note: `ace.tonioriol.com` is the old reverse proxy path. Prefer the in-cluster endpoints above.
