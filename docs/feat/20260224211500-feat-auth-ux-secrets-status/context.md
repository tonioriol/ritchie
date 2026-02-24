---
title: "Auth UX, secret rotation, and channel status improvements"
status: active
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

## Next Steps

- [ ] Commit and push acestream-scraper changes, trigger release for new image
- [ ] Commit and push ritchie changes (Reloader app, deployment annotations, README, ExternalSecrets)
- [ ] Verify Reloader deploys and watches secrets correctly
- [ ] Monitor channel status checker after deployment — confirm fewer false positives
- [ ] Consider removing unused `stream token` field from 1P item
