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

- `hetzner-k3s` uses `HCLOUD_TOKEN` (not `HETZNER_TOKEN`) per the event log in [`docs/feat/2026-01-19-21-13-09-feat-k3-cluster-hetzner/context.md`](docs/feat/2026-01-19-21-13-09-feat-k3-cluster-hetzner/context.md:333).
- Single-node cluster scheduling relies on `schedule_workloads_on_masters: true` in [`clusters/neumann/cluster.yaml`](clusters/neumann/cluster.yaml:24).

## ArgoCD ingress/TLS redirect-loop fix

- TLS is terminated at Traefik; ArgoCD server must run “insecure” to avoid redirect loops: [`manifests/argocd/argocd-cmd-params-cm.yaml`](manifests/argocd/argocd-cmd-params-cm.yaml:1) sets `server.insecure: "true"`.
- That config is kept in sync via [`apps/argocd-config.yaml`](apps/argocd-config.yaml:1).

## Metrics-server (k3s TLS)

- `kubectl top …` works because [`apps/metrics-server.yaml`](apps/metrics-server.yaml:1) injects `--kubelet-insecure-tls` (k3s kubelet certs are often not verifiable in-cluster).

## Cloudflare Tunnel config (credentials-file, GitOps)

The tunnel runs in **credentials-file mode**: the local ConfigMap IS the routing config. No remote config override, no imperative API calls. ArgoCD reconciles everything.

- Tunnel identity: Secret `cloudflared/cloudflared-credentials` (key `credentials.json`, contains `AccountTag`, `TunnelID`, `TunnelSecret`) — created out-of-band, never committed.
- Routing rules: [`charts/cloudflared/values.yaml`](charts/cloudflared/values.yaml:1) `hosts:` array → rendered into ConfigMap → mounted into the cloudflared pod.
- DNS: **external-dns** (namespace `external-dns`) watches annotated Services/Ingresses and auto-creates/updates CNAME records pointing at `85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com`.

### Required env vars (all in `.env`)

| Var | Description |
|-----|-------------|
| `CF_EMAIL` | Cloudflare account e-mail (used by external-dns) |
| `CF_API_KEY` | Global API key (used by external-dns) |
| `CF_ACCOUNT_ID` | `6e73d8e42d0b50e37efc1b20401e35a0` |
| `CF_TUNNEL_ID` | `85e6bc75-0025-4fc3-9341-d4e517fea614` |

Secrets created out-of-band (never committed):
- `cloudflared/cloudflared-credentials` — tunnel credentials JSON
- `external-dns/external-dns-cloudflare` — `CF_API_KEY` + `CF_API_EMAIL`

### Adding / changing a public hostname (pure GitOps)

> **⚠️ Cloudflare Tunnel only supports one-level subdomains** (`foo.tonioriol.com`). Deep subdomains like `a.b.tonioriol.com` are **not** supported by Universal SSL. Always use a single-label prefix.

1. Edit [`charts/cloudflared/values.yaml`](charts/cloudflared/values.yaml:1) — add a new entry under `hosts:`:
   ```yaml
   - hostname: myservice.tonioriol.com
     service: http://myservice.mynamespace.svc.cluster.local:80
   ```
2. Add `externalDns.enabled: true` + `hostname` + `target` to the Service template's chart `values.yaml` (or set them in the ArgoCD Application `helm.values`).
3. Commit and push — ArgoCD auto-syncs:
   - cloudflared Deployment rolls (checksum annotation detects ConfigMap change) and picks up the new route.
   - external-dns reconciles and creates/updates the CNAME record.

That's it. No scripts, no API calls, no manual DNS clicks.

## Acestream-scraper API quirks

- The Flask `app/` package is the custom overlay maintained in `tonioriol/acestream-scraper`. It is baked into the Docker image via `pyproject.toml`.
- **Config API endpoint**: `PUT /api/config/<key>` (not `/api/v1/config/`). Each endpoint expects a specific JSON key:
  ```bash
  # Set base URL (used in playlist.m3u output) — point at acestreamio proxy, not raw Acexy
  curl -X PUT https://scraper.tonioriol.com/api/config/base_url \
    -H "Content-Type: application/json" \
    -d '{"base_url":"https://acestreamio.tonioriol.com/ace/getstream?id="}'

  # Set Ace Engine URL
  curl -X PUT https://scraper.tonioriol.com/api/config/ace_engine_url \
    -H "Content-Type: application/json" \
    -d '{"ace_engine_url":"http://localhost:6878"}'

  # Set rescrape interval (key is "hours", not "rescrape_interval")
  curl -X PUT https://scraper.tonioriol.com/api/config/rescrape_interval \
    -H "Content-Type: application/json" \
    -d '{"hours":6}'
  ```
- The **Config web UI** (`/config`) is a React SPA. If the "Update" button appears to do nothing (value disappears from the field), use the API directly — the frontend may have a bug with certain URL formats.
- **URL management**: `POST /api/urls/` to add, `DELETE /api/urls/{id}` (no trailing slash) to remove. Trailing slash on DELETE returns 404.
- **Channel data**: `GET /api/channels/` returns all channels; filter with `ch.status === 'active' && ch.is_online !== false`.
- **Ports**: Flask on `8000`, Acexy on `8080`, Acestream Engine on `6878` (all in the same pod).
- **Acexy vs raw engine**: Acexy (port 8080, cluster-internal only) is a Go proxy wrapping the engine API. Key differences:
  - Acexy **rejects the `pid` parameter** with HTTP 400 ("PID parameter is not allowed"). Never include `&pid=` in Acexy URLs.
  - Acexy only supports MPEG-TS via `/ace/getstream?id=<hash>` — no HLS (`/ace/manifest.m3u8` returns 404).
  - The raw engine (port 6878) supports both HLS and MPEG-TS, and accepts `pid`.
  - The scraper Config page has an "Add PID parameter to URLs" checkbox — must be **unchecked** when using Acexy.
