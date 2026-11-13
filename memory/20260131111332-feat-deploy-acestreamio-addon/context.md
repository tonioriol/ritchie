---
title: "feat-deploy-acestreamio-addon Deploy Acestreamio (Stremio addon) to neumann"
status: done
created: 2026-01-31
---

# feat-deploy-acestreamio-addon Deploy Acestreamio (Stremio addon) to neumann

## TASK

Deploy the Acestreamio Stremio addon onto the `neumann` k3s cluster using this GitOps repo (ArgoCD + Helm), including the container image build/push, Kubernetes secret creation, DNS, and validation.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/docker/acestreamio/Dockerfile`
* `/Users/tr0n/Code/ritchie/charts/acestreamio/values.yaml`
* `/Users/tr0n/Code/ritchie/charts/acestreamio/templates/deployment.yaml`
* `/Users/tr0n/Code/ritchie/charts/acestreamio/templates/service.yaml`
* `/Users/tr0n/Code/ritchie/apps/acestreamio.yaml`
* `/Users/tr0n/Code/ritchie/docs/feat/2026-01-21-00-13-56-fix-ace-neumann/context.md`

## PLAN

This repo is **GitOps-first**: ArgoCD applies everything under [`apps/`](apps:1) automatically via the “root” app.

### 1) Build & push the addon image

The addon code currently lives outside this repo at `/Users/tr0n/Code/acestreamio`, but we keep the Kubernetes deployment manifests in this repo.

Build using the Dockerfile committed here at [`docker/acestreamio/Dockerfile`](docker/acestreamio/Dockerfile:1), with the addon directory as build context:

```bash
docker build \
  -f /Users/tr0n/Code/ritchie/docker/acestreamio/Dockerfile \
  -t ghcr.io/tonioriol/acestreamio:main \
  /Users/tr0n/Code/acestreamio

docker push ghcr.io/tonioriol/acestreamio:main
```

### 2) Create/update the secret (not committed)

The Helm chart references a Secret named `acestreamio` (optional). Create it in the `media` namespace:

```bash
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig

kubectl -n media create secret generic acestreamio \
  --from-literal=STREMIO_KEY='...' \
  --dry-run=client -o yaml \
  | kubectl apply -f -
```

### 3) Ensure DNS exists

Point the desired hostname to the cluster node IP (`5.75.129.215`). Traefik is hostNetwork-bound to `:80/:443`.

#### DigitalOcean DNS (doctl)

List existing records (so you can decide whether to create or update):

```bash
doctl compute domain records list tonioriol.com --format ID,Type,Name,Data,TTL
```

If the record does not exist yet, create it (example for `acestreamio.neumann.tonioriol.com`):

```bash
doctl compute domain records create tonioriol.com \
  --record-type A \
  --record-name acestreamio.neumann \
  --record-data 5.75.129.215 \
  --record-ttl 30
```

If it exists already, update it (replace `RECORD_ID`):

```bash
doctl compute domain records update tonioriol.com \
  --record-id RECORD_ID \
  --record-data 5.75.129.215 \
  --record-ttl 30
```

#### Recommended: avoid per-app DNS by using a wildcard under neumann

If you want every app to get a name like `something.neumann.tonioriol.com`, create a single wildcard record once:

```bash
doctl compute domain records create tonioriol.com \
  --record-type A \
  --record-name '*.neumann' \
  --record-data 5.75.129.215 \
  --record-ttl 30
```

This chart already defaults to `acestreamio.neumann.tonioriol.com`; override [`charts/acestreamio/values.yaml`](charts/acestreamio/values.yaml:1) if you prefer another hostname.

### 4) Deploy via ArgoCD

Kubernetes resources live in:

- Helm chart: [`charts/acestreamio`](charts/acestreamio:1)
- ArgoCD Application: [`apps/acestreamio.yaml`](apps/acestreamio.yaml:1)

After these changes are pushed to `main`, ArgoCD should auto-sync.

If you deploy `external-dns`, the DNS record for the Ingress host can be created/maintained automatically (no `doctl` step required).

### 5) Install in Stremio

Use:

```
https://acestreamio.neumann.tonioriol.com/manifest.json
```

### Playback troubleshooting notes

- The addon only returns stream *URLs*. Actual playback depends on the Acestream engine + proxy being able to produce HLS playlists.
- Some IDs will work and others will time out (this is expected; see the findings in [`docs/feat/2026-01-21-00-13-56-fix-ace-neumann/context.md`](docs/feat/2026-01-21-00-13-56-fix-ace-neumann/context.md:1)).
- Some players probe `.m3u8` URLs with `HEAD`; the proxy config converts/handles this, but the engine itself may still not implement `HEAD`.

If you want the addon to use the in-cluster proxy hostname, set `PROXY_URL=https://ace.neumann.tonioriol.com` via the `acestreamio` Secret referenced by [`charts/acestreamio/templates/deployment.yaml`](charts/acestreamio/templates/deployment.yaml:36).

## EVENT LOG

## Next Steps

- [x] Build and push `ghcr.io/tonioriol/acestreamio:main` (or a SemVer tag if using Image Updater) — **done** (2026-11-08): built by the acestreamio release workflow (semantic-release, `.releaserc.json`); latest tag v1.17.2 is live
- [x] ~~Create `media/acestreamio` secret with required runtime config~~ — **obsolete** (2026-11-08): runtime config is inline in `apps/acestreamio.yaml` (`streamToken`), no separate secret
- [x] Ensure DNS points at the cluster (manual `doctl` or external-dns) — **done** (2026-11-08): tunnel route `acestreamio.tonioriol.com` in `charts/cloudflared/values.yaml:28`
- [x] Verify addon manifest loads and playback works for known IDs — **done** (2026-11-08): manifest 200 (v1.17.2), 2027 channels loaded; playback not re-tested 2026-11-08

### 2026-11-08 17:00 — Stale open steps closed out against live state

- Evidence: `curl https://acestreamio.tonioriol.com/manifest.json` → 200, version 1.17.2; pod `acestreamio-8bd5bfc4d-qxjbp` (rolled 2026-10-28) logs `Fetched 2027 channels`. Stream playback itself was not exercised in this check.
