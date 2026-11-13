# Acexy Standalone Deployment — Extract from Sidecar to Own Helm Chart

## TASK

Move Acexy from a sidecar container in the acestream-scraper pod to its own standalone Helm chart (`charts/acexy`) as an independent Deployment + Service in the `media` namespace. The scraper pod should no longer bundle either the AceStream engine or Acexy — both are separate services. Acexy connects to the existing `charts/acestream` engine at `acestream.media.svc.cluster.local:6878`.

## GENERAL CONTEXT

Refer to AGENTS.md for project structure description.

ALWAYS use absolute paths.

### REPO

/Users/tr0n/Code/neumann

### RELEVANT FILES

* /Users/tr0n/Code/neumann/ritchie/charts/acexy/Chart.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acexy/values.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acexy/templates/deployment.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acexy/templates/service.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acexy/templates/secret.yaml
* /Users/tr0n/Code/neumann/ritchie/apps/acexy.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/deployment.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/service.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/values.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/configmap.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/cloudflared/values.yaml
* /Users/tr0n/Code/neumann/ritchie/scripts/sync-cloudflare-tunnel.sh
* /Users/tr0n/Code/neumann/ritchie/charts/acestream/values.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestream/templates/service.yaml
* /Users/tr0n/Code/neumann/acexy/acexy/proxy.go
* /Users/tr0n/Code/neumann/acexy/docker-compose.yml

## PLAN

1. ✅ Create `ritchie/charts/acexy/Chart.yaml` — `name: acexy`, `version: 0.1.0`
2. ✅ Create `ritchie/charts/acexy/values.yaml` — image config, acestream host/port, auth, tuning env vars
3. ✅ Create `ritchie/charts/acexy/templates/deployment.yaml` — single container, TCP socket probes on 8080 (avoids token auth 401), env vars from values + Secret
4. ✅ Create `ritchie/charts/acexy/templates/service.yaml` — ClusterIP on port 8080
5. ✅ Create `ritchie/charts/acexy/templates/secret.yaml` — conditional on `auth.enabled`, stores `ACEXY_TOKEN`
6. ✅ Create `ritchie/apps/acexy.yaml` — ArgoCD Application, namespace `media`, helm values with `auth.enabled: true`, `auth.token: "SntSIGdaunNbnAZfQzjT3fXN"`, `imagePullSecrets`
7. ✅ Strip acexy sidecar container from `charts/acestream-scraper/templates/deployment.yaml`
8. ✅ Remove port 8080 from `charts/acestream-scraper/templates/service.yaml`
9. ✅ Update `charts/acestream-scraper/values.yaml` — remove `acexy:` image block, set `ENABLE_ACESTREAM_ENGINE: "false"`, change `ACESTREAM_HTTP_HOST: "acestream.media.svc.cluster.local"`
10. ✅ Fix `charts/acestream-scraper/templates/configmap.yaml` — change `ace_engine_url` port from `8080` to `{{ .Values.env.ACESTREAM_HTTP_PORT }}` (6878)
11. ✅ Update `charts/cloudflared/values.yaml` — change `ace.tonioriol.com` from `acestream-scraper.default.svc.cluster.local:8080` to `acexy.media.svc.cluster.local:8080`
12. ✅ Run `sync-cloudflare-tunnel.sh` — push updated tunnel config + upsert DNS CNAMEs
13. ✅ Commit and push all changes to ritchie `main`

## Architecture

```
Internet via Cloudflare Tunnel
  ace.tonioriol.com → acexy.media.svc.cluster.local:8080
  scraper.tonioriol.com → acestream-scraper.default.svc.cluster.local:8000

┌─────────────────────────┐
│  charts/acexy            │  standalone Deployment — media ns
│  ghcr.io/tonioriol/acexy │  1/1 Running, 0 restarts
│  port 8080               │  ACEXY_TOKEN from Secret
│  ACEXY_HOST=acestream    │  → acestream.media:6878
└────────────┬────────────┘
             │
┌────────────▼────────────┐
│  charts/acestream        │  EXISTING — no changes
│  martinbjeldbak/         │  media ns, port 6878
│  acestream-http-proxy    │  This IS the engine
└─────────────────────────┘

┌─────────────────────────┐
│  charts/acestream-scraper│  MODIFIED — Flask only
│  port 8000               │  default ns
│  ENABLE_ENGINE=false     │  Synced Healthy
│  ENABLE_ACEXY=false      │  1/1 Running, 0 restarts
│  ACESTREAM_HTTP_HOST=    │
│    acestream.media.svc.  │
└─────────────────────────┘
```

## EVENT LOG

* **2026-02-19 09:30 — Discovered sidecar crash-loop, decided on standalone architecture**
  * Why: Acexy sidecar in scraper pod had readiness probe on `/ace/status` returning 401 (ACEXY_TOKEN blocks all requests). 95 restarts, pod stuck at 1/2. User clarified Acexy was always intended as its own Deployment.
  * How: `kubectl describe pod acestream-scraper-9c4888696-dfjt6` showed `Readiness probe failed: HTTP probe failed with statuscode: 401`. Discussed architecture — Acexy is a pure proxy needing an external engine; `charts/acestream` already provides that engine in `media` namespace.
  * Key info: Acexy's docker-compose.yml uses `martinbjeldbak/acestream-http-proxy:latest` as its recommended engine — exactly what `charts/acestream` runs. Old pod `acestream-scraper-6cc6c4d85-6dv8r` (pre-sidecar, 1/1) still running.

