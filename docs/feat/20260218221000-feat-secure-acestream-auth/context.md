# feat-secure-acestream-auth — Secure acestream-scraper and acestreamio services

## TASK

Add HTTP authentication to the acestream-scraper Flask service (completely open to the internet) and secure the Acexy proxy (port 8080) which was publicly exposed via Cloudflare Tunnel with zero auth. Requirements:
- Support HTTP Basic Auth AND `?token=` query param (for M3U players like TiviMate that can't do interactive auth)
- Auto-embed token in M3U stream URLs and EPG `url-tvg` header
- Proxy Acexy through acestreamio `/ace/getstream` route (gated by STREAM_TOKEN) instead of exposing it directly
- Store credentials in 1Password, apply via ArgoCD Helm values
- Fix GitHub Actions CI push trigger that never fires
- Fork Acexy and add `ACEXY_TOKEN` env var for request-level auth
- Automate Cloudflare Tunnel ingress + DNS CNAME management from `values.yaml`

## GENERAL CONTEXT

Refer to AGENTS.md for project structure description.

ALWAYS use absolute paths.

### REPO

/Users/tr0n/Code/neumann

### RELEVANT FILES

* /Users/tr0n/Code/neumann/acestream-scraper/app/utils/auth.py
* /Users/tr0n/Code/neumann/acestream-scraper/app/__init__.py
* /Users/tr0n/Code/neumann/acestream-scraper/app/services/playlist_service.py
* /Users/tr0n/Code/neumann/acestream-scraper/app/views/main.py
* /Users/tr0n/Code/neumann/acestream-scraper/.github/workflows/release.yml
* /Users/tr0n/Code/neumann/acestreamio/server.js
* /Users/tr0n/Code/neumann/acestreamio/addon.js
* /Users/tr0n/Code/neumann/ritchie/apps/acestream-scraper.yaml
* /Users/tr0n/Code/neumann/ritchie/apps/acestreamio.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/values.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/secret.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/deployment.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/configmap.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestreamio/values.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestreamio/templates/deployment.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/cloudflared/values.yaml
* /Users/tr0n/Code/neumann/acexy/acexy/proxy.go
* /Users/tr0n/Code/neumann/acexy/.github/workflows/release.yaml
* /Users/tr0n/Code/neumann/ritchie/scripts/sync-cloudflare-tunnel.sh
* /Users/tr0n/Code/neumann/ritchie/.env
* /Users/tr0n/Code/neumann/ritchie/AGENTS.md

## PLAN

1. ✅ Add `app/utils/auth.py` — HTTP Basic Auth + `?token=` dual-auth, constant-time comparison, `/api/health` always public
2. ✅ Wire `before_request` hook in `app/__init__.py` calling `check_basic_auth()`
3. ✅ Update `playlist_service.py` to embed `?token=` in EPG url-tvg header and `&token=ACEXY_TOKEN` in stream URLs
4. ✅ Add `/ace/getstream` proxy route to `acestreamio/server.js` — gates with `STREAM_TOKEN`, pipes to cluster-internal Acexy
5. ✅ Update `acestreamio/addon.js` — `PROXY_URL` default from hardcoded `ace.tonioriol.com` to `ADDON_URL` (self)
6. ✅ Remove `ace.tonioriol.com` from `ritchie/charts/cloudflared/values.yaml` (Acexy no longer public)
7. ✅ Add Helm `secret.yaml` template and update `values.yaml` + `deployment.yaml` for acestream-scraper (auth + acexyToken)
8. ✅ Add `streamToken` + `acexyUrl` to acestreamio Helm chart values + deployment
9. ✅ Generate credentials, store in 1Password (`neumann / acestream-scraper`), apply to ArgoCD via `ritchie/apps/acestream-scraper.yaml`
10. ✅ Fix CI: change GitHub default branch from `ai-coding-documentation` to `main`; trigger `workflow_dispatch` to release v1.9.0
11. ✅ Fix k8s probes: change all `path: /` probes to `path: /api/health` (auth-exempt endpoint)
12. ✅ Verify: `401` without auth, `200` with Basic Auth, `200` with `?token=`, pod stable with 0 restarts
13. ✅ Fork Acexy (private `tonioriol/acexy`) and add `ACEXY_TOKEN` env var middleware to `proxy.go`
14. ✅ Publish `ghcr.io/tonioriol/acexy:latest` + `:v1.0.0-tonioriol` via GitHub Actions release CI
15. ✅ Add Acexy sidecar to scraper deployment (temporary — later moved to standalone)
16. ✅ Update `base_url` → `https://ace.tonioriol.com/ace/getstream?id=`
17. ✅ Re-add `ace.tonioriol.com` to cloudflared values → `acestream-scraper:8080`
18. ✅ Update acestreamio `proxyUrl` → `https://ace.tonioriol.com`
19. ✅ Remove Flask `/ace/getstream` proxy route from `acestream-scraper/app/views/main.py`
20. ✅ Automate Cloudflare Tunnel: create `ritchie/scripts/sync-cloudflare-tunnel.sh`, update `.env` to `CF_*` naming, document in `AGENTS.md`

## EVENT LOG

* **2026-02-18 ~14:00 — Discovered acestream-scraper and Acexy were completely open**
  * Why: User asked about adding auth; investigation revealed both Flask app (scraper) and Acexy (port 8080) had zero auth and were publicly reachable
  * How: Checked Cloudflare Tunnel config in `/Users/tr0n/Code/neumann/ritchie/charts/cloudflared/values.yaml` — found `ace.tonioriol.com` → Acexy exposed directly
  * Key info: Scraper at `acestream-scraper.tonioriol.com`, Acexy at `ace.tonioriol.com` (now removed)

* **2026-02-18 ~14:30 — Implemented HTTP Basic Auth + token auth in acestream-scraper**
  * Why: Need dual-auth: Basic Auth for browsers/API, `?token=` for M3U players (TiviMate can't do interactive auth)
  * How: Created `/Users/tr0n/Code/neumann/acestream-scraper/app/utils/auth.py` with `check_basic_auth()` using `hmac.compare_digest`; wired `before_request` hook in `app/__init__.py`; updated `playlist_service.py` to embed tokens in M3U and EPG URLs
  * Key info: `AUTH_USERNAME`, `AUTH_PASSWORD` env vars gate all routes except paths starting with `/api/health`; `ACEXY_TOKEN` embedded in stream URLs

* **2026-02-18 ~15:00 — Added /ace/getstream proxy to acestreamio and removed Acexy from CF tunnel**
  * Why: Acexy exposed directly via `ace.tonioriol.com` with zero auth; need to gate it through acestreamio
  * How: Added `GET /ace/getstream` route to `acestreamio/server.js` using `node:http` pipe, gated by `STREAM_TOKEN`; updated `addon.js` to use `ADDON_URL` self-reference; removed `ace.tonioriol.com` from cloudflared values
  * Key info: `ACEXY_URL=http://acestream-scraper.default.svc.cluster.local:8080`, `STREAM_TOKEN` must match `acexyToken` in scraper chart

* **2026-02-18 ~16:00 — Created Helm secret, updated ArgoCD apps, stored credentials in 1Password**
  * Why: Credentials must not be committed to git; ArgoCD `helm.values` override keeps secrets out of ritchie repo
  * How: Created `/Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/secret.yaml`; generated credentials with `openssl rand`; stored in 1Password item `neumann / acestream-scraper`; applied initial patch to ArgoCD Application CR
  * Key info: 1Password item ID `y3aowtiz5ye7mmwkwnnn7l6aiy`; username=`admin`, password=`SntSIGdaunNbnAZfQzjT3fXN`, stream token=`5e512bdea2cbeea4d29282ce3bd781922a079136920913062069d4a7b109951d`

* **2026-02-18 ~17:00 — Debugged CI push trigger never firing**
  * Why: After pushing auth code to `main`, no new image was built — CI only showed `workflow_dispatch` events
  * How: Investigated: workflow file correct, Actions enabled, not a fork, no `[skip ci]`. Found root cause: GitHub default branch was `ai-coding-documentation` (completely diverged AI-generated rewrite). Changed with `gh api repos/tonioriol/acestream-scraper --method PATCH -f default_branch=main`
  * Key info: Push trigger still did not fire after branch change (GitHub bug or delayed propagation); used `gh workflow run release.yml --repo tonioriol/acestream-scraper --ref main` as workaround → v1.9.0 released successfully

* **2026-02-18 ~21:54 — v1.9.0 released, ArgoCD image updater deployed new pod**
  * Why: Release workflow succeeded; ArgoCD image updater picked up new semver tag automatically
  * How: `gh run list` confirmed success; `kubectl get pods` showed new pod `acestream-scraper-6864c6c7fd-57wn6` running `ghcr.io/tonioriol/acestream-scraper:v1.9.0`
  * Key info: ArgoCD image updater annotation `argocd-image-updater.argoproj.io/scraper.update-strategy: semver` drives automatic rollout

* **2026-02-18 ~22:01 — Auth not applied — Secret missing, ArgoCD selfHeal reverting patches**
  * Why: `kubectl patch` to Application CR was being reverted by `selfHeal: true` back to git state (only `imagePullSecrets`)
  * How: Updated `/Users/tr0n/Code/neumann/ritchie/apps/acestream-scraper.yaml` with full auth values and committed to git; forced ArgoCD refresh with `kubectl annotate application acestream-scraper -n argocd argocd.argoproj.io/refresh=hard --overwrite`
  * Key info: Credentials are now in `ritchie/apps/acestream-scraper.yaml` `spec.source.helm.values` — not ideal (credentials in git) but necessary until ESO is set up

* **2026-02-18 ~22:07 — Pod crash-looping due to k8s probes hitting protected `/` route**
  * Why: All three probes (`readinessProbe`, `livenessProbe`, `startupProbe`) used `path: /` which now returns 401 → pod marked unhealthy → restart loop
  * How: Changed all probe paths from `/` to `/api/health` in `/Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/deployment.yaml`; committed and pushed to ritchie; forced ArgoCD refresh
  * Key info: `app/utils/auth.py` exempts paths starting with `/api/health` (no trailing slash, checked with `startswith`)

* **2026-02-18 ~22:09 — Auth fully verified, pod stable**
  * Why: Final verification via `kubectl port-forward` to confirm auth enforcement
  * How: `curl` tests: `/api/health` → 308 (public), `/playlist.m3u` no auth → 401, `/playlist.m3u` Basic Auth → 200, `/playlist.m3u?token=SntSIGdaunNbnAZfQzjT3fXN` → 200. Pod `acestream-scraper-6b75666fb-qhcb7` running 0 restarts.
  * Key info: 308 on `/api/health` is Flask redirecting to `/api/health/` — still auth-free and probes follow redirects

* **2026-02-19 ~02:00 — Forked Acexy to private tonioriol/acexy repo**
  * Why: Need to add `ACEXY_TOKEN` env var for request-level auth; upstream Acexy has no auth
  * How: `gh repo fork --private` doesn't work; GitHub disables private forks of public repos. Cloned upstream directly, created empty private repo `tonioriol/acexy` via `gh repo create`, pushed. Used `gh auth refresh -h github.com -s delete_repo` (device code `2773-879F`) to get delete scope for cleaning up failed fork attempts.
  * Key info: Remote `origin` → `git@github.com:tonioriol/acexy.git`, `upstream` → `https://github.com/Javinator9889/acexy.git`

* **2026-02-19 ~02:30 — Added ACEXY_TOKEN middleware to proxy.go**
  * Why: All requests to Acexy must require `?token=<value>` for auth
  * How: Added token check at the top of `ServeHTTP()` in `/Users/tr0n/Code/neumann/acexy/acexy/proxy.go`: reads `os.Getenv("ACEXY_TOKEN")`, checks `r.URL.Query().Get("token")`, returns 401 if mismatch
  * Key info: Token check applies to ALL requests including `/ace/status` — this later caused probe failures when used as sidecar

* **2026-02-19 ~03:00 — Published ghcr.io/tonioriol/acexy:latest via GitHub Actions**
  * Why: Need container image for k8s deployment
  * How: Created release `v1.0.0-tonioriol` via `gh release create`; CI workflow built and pushed to GHCR. Had to remove `Generate artifact attestation` step from `/Users/tr0n/Code/neumann/acexy/.github/workflows/release.yaml` — feature not available for private repos (error: "Feature not available for user-owned private repositories")
  * Key info: Tags published: `ghcr.io/tonioriol/acexy:latest` and `:v1.0.0-tonioriol`

* **2026-02-19 ~03:30 — Added Acexy as sidecar to scraper deployment (temporary)**
  * Why: Quick deployment path — sidecar shares localhost with scraper, Acexy connects to bundled engine on localhost:6878
  * How: Added second container `acexy` to `/Users/tr0n/Code/neumann/ritchie/charts/acestream-scraper/templates/deployment.yaml`; set `ACEXY_HOST=localhost`, `ACEXY_PORT={{ .Values.env.ACESTREAM_HTTP_PORT }}`, `ACEXY_TOKEN` from Secret; added port 8080 to Service; set `ENABLE_ACEXY=false` in values (disable bundled Acexy)
  * Key info: This was always intended as temporary — the plan was always a standalone Deployment

* **2026-02-19 ~04:00 — Updated tunnel config and acestreamio**
  * Why: `ace.tonioriol.com` needs to route to Acexy, acestreamio needs to use the public URL
  * How: Re-added `ace.tonioriol.com` to `/Users/tr0n/Code/neumann/ritchie/charts/cloudflared/values.yaml` pointing at `acestream-scraper.default.svc.cluster.local:8080`; updated acestreamio `proxyUrl` → `https://ace.tonioriol.com`; updated configmap `base_url` → `https://ace.tonioriol.com/ace/getstream?id=`
  * Key info: Removed Flask `/ace/getstream` proxy route from `/Users/tr0n/Code/neumann/acestream-scraper/app/views/main.py` (no longer needed with direct Acexy exposure)

* **2026-02-19 ~07:00 — Automated Cloudflare Tunnel sync from values.yaml**
  * Why: User requested automation for any service — "I WANT THAT AUTOMATED FOR ANY SERVICE IN NEUMANN"
  * How: Created `/Users/tr0n/Code/neumann/ritchie/scripts/sync-cloudflare-tunnel.sh` — reads `charts/cloudflared/values.yaml`, PUTs ingress config to CF API, upserts DNS CNAME records. Updated `/Users/tr0n/Code/neumann/ritchie/.env` to `CF_*` naming convention (`CF_EMAIL`, `CF_API_KEY`, `CF_ACCOUNT_ID`, `CF_TUNNEL_ID`), removed legacy `CLOUDFLARE_*` aliases. Updated `/Users/tr0n/Code/neumann/ritchie/AGENTS.md` with full documentation including one-level subdomain constraint.
  * Key info: Dry-run tested successfully showing all 5 hostnames. Pushed commit `4ea2273` to ritchie `main`.

* **2026-02-19 ~08:19 — Discovered sidecar crash-loop: readiness probe 401**
  * Why: Acexy sidecar readiness probe hits `/ace/status` on port 8080, but `ACEXY_TOKEN` is set → probe gets 401 → pod stuck at 1/2, 95 restarts
  * How: `kubectl describe pod acestream-scraper-9c4888696-dfjt6` → `Readiness probe failed: HTTP probe failed with statuscode: 401`
  * Key info: Old pod `acestream-scraper-6cc6c4d85-6dv8r` (pre-sidecar, 1/1) still running. New pod (with sidecar) never became ready. ArgoCD status: `Synced Degraded`

* **2026-02-19 ~09:30 — Decision: Acexy must be standalone Deployment, not sidecar**
  * Why: User clarified this was always the plan; sidecar approach was a shortcut that doesn't fit k8s architecture. The scraper image bundles engine+acexy for Docker users, but in k8s each component should be its own Deployment.
  * How: Acexy's own `docker-compose.yml` pairs it with `martinbjeldbak/acestream-http-proxy` as the engine — exactly what `charts/acestream` already runs in `media` namespace. Architecture: 3 independent Deployments (acestream engine, acexy proxy, scraper Flask app).
  * Key info: See `/Users/tr0n/Code/neumann/ritchie/docs/feat/20260219140000-feat-acexy-standalone-deployment/context.md` for full plan

* **2026-02-23 ~23:20 — Fix CI push trigger for tonioriol/acestream-scraper**
  * Why: Push events never fired on GitHub Actions despite correct workflow config
  * How: Deleted workflow file, committed, recreated, committed again. Forced GitHub to re-register the push event hook.
  * Key info: Commit `7141ff3` triggered via `push` event → `conclusion: success`. Also removed `paths:` filter (semantic-release handles no-op).

* **2026-02-24 ~00:00 — ESO + 1Password Connect: initial deployment**
  * Why: Credentials stored in plaintext in `ritchie/apps/acestream-scraper.yaml` and `apps/acexy.yaml`
  * How: Created 1Password vault `neumann`, Connect server `neumann-k8s`, token `neumann-eso`. Deployed via ArgoCD: `onepassword-connect` (Helm chart), `external-secrets` (ESO operator), `external-secrets-config` (ClusterSecretStore). Replaced `secret.yaml` templates with `externalsecret.yaml` in acestream-scraper and acexy charts. Removed plaintext credentials from ArgoCD app files.
  * Key info: Connect server UUID `TKBFXTXMERDEJCHJY2DM4K4W24`; vault ID `xuk2fqgwzzf3iqybuq7pidwgnq`; 1Password item `acestream-scraper` (ID `hthexfrtih57dr5gf2dighfa4e`)

* **2026-02-24 ~00:05 — Fix Connect credentials: wrong cluster context**
  * Why: Initially created k8s secrets on wrong cluster (AWS EKS `flo-eks-axess-dev` instead of neumann k3s)
  * How: Deleted from EKS, recreated on neumann using `KUBECONFIG=ritchie/clusters/neumann/kubeconfig`
  * Key info: Always use `KUBECONFIG=ritchie/clusters/neumann/kubeconfig` for neumann cluster commands

* **2026-02-24 ~00:10 — Fix Connect credentials format**
  * Why: Connect expects credentials file to be base64-encoded; Helm chart's `connect.credentials` value was being treated as a string name, not file content
  * How: Set `credentials_base64:` empty in Helm values (so chart doesn't create `op-credentials` Secret), pre-create `op-credentials` Secret manually with `base64 < 1password-credentials.json` content. Connect expects double-base64: file content is base64, then k8s Secret base64-encodes again.
  * Key info: Commit `f1631e2` in ritchie repo

* **2026-02-24 ~00:19 — ClusterSecretStore validated, ExternalSecrets synced**
  * Why: After fixing credentials, Connect returned 200 on `/v1/vaults` but ESO cached the old error
  * How: Deleted and recreated ClusterSecretStore to force fresh validation → `Valid + ReadWrite + Ready`. Deleted duplicate 1Password item (two items named `acestream-scraper`). Annotated ExternalSecrets to force sync → both `SecretSynced + True`.
  * Key info: Both k8s Secrets created: `acestream-scraper-auth` (AUTH_USERNAME + AUTH_PASSWORD), `acexy-auth` (ACEXY_TOKEN). All ArgoCD apps Synced + Healthy.

* **2026-02-24 ~00:28 — Cleanup and documentation**
  * Why: Remove temp files, old secrets, update AGENTS.md
  * How: Deleted `/tmp/1password-credentials.json`, `/tmp/1password-credentials-b64.txt`, old `onepassword-credentials` Secret on neumann. Updated AGENTS.md Authentication section with ESO architecture, out-of-band secret docs, credential rotation flow.

## Next Steps

- [x] **Implement Acexy standalone Deployment** — see `/Users/tr0n/Code/neumann/ritchie/docs/feat/20260219140000-feat-acexy-standalone-deployment/context.md` (COMPLETED)
- [x] **Cloudflare Tunnel GitOps** — see `/Users/tr0n/Code/neumann/ritchie/docs/feat/20260219160000-feat-cloudflare-tunnel-gitops/context.md` (COMPLETED)
- [x] **ESO (External Secrets Operator) + 1Password integration** — deployed, credentials removed from git (COMPLETED 2026-02-24)
- [x] **Fix GitHub Actions push trigger** — fixed by deleting/recreating workflow file (COMPLETED 2026-02-24)