- **Config is stored in SQLite** (`/app/config/acestream_scraper.db`), persisted via PVC at `/app/config`.

## Authentication

Both `acestream-scraper` and `acestreamio` are protected. Credentials are stored in 1Password (`neumann / acestream-scraper`).

### acestream-scraper auth

- All routes except `/api/health` require auth. Two methods accepted (see [`acestream-scraper/app/utils/auth.py`](../acestream-scraper/app/utils/auth.py:1)):
  - **HTTP Basic Auth**: `Authorization: Basic <base64(username:password)>` — for browsers and `curl -u`.
  - **`?token=<password>`**: embed password as query param — for media players (TiviMate, VLC) that can't do interactive auth.
- Enabled via env vars `AUTH_USERNAME` + `AUTH_PASSWORD` (injected from k8s Secret `acestream-scraper-auth`).
- k8s liveness/readiness/startup probes must use `/api/health` (auth-exempt). Any other probe path will get 401 and cause crash-loops.

### acestreamio `/ace/getstream` stream proxy

- Acexy (port 8080) is **not** publicly exposed. All stream traffic routes through `acestreamio.tonioriol.com/ace/getstream`.
- Gated by `STREAM_TOKEN` env var. When set, requests must carry `?token=<STREAM_TOKEN>`.
- The scraper auto-embeds the token in generated M3U stream URLs via `ACEXY_TOKEN` env var (same value as `STREAM_TOKEN`).
- Both secrets are in k8s Secrets and sourced from 1Password. See [`apps/acestream-scraper.yaml`](apps/acestream-scraper.yaml:1) for the ArgoCD `helm.values` override where credentials are set.

### Credential rotation

1. Update 1Password item `neumann / acestream-scraper` with new values.
2. Edit `spec.source.helm.values` in [`apps/acestream-scraper.yaml`](apps/acestream-scraper.yaml:18) and [`apps/acestreamio.yaml`](apps/acestreamio.yaml:1).
3. Commit + push to ritchie `main` → ArgoCD auto-syncs and recreates both Secrets.

## Acestream-scraper release process (CI pipeline)

- The scraper repo (`tonioriol/acestream-scraper`) is a fork of `pipepito/acestream-scraper` with custom overlay code in `app/`.
- CI/CD: [`.github/workflows/release.yml`](../acestream-scraper/.github/workflows/release.yml:1) runs **semantic-release** on every push to `main` (when `app/`, `migrations/`, `Dockerfile`, `requirements*.txt`, `wsgi.py`, etc. change).
- **NEVER** deploy manually (no `docker build`, no `docker push`, no `kubectl rollout restart`). Just push to `main` with Conventional Commits.

### Deploy steps

1. Make code changes in the `acestream-scraper` repo. Use **Conventional Commits** (`fix:`, `feat:`, `BREAKING CHANGE:`) so semantic-release can compute the version:
   ```bash
   cd ../acestream-scraper
   git add -A && git commit -m "fix: description of change"
   git push origin main
   ```

2. That's it. The CI pipeline handles everything:
   - **semantic-release** bumps the version, creates a GitHub release + git tag
   - **Docker build** builds `linux/amd64` image and pushes to `ghcr.io/tonioriol/acestream-scraper:vX.Y.Z`
   - **ArgoCD Image Updater** detects the new semver tag (polls every ~2 min) and rolls the deployment

3. Verify deployment:
   ```bash
   export KUBECONFIG=${PWD}/clusters/neumann/kubeconfig
   # Check Image Updater logs
   kubectl logs -l app.kubernetes.io/name=argocd-image-updater --tail=20 -n argocd
   # Check current image
   kubectl get deploy acestream-scraper -o jsonpath='{.spec.template.spec.containers[*].image}'
   ```

### Important notes

- The Image Updater is configured via the `ImageUpdater` CRD in [`apps/argocd-image-updater.yaml`](apps/argocd-image-updater.yaml:58) (not via Application annotations).
- The `semver` strategy + `allowTags: regexp:^v?\d+\.\d+\.\d+$` means only proper semver tags are considered.
- The chart [`charts/acestream-scraper/values.yaml`](charts/acestream-scraper/values.yaml:1) has a baseline tag but Image Updater overrides this at deploy time.
- GHCR auth: the CI pipeline uses `GHCR_PAT` secret; the cluster uses `ghcr-pull` Secret in the `argocd` namespace.
- If SSH to github.com times out, use HTTPS: `git push https://github.com/tonioriol/acestream-scraper.git main`

## kubectl context (important for agents)

- Always use the neumann cluster kubeconfig when running `kubectl` or `helm` commands: `KUBECONFIG=${PWD}/clusters/neumann/kubeconfig`.
- In terminal commands, prefix with `export KUBECONFIG=${PWD}/clusters/neumann/kubeconfig &&` or pass `--kubeconfig clusters/neumann/kubeconfig` to avoid hitting the wrong cluster context.
