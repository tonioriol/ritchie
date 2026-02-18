# feat-acestreamio-online-grouping-posters: Online markers, channel grouping, and poster proxy

## TASK

Improve the Acestreamio Stremio addon with three features:
1. Add online/offline markers (🟢/🔴/⚪) at both catalog and stream level
2. Fix channel grouping so quality variants (FHD/HD/SD) of the same channel are grouped together
3. Add a poster proxy that converts remote channel logos into Stremio-compatible 2:3 poster format

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

### REPO

`/Users/tr0n/Code/acestreamio` (addon source — deployed via CI to `ghcr.io/tonioriol/acestreamio`)

### RELEVANT FILES

* `/Users/tr0n/Code/acestreamio/addon.js` — Stremio addon logic (catalog, meta, stream handlers)
* `/Users/tr0n/Code/acestreamio/channels.js` — Channel fetching from scraper API + transformation
* `/Users/tr0n/Code/acestreamio/server.js` — Express server wiring (stremio-addon-sdk + poster proxy)
* `/Users/tr0n/Code/acestreamio/poster-proxy.js` — Sharp-based image processing for poster format
* `/Users/tr0n/Code/acestreamio/.gitignore` — Added .poster-cache/
* `/Users/tr0n/Code/acestreamio/.dockerignore` — Added .poster-cache
* `/Users/tr0n/Code/acestream-scraper/v2/backend/app/services/channel_status_service.py` — Scraper's `is_online` check logic (read-only reference)

## PLAN

- ✅ Add `is_online` field passthrough from scraper API to addon channel objects
- ✅ Stop filtering offline channels (show all with status markers)
- ✅ Add `isGroupOnline()` for 3-state group status (true/false/null)
- ✅ Add `onlineMarker()` returning 🟢/🔴/⚪
- ✅ Prefix catalog meta names and stream labels with markers
- ✅ Clean up dead code from server.js (buildM3U, list.js import, playlist endpoint)
- ✅ Fix grouping: strip 4-char hash suffix from channel names (`stripHashSuffix()`)
- ✅ Fix grouping: use `tvg_id` from M3U as canonical grouping key (replaces regex hacks)
- ✅ Add poster proxy endpoint (`/posters/proxy?url=...`)
- ✅ Wire poster proxy into server.js and addon.js meta responses
- ⬜ Remove list.js, converter.js from acestreamio (deferred — once stable)

## EVENT LOG

* **2026-02-17 23:30 - Added online/offline markers to catalog and streams**
  * Why: User wanted visual indication of channel status at both catalog level (channel names) and stream level (variant labels)
  * How: Modified `channels.js` to pass `is_online` (raw, not coerced) and `last_checked` through `transformChannel()`. Stopped filtering by `is_online` in `fetchFromApi()` — now filters only `status === 'active'`. Added `isGroupOnline()` (returns true if any variant online, false if all checked offline, null if all unchecked) and `onlineMarker()` (🟢/🔴/⚪) to `addon.js`. Prefixed `groupedChannelToMeta()` name and stream handler labels with markers.
  * Key info: Commit `0383c78`, deployed as v1.11.0. Verified: 244 channels, 236🟢, 8🔴

* **2026-02-17 23:45 - Cleaned up dead code from server.js**
  * Why: `buildM3U`, `list.js` import, and `/playlist.m3u` endpoint were no longer used after refactoring to dynamic channel fetching
  * How: Removed 55 lines: `escapeAttr()`, `escapeTitle()`, `buildM3U()`, `list.js` import, `/playlist.m3u` route, trailing comments
  * Key info: Committed with the online markers commit `0383c78`

* **2026-02-17 23:50 - Fixed channel grouping: strip hash suffix**
  * Why: Channel names included 4-char hash suffixes (e.g., "DAZN 1 FHD ad6d") preventing proper grouping — 244 ungrouped channels instead of ~120
  * How: Added `stripHashSuffix()` to `channels.js` with regex `\s+[0-9a-f]{4}$/i`. Applied in `parseName()` to channel_name extraction.
  * Key info: Commit `99a4cb6`, deployed as v1.11.1. Result: 202 grouped channels, 197🟢, 5🔴