* **2026-02-19 09:37 — Wrote architecture plan and context file**
  * Why: User requested `/context` to capture the plan before implementation
  * How: Created `/Users/tr0n/Code/neumann/ritchie/docs/feat/20260219140000-feat-acexy-standalone-deployment/context.md` with full architecture diagram, 13-step plan, and rationale. TCP socket probes chosen over HTTP to avoid 401 issue.
  * Key info: Key insight — `ace_engine_url` in configmap was pointing at port 8080 (sidecar Acexy) not port 6878 (engine); needed fixing.

* **2026-02-19 09:41 — Created charts/acexy standalone Helm chart**
  * Why: New chart for Acexy as an independent Deployment in `media` namespace
  * How: Created 5 files: `Chart.yaml`, `values.yaml`, `templates/deployment.yaml`, `templates/service.yaml`, `templates/secret.yaml`. Key decisions: TCP socket probes on port 8080 (not HTTP `/ace/status` which returns 401 with token auth); `ACEXY_HOST=acestream` (k8s DNS resolves to `acestream.media.svc.cluster.local` within same namespace); `ACEXY_TOKEN` from Secret when `auth.enabled`.
  * Key info: `/Users/tr0n/Code/neumann/ritchie/charts/acexy/` — all files created successfully

* **2026-02-19 09:41 — Created apps/acexy.yaml ArgoCD Application**
  * Why: ArgoCD root app-of-apps watches `apps/` path and auto-syncs; adding file here auto-deploys the chart
  * How: Created `/Users/tr0n/Code/neumann/ritchie/apps/acexy.yaml` — `namespace: media`, `auth.enabled: true`, `auth.token: "SntSIGdaunNbnAZfQzjT3fXN"` (same as acestream-scraper AUTH_PASSWORD), `imagePullSecrets: [{name: ghcr-pull}]`
  * Key info: No image updater annotations — acexy uses `:latest` tag not semver

* **2026-02-19 09:42 — Stripped sidecar + cleaned up scraper chart**
  * Why: Remove the broken sidecar, disable bundled engine, point scraper at external engine
  * How: 5 simultaneous edits — removed acexy container block from deployment.yaml (lines 138-174); removed port 8080 from service.yaml; updated values.yaml (`ENABLE_ACESTREAM_ENGINE=false`, `ACESTREAM_HTTP_HOST=acestream.media.svc.cluster.local`, removed `acexy:` image block); fixed configmap.yaml `ace_engine_url` port from hardcoded `8080` to `{{ .Values.env.ACESTREAM_HTTP_PORT }}`; updated cloudflared/values.yaml ace.tonioriol.com target
  * Key info: All YAML lint errors were false positives — linter doesn't understand Helm `{{ }}` template syntax

* **2026-02-19 09:42 — Fixed sync-cloudflare-tunnel.sh DNS upsert bug**
  * Why: Script failed with `JSONDecodeError: Expecting value` — Python heredoc `<<PYEOF` replaces stdin, so `json.load(sys.stdin)` read the heredoc (empty) instead of the piped INGRESS_JSON
  * How: Changed script to `export INGRESS_JSON` and use `python3 <<'PYEOF'` with `json.loads(os.environ["INGRESS_JSON"])` instead of pipe+heredoc. Also added `export TUNNEL_CNAME` and `export CF_ZONE_ID` so Python subprocess can access them.
  * Key info: Tunnel config PUT succeeded (✓) before the DNS error — ingress rules were already live in CF when DNS upsert failed

* **2026-02-19 09:43 — Ran sync script successfully, committed and pushed**
  * Why: Push updated tunnel config (ace.tonioriol.com now → acexy.media) and upsert all DNS records
  * How: `cd ritchie && set -a && source .env && set +a && ./scripts/sync-cloudflare-tunnel.sh` — all 5 DNS records ✓ updated. Committed as `20173b0` "feat: acexy standalone deployment + scraper cleanup" — 14 files changed.
  * Key info: Commit SHA `20173b0`, pushed to `https://github.com/tonioriol/ritchie.git main`

* **2026-02-19 10:43 — Verified live: all pods healthy, M3U correct**
  * Why: Final end-to-end verification
  * How: `kubectl get pods` — `acexy-868c5b9644-rmbmj 1/1 Running 0 55m` (media ns). ArgoCD: `acexy Synced Healthy`, `acestream-scraper Synced Healthy`. `curl -u admin:SntSIGdaunNbnAZfQzjT3fXN https://scraper.tonioriol.com/api/playlists/m3u` returned correct M3U with EPG `url-tvg=...?token=SntSIGdaunNbnAZfQzjT3fXN` and all stream URLs as `https://acestreamio.tonioriol.com/ace/getstream?id=<hash>&token=SntSIGdaunNbnAZfQzjT3fXN`
  * Key info: Stream URLs route through acestreamio (validates STREAM_TOKEN) → acexy (validates ACEXY_TOKEN) → acestream engine (P2P)

## Next Steps

COMPLETED
