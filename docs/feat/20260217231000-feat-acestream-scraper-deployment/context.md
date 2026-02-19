# feat-acestream-scraper-deployment: Deploy acestream-scraper as all-in-one channel discovery service

## TASK

Deploy [pipepito/acestream-scraper](https://github.com/pipepito/acestream-scraper) as a consolidated all-in-one pod bundling the acestream engine, Acexy proxy, ZeroNet, and Flask scraper app. Fix deployment issues (SQLite migrations, health probes, port conflicts), configure scraping sources, and verify channel discovery works.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* [`charts/acestream-scraper/values.yaml`](charts/acestream-scraper/values.yaml:1) — Central configuration (ports, features, persistence)
* [`charts/acestream-scraper/templates/deployment.yaml`](charts/acestream-scraper/templates/deployment.yaml:1) — Deployment with initContainers (seed-config, db-migrate)
* [`charts/acestream-scraper/templates/configmap.yaml`](charts/acestream-scraper/templates/configmap.yaml:1) — Seed config.json for scraper
* [`charts/acestream-scraper/templates/service.yaml`](charts/acestream-scraper/templates/service.yaml:1)
* [`charts/acestream-scraper/templates/pvc.yaml`](charts/acestream-scraper/templates/pvc.yaml:1)
* [`charts/acestream-scraper/templates/_helpers.tpl`](charts/acestream-scraper/templates/_helpers.tpl:1)
* [`charts/acestream-scraper/Chart.yaml`](charts/acestream-scraper/Chart.yaml:1)
* [`apps/acestream-scraper.yaml`](apps/acestream-scraper.yaml:1) — ArgoCD Application
* [`plans/acestream-scraper-integration.md`](plans/acestream-scraper-integration.md:1) — Architecture plan

## ARCHITECTURE

### Port layout (single pod)

| Service              | Port  | Purpose                                    |
|----------------------|-------|--------------------------------------------|
| AceStream Engine     | 6878  | P2P engine HTTP API                        |
| Acexy                | 8080  | HTTP proxy to engine (acestream-http-proxy) |
| Flask scraper        | 8000  | Web UI + REST API + M3U playlist           |
| ZeroNet              | 43110 | P2P site access for channel lists          |

### Environment variables (key ones)

```yaml
ENABLE_ACESTREAM_ENGINE: "true"   # start bundled engine
ENABLE_ACEXY: "true"              # start bundled Acexy proxy
ACESTREAM_HTTP_PORT: "6878"       # engine port (NOT 8080, conflicts with Acexy)
ACESTREAM_HTTP_HOST: "localhost"   # all services in same pod
FLASK_PORT: "8000"                # scraper web UI
```

### Config relationships

The entrypoint script starts the engine with `--http-port $ACESTREAM_HTTP_PORT`. Acexy reads `ACEXY_HOST`/`ACEXY_PORT` (defaults to `localhost:6878`) and listens on `:8080`. The scraper's [`config.json`](charts/acestream-scraper/templates/configmap.yaml:8) points `base_url` and `ace_engine_url` at Acexy (`localhost:8080`).

## WHAT WAS DONE

### 1. SQLite migration fix

The pod was crash-looping because a previous failed Alembic migration left a `_alembic_tmp_scraped_urls` table in the SQLite database. Fixed by:

- Exec'd into the pod to drop the leftover table and re-run migrations
- Added a permanent [`db-migrate` initContainer](charts/acestream-scraper/templates/deployment.yaml:35) that automatically drops any `_alembic_tmp_*` tables and runs `python manage.py upgrade` before the main container starts
- The initContainer disables engine/Acexy/Tor/Warp (only needs Python + SQLite)

### 2. Health probe fix

The scraper does not have a `/health` or `/setup` endpoint. Switched all probes (readiness, liveness, startup) to [`/`](charts/acestream-scraper/templates/deployment.yaml:101) which always returns HTTP 200.

**Commit:** `33cc87a` — fix: add db-migrate initContainer, switch probes to /

### 3. Consolidated all-in-one deployment

Instead of running separate acestream engine + acestream-http-proxy (Acexy) pods, enabled both as bundled services inside the acestream-scraper pod:

- Set `ENABLE_ACESTREAM_ENGINE: "true"` and `ENABLE_ACEXY: "true"` in [`values.yaml`](charts/acestream-scraper/values.yaml:17)
- Changed `ACESTREAM_HTTP_HOST` from `"acestream-proxy"` to `"localhost"` (all in same pod)

**Commit:** `29ea2fc` — feat: enable bundled acestream engine + Acexy in acestream-scraper

### 4. Engine port conflict fix

The engine was starting on port 8080 (same as Acexy) because `ACESTREAM_HTTP_PORT` was set to `"8080"`. The engine silently failed (port 6878 was CLOSED). Fixed by setting [`ACESTREAM_HTTP_PORT: "6878"`](charts/acestream-scraper/values.yaml:23).

After fix, all ports verified open: 6878 (engine), 8080 (Acexy), 8000 (Flask), 43110 (ZeroNet).

**Commit:** `7865ac2` — fix: engine port 6878 (was conflicting with Acexy on 8080)

### 5. Scraping sources configured

Added channel sources via the scraper REST API (`POST /api/urls/`):

| URL | Type | Result |
|-----|------|--------|
| `https://ipfs.io/ipns/k2k4r8oqlcjxsritt5mczkcn4mmvcmymbqw7113fz2flkrerfwfps004/` | regular | ✅ 244 channels scraped |
| `http://127.0.0.1:43110/18D6dPcsjLrjg2hhnYqKzNh2W6QtXrDwF` | zeronet | ⏳ ZeroNet syncing |
| `http://127.0.0.1:43110/1JKe3V9qScFiDmcXMqq8R5x5Xpniav2ynV` | zeronet | ⏳ ZeroNet syncing |
| Various elcano.top / IPFS IPNS URLs | regular | ❌ JS-rendered or deprecated |

ZeroNet sites require first-time P2P sync (5–15 min) to download `content.json` from peers.

### 6. ConfigMap updated for Acexy

[`configmap.yaml`](charts/acestream-scraper/templates/configmap.yaml:11) now uses `ACEXY_PORT | default "8080"` for `base_url` and `ace_engine_url`, so the scraper talks to Acexy (which proxies to the engine) rather than directly to the engine.

## ERRORS & FIXES REFERENCE

| Error | Root cause | Fix |
|-------|-----------|-----|
| `_alembic_tmp_scraped_urls already exists` | Failed migration left temp table | Drop `_alembic_tmp_*` tables in [`db-migrate` initContainer](charts/acestream-scraper/templates/deployment.yaml:41) |
| `/health` returns 404 | Scraper has no `/health` endpoint | Switch probes to [`/`](charts/acestream-scraper/templates/deployment.yaml:101) |
| Port 6878 CLOSED after enabling engine | `ACESTREAM_HTTP_PORT=8080` conflicted with Acexy | Set [`ACESTREAM_HTTP_PORT: "6878"`](charts/acestream-scraper/values.yaml:23) |
| Config.json stale after env changes | PVC retains old config.json | Delete config.json from PVC before redeploy so seed-config initContainer recreates it |
| `URL type must be explicitly specified` | API requires `url_type` field | POST with `{"url": "...", "url_type": "regular"}` or `"zeronet"` |
| IPFS IPNS URLs return empty/410 | `ipfs.io` deprecated IPNS resolution; some pages are JS-rendered | Use direct content URLs or alternative gateways |

## GIT COMMITS (this session)

```
33cc87a fix: add db-migrate initContainer, switch probes to /
29ea2fc feat: enable bundled acestream engine + Acexy in acestream-scraper
7865ac2 fix: engine port 6878 (was conflicting with Acexy on 8080)
```

### 7. Cloudflare Tunnel exposure

Exposed acestream-scraper web UI via Cloudflare tunnel:
- `scraper.tonioriol.com` → acestream-scraper Flask (port 8000)
- `ace.tonioriol.com` → acestream-scraper Acexy (port 8080)
- Updated Cloudflare tunnel remote config via API (local ConfigMap overridden by remote — see AGENTS.md)

### 8. Broken IPFS URL cleanup

Deleted non-working IPFS URL `k51qzi5uqu5di00365631...` (returns 404) via `DELETE /api/urls/<id>`.

### 9. M3U source with tvg-logo

Added M3U source URL from k2k4r8 IPNS that includes `tvg-logo` attributes. All 244 channels now have logo URLs extracted from the M3U metadata. Logos come from various sources (GitHub raw, ibb.co, wikimedia, etc.).

## PENDING WORK

- **ZeroNet sync**: Sites `18D6dPcsjLrjg2hhnYqKzNh2W6QtXrDwF` and `1JKe3V9qScFiDmcXMqq8R5x5Xpniav2ynV` still syncing — will auto-scrape when content downloads
- **Retire `charts/acestream`**: Engine + proxy now consolidated in acestream-scraper; the separate [`charts/acestream/`](charts/acestream/Chart.yaml:1) chart can be removed

## API REFERENCE (acestream-scraper)

```bash
# List channels
kubectl exec -it deploy/acestream-scraper -- curl -s localhost:8000/api/channels/ | python -m json.tool

# List configured URLs
kubectl exec -it deploy/acestream-scraper -- curl -s localhost:8000/api/urls/

# Add a scraping source
kubectl exec -it deploy/acestream-scraper -- curl -s -X POST localhost:8000/api/urls/ \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/channels", "url_type": "regular"}'

# Delete a source
kubectl exec -it deploy/acestream-scraper -- curl -s -X DELETE localhost:8000/api/urls/<id>/

# Get M3U playlist
kubectl exec -it deploy/acestream-scraper -- curl -s localhost:8000/playlist.m3u

# Force re-scrape
kubectl exec -it deploy/acestream-scraper -- curl -s -X POST localhost:8000/api/scrape/
```

Note: All `kubectl` commands require `export KUBECONFIG=${PWD}/clusters/neumann/kubeconfig`.
