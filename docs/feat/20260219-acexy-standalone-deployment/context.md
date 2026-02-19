# Acexy Standalone Deployment — Extract from Sidecar to Own Helm Chart

## TASK

Move Acexy from a sidecar container in the acestream-scraper pod to its own standalone Helm chart (`charts/acexy`) as an independent Deployment + Service in the `media` namespace. The scraper pod should no longer bundle either the AceStream engine or Acexy — both are separate services. Acexy connects to the existing `charts/acestream` engine at `acestream.media.svc.cluster.local:6878`.

## GENERAL CONTEXT

Refer to AGENTS.md for project structure description.

ALWAYS use absolute paths.

### REPO

/Users/tr0n/Code/neumann

### RELEVANT FILES

* /Users/tr0n/Code/neumann/ritchie/charts/acexy/ — NEW chart (to be created)
* /Users/tr0n/Code/neumann/ritchie/apps/acexy.yaml — NEW ArgoCD Application (to be created)
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/deployment.yaml — remove sidecar
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/service.yaml — remove port 8080
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/values.yaml — remove acexy block, disable engine
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/configmap.yaml — fix ace_engine_url port
* /Users/tr0n/Code/neumann/ritchie/charts/cloudflared/values.yaml — retarget ace.tonioriol.com
* /Users/tr0n/Code/neumann/ritchie/scripts/sync-cloudflare-tunnel.sh — run to push tunnel config
* /Users/tr0n/Code/neumann/ritchie/charts/acestream/values.yaml — existing engine chart (no changes)
* /Users/tr0n/Code/neumann/ritchie/charts/acestream/templates/service.yaml — engine ClusterIP on 6878
* /Users/tr0n/Code/neumann/acexy/acexy/proxy.go — fork with ACEXY_TOKEN middleware
* /Users/tr0n/Code/neumann/acexy/docker-compose.yml — reference for recommended engine pairing

## PLAN

1. ⬜ Create `ritchie/charts/acexy/Chart.yaml` — `name: acexy`, `version: 0.1.0`
2. ⬜ Create `ritchie/charts/acexy/values.yaml` — image config, acestream host/port, auth, tuning env vars
3. ⬜ Create `ritchie/charts/acexy/templates/deployment.yaml` — single container, TCP socket probes on 8080 (avoids token auth issues with HTTP probes), env vars from values + Secret
4. ⬜ Create `ritchie/charts/acexy/templates/service.yaml` — ClusterIP on port 8080
5. ⬜ Create `ritchie/charts/acexy/templates/secret.yaml` — conditional on `auth.enabled`, stores `ACEXY_TOKEN`
6. ⬜ Create `ritchie/apps/acexy.yaml` — ArgoCD Application, namespace `media`, helm values override with `auth.enabled: true`, `auth.token: "SntSIGdaunNbnAZfQzjT3fXN"`, `imagePullSecrets`
7. ⬜ Strip acexy sidecar container from `/Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/deployment.yaml` (remove lines 138-174)
8. ⬜ Remove port 8080 from `/Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/service.yaml`
9. ⬜ Update `/Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/values.yaml` — remove `acexy:` image block, set `ENABLE_ACESTREAM_ENGINE: "false"`, change `ACESTREAM_HTTP_HOST: "acestream.media.svc.cluster.local"`
10. ⬜ Fix `/Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/configmap.yaml` — change `ace_engine_url` port from `8080` to `{{ .Values.env.ACESTREAM_HTTP_PORT }}` (6878)
11. ⬜ Update `/Users/tr0n/Code/neumann/ritchie/charts/cloudflared/values.yaml` — change `ace.tonioriol.com` service from `http://acestream-scraper.default.svc.cluster.local:8080` to `http://acexy.media.svc.cluster.local:8080`
12. ⬜ Run `sync-cloudflare-tunnel.sh` to push updated tunnel config to Cloudflare API
13. ⬜ Commit and push all changes to ritchie `main`

## Architecture

```
Internet via Cloudflare Tunnel
  ace.tonioriol.com → acexy.media.svc.cluster.local:8080
  scraper.tonioriol.com → acestream-scraper.default.svc.cluster.local:8000

┌─────────────────────────┐
│  charts/acexy            │  NEW — standalone Deployment
│  ghcr.io/tonioriol/acexy │  namespace: media
│  port 8080               │  ACEXY_TOKEN for auth
│  ACEXY_HOST=acestream    │  → acestream.media:6878
│  ACEXY_PORT=6878         │
└────────────┬────────────┘
             │
┌────────────▼────────────┐
│  charts/acestream        │  EXISTING — no changes
│  martinbjeldbak/         │  namespace: media
│  acestream-http-proxy    │  port 6878
│  ClusterIP service       │  This IS the engine
└─────────────────────────┘

┌─────────────────────────┐
│  charts/acestream-scraper│  MODIFIED — scraper only
│  ghcr.io/tonioriol/     │  namespace: default
│  acestream-scraper       │  port 8000
│  ENABLE_ENGINE=false     │  No bundled engine
│  ENABLE_ACEXY=false      │  No bundled acexy
│  ACESTREAM_HTTP_HOST=    │
│    acestream.media.svc.  │  → engine for status API
│    cluster.local         │
└─────────────────────────┘
```

Acexy's own `docker-compose.yml` recommends `martinbjeldbak/acestream-http-proxy` as the engine — exactly what `charts/acestream` already runs. TCP socket probes on port 8080 avoid token auth issues that caused the sidecar crash-loop.

## EVENT LOG

* **2026-02-19 09:30 — Discovered sidecar crash-loop, decided on standalone architecture**
  * Why: Acexy sidecar in scraper pod had readiness probe on `/ace/status` returning 401 (ACEXY_TOKEN blocks all requests). 95 restarts, pod stuck at 1/2. User clarified Acexy was always intended as its own Deployment.
  * How: `kubectl describe pod acestream-scraper-9c4888696-dfjt6` showed `Readiness probe failed: HTTP probe failed with statuscode: 401`. Discussed architecture — Acexy is a pure proxy needing an external engine; `charts/acestream` already provides that engine in `media` namespace.
  * Key info: Old pod `acestream-scraper-6cc6c4d85-6dv8r` (pre-sidecar, 1/1) still running. Acexy's docker-compose.yml uses `martinbjeldbak/acestream-http-proxy:latest` as its recommended engine.

## Next Steps

- [ ] Implement all 13 plan steps above
- [ ] Verify ArgoCD deploys acexy pod in media namespace and it connects to engine
- [ ] Verify `ace.tonioriol.com` returns streams through the standalone acexy
- [ ] Verify scraper status checks work cross-namespace to `acestream.media.svc.cluster.local:6878`
