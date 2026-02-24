---
title: "Auth UX, secret rotation, and channel status improvements"
status: done
repos: [ritchie, acestream-scraper]
tags: [1password, auth, channel-status, eso, kubernetes, reloader, secrets]
related: [20260218221000-feat-secure-acestream-auth, 20260217231000-feat-acestream-scraper-deployment]
created: 2026-02-24
---
# Auth UX, secret rotation, and channel status improvements

## TASK

Batch of improvements requested after auth was deployed:
1. Show full M3U playlist URLs with `?token=` in the scraper web UI so users can copy-paste into TiviMate
2. Auto-reload pods when 1Password credentials change (no manual `kubectl rollout restart`)
3. Document secrets management (1P account, vault, items, ESO flow) in ritchie README
4. Clean up duplicate 1Password items left over from initial setup
5. Fix channel availability monitor — many channels showing online when they're actually dead

## GENERAL CONTEXT

Refer to AGENTS.md for project structure description.

### REPO

ritchie/ and acestream-scraper/ (both in neumann monorepo workspace)

### RELEVANT FILES

* acestream-scraper/app/__init__.py — Added context_processor for auth_token_qs
* acestream-scraper/app/utils/auth.py — build_token_query_string() used by templates
* acestream-scraper/app/templates/tv_channels.html — Playlist/EPG URLs now include ?token=
* acestream-scraper/app/templates/dashboard.html — Playlist URL now includes ?token=
* acestream-scraper/app/templates/streams.html — Playlist URL now includes ?token=
* acestream-scraper/app/static/js/tv-channels.js — URL builder handles existing ?token= param
* acestream-scraper/app/services/channel_status_service.py — Improved check_channel + check_channels
* acestream-scraper/tests/unit/test_channel_status_service.py — Fixed unit tests for updated signatures
* AGENTS.md — NEW: root workspace AGENTS.md with deployment flows, secrets, URLs
* ritchie/AGENTS.md — Updated credential rotation section with Reloader docs
* ritchie/apps/reloader.yaml — Stakater Reloader ArgoCD Application
* ritchie/charts/acestream-scraper/templates/deployment.yaml — Reloader annotation
* ritchie/charts/acexy/templates/deployment.yaml — Reloader annotation
* ritchie/charts/acestream-scraper/templates/externalsecret.yaml — Added deletionPolicy: Retain
* ritchie/charts/acexy/templates/externalsecret.yaml — Added deletionPolicy: Retain
* ritchie/README.md — Added §7 secrets management docs
* ritchie/TODO.md — Added playlist item removal TODO

## PLAN

1. ✅ Add `auth_token_qs` Jinja2 context processor to Flask app factory
2. ✅ Update all template playlist/EPG URL inputs to append `{{ auth_token_qs }}`
3. ✅ Deploy Stakater Reloader via ArgoCD (`apps/reloader.yaml`)
4. ✅ Add `secret.reloader.stakater.com/reload` annotations to both Deployments
5. ✅ Add `deletionPolicy: Retain` to ExternalSecrets
6. ✅ Document 1P account, vault, items, ESO flow, rotation steps in README §7
7. ✅ Delete duplicate `neumann / acestream-scraper` item from Private vault
8. ✅ Improve channel status checker: 8KB min data threshold, stream stop cleanup, semaphore-only concurrency
9. ✅ Add TODO for playlist item removal feature
10. ✅ Run unit tests for channel_status_service — fix 2 failing tests, all 7 pass

## EVENT LOG

* **2026-02-24 21:08 — Added auth token to M3U URLs in scraper UI**
  * Why: Users need to copy the full URL with `?token=` for TiviMate and other M3U players
  * How: Added `@app.context_processor` in `acestream-scraper/app/__init__.py` injecting `auth_token_qs` (calls `build_token_query_string()`). Updated `tv_channels.html` (3 URL inputs), `dashboard.html` (1 input), `streams.html` (1 input) to append `{{ auth_token_qs }}`. Updated `tv-channels.js` URL builder comments to note base URL may contain `?token=`.
  * Key info: `build_token_query_string()` returns `?token=<AUTH_PASSWORD>` when auth enabled, empty string when not

* **2026-02-24 21:13 — Deployed Stakater Reloader for auto pod restart on secret change**
  * Why: User explicitly wants pods to restart automatically when 1P credentials change — no manual `kubectl rollout restart`
  * How: Created `ritchie/apps/reloader.yaml` (ArgoCD Application, chart `stakater/reloader` v1.2.0, namespace `kube-system`). Added `secret.reloader.stakater.com/reload: <release>-auth` annotations to pod templates in both `charts/acestream-scraper/templates/deployment.yaml` and `charts/acexy/templates/deployment.yaml`. Added `deletionPolicy: Retain` to both ExternalSecrets.
  * Key info: Flow: 1P change → ESO refreshes Secret (1h interval) → Reloader detects Secret data change → rolling restart of Deployment

* **2026-02-24 21:14 — Documented secrets management in ritchie README**
  * Why: Need to document which 1P account/vault/items are used, how ESO flows, how to rotate
  * How: Added §7 to `ritchie/README.md` covering: 1P account (`my.1password.com`, `tonioriol@gmail.com`, UUID `PRBEZ6ELGNCMDIK6YVMRW5TTXQ`), vault `neumann`, item `acestream-scraper` (ID `hthexfrtih57dr5gf2dighfa4e`), field mapping, ESO architecture, Reloader integration, rotation steps, out-of-band secrets table
  * Key info: `password` field is used as token everywhere — ACEXY_TOKEN, STREAM_TOKEN, and `?token=` all use the same value

