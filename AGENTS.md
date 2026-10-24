# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Stack & repo layout (non-obvious)

- Tooling is provided via Homebrew (`kubernetes-cli`, `helm@3`, `argocd`) + mise: [`mise.toml`](mise.toml:1) adds `helm@3` to PATH, loads `.env`, then sets `KUBECONFIG` to `clusters/neumann/kubeconfig` (interactive shells with `mise activate`). **Note:** that env is not active for agents; always use the explicit kubeconfig path shown in the [kubectl context](#kubectl-context-important-for-agents) section below.
- Secrets live in [`.env`](.env:1) (gitignored by [`.gitignore`](.gitignore:1)); generated kubeconfigs are also ignored (`clusters/*/kubeconfig` and top-level `kubeconfig`).
- GitOps “app-of-apps”: [`apps/root.yaml`](apps/root.yaml:1) points ArgoCD at this repo (`path: apps`) and auto-syncs (`prune` + `selfHeal`). Each file in `apps/` is an ArgoCD `Application`.
- Helm charts live in `charts/` and are referenced by ArgoCD `Application.spec.source.path` (e.g. [`apps/acestream.yaml`](apps/acestream.yaml:1) -> `charts/acestream`).

## Commands / validation (there is no unit-test suite)

- Install the toolchain: `brew install kubernetes-cli helm@3 argocd`, then `mise trust` to load [`mise.toml`](mise.toml:1).
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

The tunnel runs in **credentials-file mode**: the local ConfigMap IS the routing config. ArgoCD reconciles everything.

- Tunnel identity: Secret `cloudflared/cloudflared-credentials` (key `credentials.json`, contains `AccountTag`, `TunnelID`, `TunnelSecret`) — created out-of-band, never committed.
- Routing rules: [`charts/cloudflared/values.yaml`](charts/cloudflared/values.yaml:1) `hosts:` array → rendered into ConfigMap → mounted into the cloudflared pod.
- DNS: **external-dns** (namespace `external-dns`) watches annotated Services/Ingresses and auto-creates/updates CNAME records pointing at `85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com`.

> **⚠️ Remote config override**: The Cloudflare API has a remote tunnel configuration (managed via Zero Trust dashboard) that **overrides the local ConfigMap** on startup. When adding a new hostname, you must also update the remote config via the API:
> ```bash
> curl -X PUT "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations" \
>   -H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_API_KEY" \
>   -H "Content-Type: application/json" \
>   -d '{"config":{"ingress":[...all hostnames...,{"service":"http_status:404"}],"warp-routing":{"enabled":true}}}'
> ```
> Alternatively, delete the remote config entirely to let the local ConfigMap be authoritative.

### Required env vars (all in `.env`)

| Var | Description |
|-----|-------------|
| `CF_EMAIL` | Cloudflare account e-mail |
| `CF_API_KEY` | Global API key (account-wide; only for manual admin calls) |
| `CF_ACCOUNT_ID` | `6e73d8e42d0b50e37efc1b20401e35a0` |
| `CF_TUNNEL_ID` | `85e6bc75-0025-4fc3-9341-d4e517fea614` |

Secrets created out-of-band (never committed):
- `cloudflared/cloudflared-credentials` — tunnel credentials JSON

external-dns authenticates with a **scoped API token**, not the Global API key.
Token `external-dns-neumann` (ID `d7860720590ddbe6229d9176625ceed4`) grants only
`Zone:Read` + `DNS:Write` on the `tonioriol.com` zone. It lives in 1Password
(`neumann` vault, item `cloudflare-external-dns`, field `api_token`) and reaches
the cluster as `external-dns/external-dns-cloudflare-token` → `CF_API_TOKEN` via
the ExternalSecret in [`charts/external-secrets-config`](charts/external-secrets-config/templates/external-dns-cloudflare.yaml:1).
Rotate by editing the 1Password field; Reloader rolls the Deployment.

> The Global API key acts as the account owner, so every DNS change external-dns
> made was logged in the Cloudflare audit log as a human action. The scoped token
> is attributed to itself, and cannot touch anything outside this one zone.

### Adding / changing a public hostname (pure GitOps)

> **⚠️ Cloudflare Tunnel only supports one-level subdomains** (`foo.tonioriol.com`). Deep subdomains like `a.b.tonioriol.com` are **not** supported by Universal SSL. Always use a single-label prefix.

1. Edit [`charts/cloudflared/values.yaml`](charts/cloudflared/values.yaml:1) — add a new entry under `hosts:`:
   ```yaml
   - hostname: myservice.tonioriol.com
     service: http://myservice.mynamespace.svc.cluster.local:80
   ```
2. Add `externalDns.enabled: true` + `hostname` + `target` to the Service template's chart `values.yaml` (or set them in the ArgoCD Application `helm.values`).
3. **Critical**: Add `external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"` annotation to the Service. Without this, external-dns creates DNS records with `proxied: false` (grey cloud), which breaks tunnel routing — `cfargotunnel.com` resolves to a private IPv6 address instead of Cloudflare Anycast IPs.
4. Update the Cloudflare remote tunnel config via the API (see warning above) to include the new hostname.
5. Commit and push — ArgoCD auto-syncs:
   - cloudflared Deployment rolls (checksum annotation detects ConfigMap change) and picks up the new route.
   - external-dns reconciles and creates/updates the CNAME record (proxied).

## Acestream catalog, Acexy and engine

- The Flask acestream-scraper is retired (ArgoCD app, chart and tunnel route removed); only its PVC `media/acestream-scraper-config` (PV `Retain`, old SQLite DB) is kept on purpose. Its 1Password item is still named `acestream-scraper`.
- **acestream-catalog** (Rust, repo `acestream-catalog/`) replaces it: app [`apps/acestream-catalog.yaml`](apps/acestream-catalog.yaml:1), chart [`charts/acestream-catalog`](charts/acestream-catalog/Chart.yaml:1), ns `media`, public `https://catalog.tonioriol.com`, internal `acestream-catalog.media.svc:80` (container `8080`). Operate it with the global `acestream-catalog` skill; code, admin API and release live in [`acestream-catalog/AGENTS.md`](../acestream-catalog/AGENTS.md:1) — don't duplicate them here.
  - Feeds take `?token=<FEED_TOKEN>`: `/api/playlists/tv-channels/m3u` (alias `/playlist.m3u`), `/api/playlists/epg.xml`, `/api/channels/`. `/health` is unauthenticated. The admin API uses `Authorization: Bearer <ADMIN_TOKEN>`.
  - The chart pins `image.tag: latest`, overridden in [`apps/acestream-catalog.yaml`](apps/acestream-catalog.yaml:1); Image Updater does not track it. The manual release flow was selected during a GitHub Actions billing block; recheck current CI rather than assuming the block persists.
- **acestreamio** reads channels from the catalog (`env.scraperApiUrl` in [`charts/acestreamio/values.yaml`](charts/acestreamio/values.yaml:1); key name is code-facing).
- **Ports** (all `media` ns): catalog `8080` (Service `80`), Acexy `8080`, Acestream Engine `6878`.
- **Acexy vs raw engine**: Acexy (`ace.tonioriol.com`, publicly exposed via CF tunnel, token-gated by `ACEXY_TOKEN`) is a Go proxy wrapping the engine API. Key differences:
   - Acexy **rejects the `pid` parameter** with HTTP 400 ("PID parameter is not allowed"). Never include `&pid=` in Acexy URLs.
   - Acexy supports both `?id=<hash>` and `?infohash=<hash>` for `/ace/getstream`. **Always use `?infohash=`** — the `?id=` parameter requires acestream's content server (decommissioned since April 2026).
   - Acexy only supports MPEG-TS — no HLS (`/ace/manifest.m3u8` returns 404).
   - The raw engine (port 6878) supports both HLS and MPEG-TS, and accepts `pid`.
- **Acestream engine image**: Custom `ghcr.io/tonioriol/acestream-engine:latest` based on `jopsis/acestream:latest` (engine 3.2.17). Includes attestation bypass via `ssl_fix.py` — patches Python SSL/socket to redirect attestation requests to a local fake HTTPS server. Source: [`docs/feat/20260510225602-acestream-scraper-health-audit/Dockerfile`](../docs/feat/20260510225602-acestream-scraper-health-audit/Dockerfile:1).

## Authentication

Credentials live in 1Password (`neumann` vault) and are injected into the cluster via **External Secrets Operator (ESO) + 1Password Connect**.

### Secret management architecture

- **1Password Connect** runs in-cluster (`1password` namespace) as the bridge between ESO and the 1Password cloud.
- **ClusterSecretStore** `onepassword` points ESO at Connect's API (`http://onepassword-connect.1password.svc.cluster.local:8080`).
- **ExternalSecret** CRs in each app's Helm chart pull individual fields from the 1Password item and create k8s Secrets.
- No plaintext credentials in git. Charts only toggle `auth.enabled`.

### Out-of-band secrets (not in git, pre-created manually)

Two secrets in `1password` namespace must exist before Connect can start:

| Secret | Key | Content |
|--------|-----|---------|
| `op-credentials` | `1password-credentials.json` | Base64-encoded Connect credentials file (from `op connect server create`) |
| `onepassword-token` | `token` | Connect access token JWT (from `op connect token create`) |

These are **never** stored in git. If the cluster is rebuilt, recreate them:
```bash
# 1. Get credentials file from 1Password (already base64-encoded inside)
#    The file is from: op connect server create neumann-k8s --vaults neumann
# 2. Base64-encode the JSON file content (Connect expects double-base64)
base64 < 1password-credentials.json | tr -d '\n' > creds-b64.txt
# 3. Create secrets
KUBECONFIG=ritchie/clusters/neumann/kubeconfig kubectl create ns 1password
KUBECONFIG=ritchie/clusters/neumann/kubeconfig kubectl create secret generic op-credentials -n 1password --from-file=1password-credentials.json=creds-b64.txt
KUBECONFIG=ritchie/clusters/neumann/kubeconfig kubectl create secret generic onepassword-token -n 1password --from-literal=token='<JWT from op connect token create>'
```

### Catalog and Acexy tokens

- The catalog's feed token (`FEED_TOKEN`), `ACEXY_TOKEN` (Acexy) and `STREAM_TOKEN` (acestreamio) are all the 1Password `neumann / acestream-scraper` item's `password` field. The catalog's ExternalSecret ([`charts/acestream-catalog/templates/externalsecret.yaml`](charts/acestream-catalog/templates/externalsecret.yaml:1)) also maps `acestream-catalog.admin_token` → `ADMIN_TOKEN` and `ccx.api_key` → `LLM_API_KEY` into Secret `acestream-catalog-auth`.
- Acexy is publicly exposed at `ace.tonioriol.com`, gated by `ACEXY_TOKEN` (all requests must include `?token=<value>`), injected via [`ExternalSecret`](charts/acexy/templates/externalsecret.yaml:1) into Secret `acexy-auth`.
- acestreamio `PROXY_URL=https://ace.tonioriol.com`; stream URLs go directly to Acexy with `?token=<STREAM_TOKEN>` (`streamToken` is inline in [`apps/acestreamio.yaml`](apps/acestreamio.yaml:1)).
- Catalog probes must use `/health` (auth-exempt); other paths return 401.

### Credential rotation

1. Update the `password` field in 1Password item `neumann / acestream-scraper`.
2. ESO auto-refreshes every 1h, or force immediate sync: `kubectl annotate externalsecret <name> -n <ns> force-sync=$(date +%s) --overwrite`.
3. **Stakater Reloader** ([`apps/reloader.yaml`](apps/reloader.yaml:1)) rolls Deployments annotated with `secret.reloader.stakater.com/reload: <secret-name>` when the Secret changes. Currently annotated: `acestream-catalog` and `acexy` (`media` ns). No manual `kubectl rollout restart` needed.
4. For `acestreamio` (inline `STREAM_TOKEN`): update [`apps/acestreamio.yaml`](apps/acestreamio.yaml:1) and push.

**Full secret rotation flow:**
```
1Password item edit → ESO refresh (≤1h) → k8s Secret updated → Reloader detects hash change → rolling restart
```

## kubectl context (important for agents)

- The workspace root is the **parent monorepo** (`neumann/`), not the `ritchie/` subdirectory. The kubeconfig lives at `ritchie/clusters/neumann/kubeconfig` relative to the workspace root.
- Always prefix `kubectl` / `helm` commands with: `KUBECONFIG=ritchie/clusters/neumann/kubeconfig`.
- Example: `KUBECONFIG=ritchie/clusters/neumann/kubeconfig kubectl get nodes -o wide`.
- Do **not** use `${PWD}/clusters/neumann/kubeconfig` — that only works when CWD is `ritchie/` and the mise env is not available to agents.
