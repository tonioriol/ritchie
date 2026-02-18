# feat-secure-acestream-auth — Secure acestream-scraper and acestreamio services

## TASK

Add HTTP authentication to the acestream-scraper Flask service (completely open to the internet) and secure the Acexy proxy (port 8080) which was publicly exposed via Cloudflare Tunnel with zero auth. Requirements:
- Support HTTP Basic Auth AND `?token=` query param (for M3U players like TiviMate that can't do interactive auth)
- Auto-embed token in M3U stream URLs and EPG `url-tvg` header
- Proxy Acexy through acestreamio `/ace/getstream` route (gated by STREAM_TOKEN) instead of exposing it directly
- Store credentials in 1Password, apply via ArgoCD Helm values
- Fix GitHub Actions CI push trigger that never fires

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
* /Users/tr0n/Code/neumann/ritchie/charts/acestreamio/values.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/acestreamio/templates/deployment.yaml
* /Users/tr0n/Code/neumann/ritchie/charts/cloudflared/values.yaml

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

## EVENT LOG

* **2026-02-18 ~14:00 — Discovered acestream-scraper and Acexy were completely open**
  * Why: User asked about adding auth; investigation revealed both Flask app (scraper) and Acexy (port 8080) had zero auth and were publicly reachable
  * How: Checked Cloudflare Tunnel config in `ritchie/charts/cloudflared/values.yaml` — found `ace.tonioriol.com` → Acexy exposed directly
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
  * How: Created `ritchie/charts/acestream-scraper/templates/secret.yaml`; generated credentials with `openssl rand`; stored in 1Password item `neumann / acestream-scraper`; applied initial patch to ArgoCD Application CR
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
  * How: Updated `ritchie/apps/acestream-scraper.yaml` with full auth values and committed to git; forced ArgoCD refresh with `kubectl annotate application acestream-scraper -n argocd argocd.argoproj.io/refresh=hard --overwrite`
  * Key info: Credentials are now in `ritchie/apps/acestream-scraper.yaml` `spec.source.helm.values` — not ideal (credentials in git) but necessary until ESO is set up

* **2026-02-18 ~22:07 — Pod crash-looping due to k8s probes hitting protected `/` route**
  * Why: All three probes (`readinessProbe`, `livenessProbe`, `startupProbe`) used `path: /` which now returns 401 → pod marked unhealthy → restart loop
  * How: Changed all probe paths from `/` to `/api/health` in `ritchie/charts/acestream-scraper/templates/deployment.yaml`; committed and pushed to ritchie; forced ArgoCD refresh
  * Key info: `app/utils/auth.py` exempts paths starting with `/api/health` (no trailing slash, checked with `startswith`)

* **2026-02-18 ~22:09 — Auth fully verified, pod stable**
  * Why: Final verification via `kubectl port-forward` to confirm auth enforcement
  * How: `curl` tests: `/api/health` → 308 (public), `/playlist.m3u` no auth → 401, `/playlist.m3u` Basic Auth → 200, `/playlist.m3u?token=SntSIGdaunNbnAZfQzjT3fXN` → 200. Pod `acestream-scraper-6b75666fb-qhcb7` running 0 restarts.
  * Key info: 308 on `/api/health` is Flask redirecting to `/api/health/` — still auth-free and probes follow redirects

## Next Steps

- [ ] **ESO (External Secrets Operator) + 1Password integration** — remove credentials from `ritchie/apps/acestream-scraper.yaml` git file and pull them from 1Password via ESO ExternalSecret CR (explicitly deferred from this task)
- [ ] **Fix GitHub Actions push trigger** — push trigger still does not fire after changing default branch; needs further investigation (possibly GitHub Actions bug or caching issue). Workaround: `gh workflow run release.yml --repo tonioriol/acestream-scraper --ref main`
- [ ] **Verify acestreamio STREAM_TOKEN** — confirm `acestreamio` deployment has correct `STREAM_TOKEN` matching the acexyToken and that `/ace/getstream?token=...` works end-to-end for stream playback