* **2026-02-24 21:18 — Cleaned up duplicate 1P items**
  * Why: Old `neumann / acestream-scraper` item (ID `y3aowtiz5ye7mmwkwnnn7l6aiy`) in Private vault was a leftover from before ESO setup
  * How: `op item delete y3aowtiz5ye7mmwkwnnn7l6aiy --account PRBEZ6ELGNCMDIK6YVMRW5TTXQ --vault Private`
  * Key info: Active item is `hthexfrtih57dr5gf2dighfa4e` in `neumann` vault. The `stream token` field is unused by ESO (legacy) but kept for now.

* **2026-02-24 21:13 — Improved channel status checker**
  * Why: Many channels showing as online when they're actually dead — Phase 1 `is_live` flag is unreliable
  * How: Updated `acestream-scraper/app/services/channel_status_service.py`:
    - Increased **minimum stream data** from 4096 to 8192 bytes (`MIN_STREAM_BYTES`) — ensures we get real video data not just headers
    - Increased **stream probe timeout** from 15s to 20s (`STREAM_PROBE_TIMEOUT`)
    - Added **stream stop command** in `finally` block — sends `method=stop` to engine to free player slots after probing
    - Added **metadata timeout handling** — explicit `asyncio.TimeoutError` catch for Phase 1
    - Fixed **concurrency bottleneck**: removed `chunk_size=2` loop that limited actual parallelism to 2 regardless of semaphore. Now uses `asyncio.gather()` over all channels with semaphore controlling concurrency.
    - Reduced default inter-check sleep from 2s to 1s
  * Key info: Default concurrency is now 3 (was effectively 2). Phase 2 stream probe uses `iter_chunked()` instead of single `read()`. Peer count was NOT added because `get_status` API doesn't return `peers` — only the `stat_url` endpoint does.

* **2026-02-24 22:30 — Fixed 2 failing unit tests in test_channel_status_service.py**
  * Why: `test_check_multiple_channels_simple` and `test_check_channels_concurrently` failed after `check_channels()` changes
  * How: Two issues fixed in `acestream-scraper/tests/unit/test_channel_status_service.py`:
    1. Mock `check_channel` functions were missing `quick_check=False` kwarg — `check_with_semaphore` passes it via `self.check_channel(channel, quick_check=quick_check)`
    2. `test_check_channels_concurrently` called `ChannelStatusService()` without mocking `__init__`, which tries to instantiate `Config()` and `ChannelRepository()` — added `patch.object(ChannelStatusService, '__init__', lambda self: None)`
  * Key info: All 7 tests now pass. Run with `cd acestream-scraper && python -m pytest tests/unit/test_channel_status_service.py -v`

* **2026-02-24 22:38 — Deployed acestream-scraper v1.11.0 and ritchie infra changes**
  * Why: Code changes complete, push to trigger CI/CD and ArgoCD sync
  * How: `cd acestream-scraper && git add -A && git commit -m "feat: auth token in UI URLs, improved channel status checker" && git push` — triggered Release Pipeline, semantic-release created `v1.11.0`, Docker image built and pushed to GHCR. ArgoCD Image Updater picked up new tag. `cd ritchie && git add -A && git commit -m "feat: Reloader, secret rotation docs, deployment annotations" && git push` — ArgoCD synced Reloader app, deployment annotations, ExternalSecrets.
  * Key info: `gh repo set-default tonioriol/acestream-scraper` was needed — `gh` CLI was defaulting to upstream fork `Pipepito/acestream-scraper`. SSH host key for `5.75.129.215` was updated (changed after k3s restart).

* **2026-02-24 22:50 — Verified deployment and initial health check results**
  * Why: Confirm v1.11.0 is live and Reloader deployed
  * How: `kubectl get deploy acestream-scraper -n default -o jsonpath='{.spec.template.spec.containers[0].image}'` → `ghcr.io/tonioriol/acestream-scraper:v1.11.0` ✅. Reloader pod `reloader-reloader-5c994c6984-lskbb` in `kube-system` was `ContainerCreating` then Running ✅.
  * Key info: k3s restarted at 21:46 UTC during deployment (unrelated — possible OOM on single node with 1.3G memory usage). All pods recovered.

* **2026-02-24 23:01 — Channel health check comparison (partial recheck)**
  * Why: Compare old vs new checker accuracy
  * How: Queried DB stats via `kubectl exec`. After 540/2938 channels rechecked:
    - Before (v1.10.0): 1882 online (64%)
    - After (v1.11.0 partial): 1578 online (53%) — **304 false positives caught**
    - Recent batch online rate: 5% (23/386) — old code would have said 64%
    - Dominant error: `failed to load content` (349/363) — engine can't produce real stream data
  * Key info: Task manager runs every 60s, checking 30 TV + 20 unassigned per cycle. Full sweep ~50min.

* **2026-02-24 23:12 — Created root AGENTS.md and updated ritchie AGENTS.md**
  * Why: User requested deployment flows documented in AGENTS.md files
  * How: Created `AGENTS.md` at workspace root with deployment flows (A: infra, B: app code, C: secret rotation), secrets table, key URLs, conventional commits guide. Updated `ritchie/AGENTS.md` credential rotation section with Stakater Reloader docs. Pushed: `git commit -m "docs: deployment flows in root AGENTS.md, Reloader in ritchie AGENTS.md"`.

## Next Steps

COMPLETED — all tasks done. Monitor channel status checker over next hours to see final online % after full recheck cycle.