* **2026-02-18 00:00 - Added 3-state online marker**
  * Why: 48 channels had never been checked by the scraper (defaulted to `is_online: true`). The `is_live == 1` check only verifies P2P swarm existence, not actual video broadcast.
  * How: Updated `isGroupOnline()` for proper 3-state logic (true/false/null). Updated `onlineMarker()` to return ⚪ for null (unchecked). Also expanded `stripHashSuffix` regex from `[0-9a-f]` to `[0-9a-z]` to catch non-hex suffixes like "f33y".
  * Key info: Commit `1077a7a`, deployed as v1.11.2. Verified: 202 channels, 197🟢, 5🔴, 0⚪

* **2026-02-18 00:10 - Fixed grouping: use tvg_id from M3U as canonical key**
  * Why: User reported "grouping isn't working" — "DAZN 1 FHD" and "DAZN 1" remained separate groups. Regex stripping was fragile.
  * How: Discovered scraper's `tvg_id` field (from M3U `tvg-id` attribute) already defines proper channel grouping (e.g., "DAZN 1 HD" groups all FHD/HD/SD variants). 141/244 channels have tvg_id; 103 without are mostly unique. Passed `tvg_id` through `transformChannel()`. Updated `getChannelKey()` in `addon.js` to use `tvg_id` as primary grouping key, falling back to `channel_name`. Removed `deriveChannelId()` and `stripQualitySuffix()`.
  * Key info: Commit `2a3ff60`, deployed as v1.11.3. Result: 172 grouped channels (down from 202). DAZN 1 HD correctly groups 5 variants.

* **2026-02-18 00:25 - Added poster proxy for Stremio 2:3 format**
  * Why: Remote logos from M3U sources are small/square icons, not Stremio poster format (2:3 ratio, 300×450px)
  * How: Created `poster-proxy.js` using `sharp` (already a dependency). Fetches remote logos, resizes to fit 210×200px area (preserving aspect ratio), centers on dark navy 300×450px canvas, outputs progressive JPEG (quality 85, mozjpeg). Caches to disk (`.poster-cache/`, 7-day TTL). Deduplicates concurrent requests. Wired into `server.js` as `GET /posters/proxy?url=<encoded-logo-url>`. Updated `groupedChannelToMeta()` in `addon.js` to generate proxy URLs via `posterUrl()`. Added `.poster-cache/` to `.gitignore` and `.dockerignore`.
  * Key info: Commit `dde9139`, deployed as v1.12.0. 118/172 channels use proxy, 54 use default poster (no logo). Output verified: 300×450 progressive JPEG, ~4.7KB. Some ibb.co logo URLs are broken (404 from source, not proxy issue).

## SCRAPER `is_online` LIMITATION

The scraper's channel status check (`channel_status_service.py:40-194`) queries the raw engine at port 6878 with `is_live == 1`. This only verifies that a P2P swarm exists for the infohash, NOT that actual video is being broadcast. Event-only channels (e.g., "SOLO EVENTOS") may show as online when they have idle swarms but no active stream. There is no fix possible without actually streaming each channel.

## GIT COMMITS (acestreamio repo)

```
0383c78  feat: add online/offline markers to catalog and streams (+ server.js cleanup)
99a4cb6  fix: strip 4-char hex hash suffix from channel names for proper grouping
1077a7a  fix: add 3-state online marker (🟢 peers / 🔴 offline / ⚪ unchecked)
2a3ff60  fix: use tvg_id from M3U source as canonical grouping key
dde9139  feat: add poster proxy for Stremio-compatible 2:3 poster images
```

Semantic-release versions: v1.11.0, v1.11.1, v1.11.2, v1.11.3, v1.12.0

## Next Steps

- [ ] Remove `list.js`, `converter.js` from acestreamio (deferred until stable)
- [ ] Retire `charts/acestream` (engine + proxy now in acestream-scraper)
