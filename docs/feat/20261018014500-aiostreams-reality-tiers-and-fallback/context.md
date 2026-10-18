---
title: "AIOStreams max/mid/min tiers with untagged fallback after Real-Debrid expiry"
status: done
repos: [ritchie]
tags: [deployment]
related: [20260729115122-aiostreams-language-and-tier-fallback]
created: 2026-10-18
---

# AIOStreams max/mid/min tiers with untagged fallback after Real-Debrid expiry

## TASK

**Goal:** Make reality-TV episodes (Real Housewives, Love Island, Drag Race, Selling Sunset) return playable TorBox links, keep Catalan → Spanish → English sections, show per resolution tier (2160p, 1080p, 720p) the largest, median and smallest file, and show unknown-resolution / low-resolution / untagged-language releases only when no proper row exists — as fast as possible.

**Done when:** the 17-episode reality test set returns links for episodes that were empty, first-request latency is no worse than baseline, and the saved config is recorded.

## LOG

### 2026-10-18 01:45 — Empty reality results diagnosed; slow first requests traced to MediaFusion; new tier config applied

- Why: Real-Debrid premium expired; the user saw too few links for older/niche reality titles and suspected the TorBox cache.
- Diagnosis: Baseline over 17 episodes from Toni's/Laura's Stremio + Nuvio watch history — 10 returned zero playable rows. In every empty case the upstream addons *had* releases; our own filters removed them, mostly `excludedResolutions: Unknown` (~140 releases) and fixed per-resolution size caps (e.g. 30 Love Island S8E36 releases > 5.37 GB). English section also required a parsed English tag, which reality releases often lack. Not a TorBox cache problem.
- Latency: first (uncached) requests took ~8.4 s; repeats ~1 s. Server log shows `MediaFusion TB | RD … aborted due to timeout took 8005` on every first request. MediaFusion contributed 0 rows in the baseline; Comet and wrapped Torrentio supplied all rows. More presets never speed things up — responses wait for the slowest one.
- Change (one complete `PUT /api/v1/user`, readback identical outside `trusted`):
  - `realdebrid` service disabled; MediaFusion preset disabled; all preset timeouts 8000 → 5000 ms; Torz stays off.
  - `excludedResolutions: []`; size limit reduced to a 50 MB floor (movies/series), no per-resolution caps; `resultLimits: {global: 40}` (the selectors bound each tier).
  - Ranked tags kept `C`/`S`/`E`; added `M` (C∪S∪E at 2160p/1080p/720p), `F` (everything not in `M`: other resolutions, Unknown, untagged language), `FB` (F cached-first), `E2160p`/`E1080p`/`E720p` (English per tier, cached-first).
  - Required selectors: fallback (3 rows from `FB` only when `M` is empty), Catalan and Spanish one row per main tier, English per tier = largest + smallest + first at/below median, backfilled, max 3.
- Rollback source: `.agent-runs/debrid-compare/backup-20261018T013331.json` at the workspace root (contains secrets; never commit).
- Early result (before rate limiting interrupted the run): RHOBH S15E1, S14E5, S10E5, S3E5, Love Island S8E36, S3E5 and Drag Race S17E1 went from 0 to 2–3 cached TorBox rows each; responses 0.5–1.9 s. Remaining episodes hit the AIOStreams per-IP `stremio-stream` rate limit from the test burst, not a config error. A Real-Debrid row can still appear via the wrapped Torrentio instance, which carries its own debrid keys.
- Commit: e5e892e.

### 2026-10-18 01:50 — Full test set passes, dead RD rows excluded, cold latency verified

- Spaced re-run (7 s apart, avoiding the per-IP rate limit) of the remaining 7 episodes: Drag Race S10E5 0→3, All Stars S9E2 0→3 (2160p/1080p/1080p), Drag Race España S5E11 1→1, Ultimate Girls Trip S5E2 1→1 and S2E1 2→1 TB, Selling Sunset S8E11 1→1 and S3E1 3→3. All 17 episodes now return rows; none got worse (Girls Trip S2E1 lost only a dead RD row).
- Real-Debrid rows came from wrapped Torrentio's own debrid keys. Added `excludedStreamExpressions: [service(streams,'realdebrid')]` in a second complete PUT; readback identical. RHOBH S15E21, Love Island S7E10 and Girls Trip S2E1 now show only TorBox rows.
- Cold first requests on never-requested episodes: 0.86–1.65 s (repeat 0.38–0.54 s), down from ~8.4 s.
- Autoplay: adjacent RHOBH S15E20/E21 share bingeGroup `…|1080p|MeGusta`, so binge continuation works on a matching release group.
- Operator doc `docs/STREMIO-AIOSTREAMS.md` "Current configuration" rewritten for this setup. Rollback not needed.

### 2026-10-18 02:21 — Nuvio TV set to auto-play the first instant AIOStreams link

- Why: the user wants playback to start without choosing a link; with "first source", an uncached (⏳) Catalan/Spanish row could win over an instant one.
- Nuvio TV syncs per-profile settings as a blob via `rpc/sync_pull_profile_settings_blob` / `sync_push_profile_settings_blob` (`p_profile_id`, `p_platform: "tv"`, `p_settings_json`). Mobile and desktop blobs are separate and carry no autoplay keys.
- `StreamAutoPlaySelector` (NuvioTV dev) in `REGEX_MATCH` mode matches case-insensitively against addon name + stream name + title + description + URL and plays the first match in list order, so `⚡` (in our formatter's name) picks the first cached row and keeps the C → S → E order. A matching bingeGroup from the previous episode still takes priority.
- Pushed to both profiles (Toni 1, Laura 2), readback identical: `stream_auto_play_mode=REGEX_MATCH`, `stream_auto_play_regex=⚡`, `stream_auto_play_source=INSTALLED_ADDONS_ONLY`, `stream_auto_play_selected_addons=[AIOStreams]`. Timeout unchanged (Toni 3 s, Laura default). Pre-change blobs backed up in `.agent-runs/debrid-compare/nuvio-settings-{1,2}.backup-*.json` (secrets, never commit).
- If no row is ⚡, the selector returns nothing and Nuvio shows the picker. Devices apply the cloud blob on their next foreground pull (≥60 s interval) or app restart. On-TV playback not yet observed.

### 2026-10-18 09:14 — Regex autoplay failed in practice; switched to first-stream with an AIOStreams pin

- User report: the ⚡ regex mode did not autoplay on Android TV or on the phone; "Auto-play first source" on the phone did. New requirement: the first result must always be the highest-quality, original-language, instant link.
- AIOStreams side: added a required SEL at the top that pins one stream: cached streams whose language is `Original` (AIOStreams adds it when the file's language equals the TMDB original language) or `Unknown` (untagged reality releases are original audio), taking the best resolution first (2160p → 1080p → 720p → any), then sort order (largest size). `pin(..., 'top', true)` runs after sorting, so it overrides the C → S → E order only for row 1. Applied with one full PUT; readback matched (`candidate3.json`; rollback = `live-before-pin.json`).
- Re-test on the 17 episodes: row 1 is instant (⚡) in all 17 and is the highest available resolution, e.g. Drag Race S17E1 → 2160p 7.66 GB, All Stars S9E2 → 2160p 7.08 GB, Drag Race España → Spanish 1080p.
- Nuvio TV (profiles 1 and 2): `stream_auto_play_mode=FIRST_STREAM`, source `ALL_SOURCES`, no addon restriction, matching the phone's working setup. Readback matched.

### 2026-10-18 09:52 — Rows reordered: original → Catalan → Spanish, per resolution

- New user rule: for each resolution (highest first), show original language, then Catalan, then Spanish, each the highest-quality and largest file; fall back to anything when none of those exist.
- Config (`build-slots.py` on top of the live config, then a row-1 pin fix; result `candidate5.json`, rollback `live-before-slots.json`):
  - Ranked tags: `C`, `S` (unchanged) and new `O` = `Original` ∪ `Unknown`. The `E`, `M`, `F`, `FB` and `E<res>` tags were removed.
  - Preferred labels, disjoint: Original (`O`), Catalan (`C` − `O`), Spanish (`S` − `O` − `C`).
  - Sort: resolution, preferred label, cached, quality, size. `preferredQualities` now lists every quality (remux → … → HDTV → Unknown → cam-likes) so quality actually ranks.
  - Required: one row per resolution per language (`perGroup(..., 'resolution', 1)`); fallback `perGroup(streams, 'resolution', 1)` only when no O/C/S stream exists.
  - Row-1 pin: the first cached stream in sort order of original → Catalan → Spanish → anything, with `pin(..., false)` so it only reorders. The first attempt used `true`, which added the pinned stream on top of its per-resolution row and produced duplicate-looking 1080p rows.
  - Formatter: 🎬 for original; 🇬🇧 removed (English is original for English shows).
- English for a non-English show is no longer shown; that follows the stated rule.
- Re-test, 17 episodes: row 1 is ⚡ on all 17; 1–7 rows each. Examples: Drag Race S17E1 → 🎬 2160p 7.66 GB / 1080p 4.98 GB / 720p 3.12 GB / N/A; Drag Race España → 🇪🇸 1080p 3.09 GB; Selling Sunset S3E1 → 🎬 ⚡ 1080p pinned, then 🎬 ⏳ 2160p 2.89 GB, then 720p original before 🇪🇸 720p.

### 2026-10-18 10:01 — Edge-case check: does dropping English hurt?

- Method: a throwaway AIOStreams user with the live rules, minus the required selectors and the Catalan/Spanish regexes (the API refuses regex for new users), limit 400, labels exposed. Its config and URL are in `.agent-runs/debrid-compare/edge/`. Rows were rebuilt offline with the same original → Catalan → Spanish per-resolution logic.
- English-original titles (Dune 2, Oppenheimer, The Bear): English is `Original`, so nothing is lost; row 1 is 2160p (REMUX for the films).
- Non-English originals (Parasite, Squid Game, Dark, Spirited Away, Amélie, La Casa de Papel): the original-language rows were the same or better resolution than the hidden English ones, with two exceptions:
  - La Casa de Papel S1E1: a cached 2160p English/Hindi dual-audio WEB-DL is hidden; row 1 is the 1080p REMUX.
  - Amélie: a cached 2160p "AI_UPSCALE" BluRay is hidden (fake 4K; hiding it is fine).
- `Unknown` counted as original: on non-English shows some untagged files are English-titled releases (e.g. "Money Heist …"), so an untagged row can be a dub. Known limit of the filename tags.
- Thin catalogue (Merlí S1E1): one uncached link only, so there is no ⚡ row and autoplay will not start.
- No config change made.

### 2026-10-18 10:25 — Decision: no English tier; test user deleted

- Simulated two variants offline on the edge-case titles: English counted as original (it moved La Casa de Papel's row 1 to a 1.2 GB English/Hindi 2160p dub, so it was rejected) and English as a second choice after original (row 1 unchanged on all 10 titles, but it added 2–5 dub rows per foreign title and put English dubs ahead of Catalan/Spanish).
- Corrections: the "Pa Negre" id was wrong (it returned *Van Diemen's Land*), and Merlí's single result was a "Unable to get metadata" error row, not a stream.
- User decision: keep the live original → Catalan → Spanish config unchanged.
- The throwaway diagnostic AIOStreams user was deleted (`DELETE /api/v1/user` with basic auth; a follow-up read returns "Invalid UUID or password").

### 2026-10-18 10:44 — Diagnosis: Gènesi (tt38483587) shows one uncached link

- Live AIOStreams returns one row per episode: an uncached Russian dub, `Genesi.s01e0N.WEBRip.XviD.Rus.RuDub.tv.avi`, about 550–600 MB.
- Raw Torrentio (no debrid, no filters) returns the same single torrent for 1x1, 1x2 and 1x5. Comet adds nothing. A Knaben search found no Catalan or Spanish release.
- Cause: supply, not filtering. It is a 3Cat original (premiered 2026-09-21 on TV3/3Cat; Netflix holds later distribution) and nobody rips 3Cat. It shows up only through the "show anything" fallback, and it is uncached because nobody has added it to TorBox.
- Takeaway: TV3/3Cat originals (also Merlí) will mostly be absent until a Netflix WEB-DL appears; no config change helps.

### 2026-10-18 10:54 — Diagnosis: why the 3alacarta addon shows nothing on Gènesi

- The 3alacarta Stremio addon (`community.3alacarta` v0.0.3, beamup) has Gènesi under its own id `3alc:76716`, with all 6 episodes. Each episode has 3 direct 3Cat streams: HLS "Auto (up to 1080p)", a 720p MP4, and a 720p audio-description MP4. The HLS returns 200.
- Its manifest declares `idPrefixes: ["3alc:", "tt"]`, but every IMDb id returns `{"streams":[]}`: Gènesi tt38483587, Merlí, Les de l'hoquei, and movies. None of its catalog items carry an `imdb_id`. In practice it serves only `3alc:` ids.
- So a title opened from Cinemeta/TMDB (tt id) never matches. It only plays when opened from 3alacarta's own catalog or search. Adding it to AIOStreams as-is would also return nothing, because AIOStreams queries with the tt id.
- Fix options: open it from the 3alacarta catalog in Nuvio, or build a small tt→3alc bridge (Cinemeta name/year → 3alacarta search → meta → season/episode map) that AIOStreams can use as a custom addon.

### 2026-10-18 11:05 — Built: alacarta-bridge (tt → 3alc), verified locally, not deployed

- Mapping: TMDB `find` (ca-ES) gives the titles. Series match the normalised title against the 3Cat programme list (`api.3cat.cat/programestv?_format=json&items_pagina=5000`, about 1319 programmes), whose `id` equals the 3alc series id (Gènesi 76716, Merlí 54076, Les de l'hoquei 59216), then pick the season/episode from the 3alacarta meta. Films aren't in that list, so they use the 3alacarta movie search with an exact normalised title match. 3alacarta's own search can't find Merlí, so it isn't used for series.
- Output: audio-description variants dropped. `behaviorHints.filename` = `<Title> S01E01 1080p WEB-DL Catalan.mp4` (films use the year), so AIOStreams title/S-E matching passes and the `catalan-name` regex puts it in the C tier.
- Local results: Gènesi 1x1 → 1080p HLS + 720p; Merlí 2x3 → 1080p/720p/480p; Alcarràs tt11930126 → 1080p/720p/480p; Breaking Bad → 0.
- Correct ids: Merlí = tt4580372, Alcarràs = tt11930126.
- Deploy shape (commit 49f0fb9, not pushed): `charts/alacarta-bridge` + `apps/alacarta-bridge.yaml`. Code is in `files/server.mjs` via a ConfigMap on stock `node:24-alpine` (no repo/CI). Internal ClusterIP `alacarta-bridge.media.svc` (no DNS/tunnel). TMDB key via ESO from the 1P `aiostreams` item, field `tmdb_api_key`. helm lint and the server dry-run are clean.
- Known limit: the row-1 pin uses `cached()`, which requires `service.cached===true`, so 3Cat http streams never reach row 1. Gènesi would have no row 1 and no autoplay unless that expression is changed (pending user decision).

### 2026-10-18 11:16 — Decision: fix the 3alacarta addon itself, not a separate bridge

- The 3alacarta addon is the user's own: `~/Code/3alacarta-stremio-addon` (GitHub `tonioriol/3alacarta-stremio-addon`, deployed to beamup `60b9a578d49f`). Its tt handling was a hard-coded 6-entry `imdb3alcMap`, which is why Gènesi/Merlí/films returned nothing.
- Plan: put the automatic mapping into the addon (new `src/lib/imdb.js`). Cinemeta name → 3Cat programme list (series) or the 3Cat PUF_PEL film list, 317 films (movies); manual map still wins. tt streams get a release-style `behaviorHints.filename` (… WEB-DL Catalan) and audio-description variants dropped. Then add the addon to AIOStreams directly.
- The ritchie bridge commit 49f0fb9 (not pushed) will be dropped.

### 2026-10-18 11:19 — 3alacarta addon fixed locally (2c02e13 in 3alacarta-stremio-addon, v0.0.5, not pushed)

- Verified locally on port 49905:
  - Gènesi 1x1/1x2 → 1080p + 720p.
  - Merlí 1x1 and 2x3 → 3 streams each.
  - Alcarràs → 1080p/720p/480p, named `Alcarràs 2022 …`. The year comes from Cinemeta because 3Cat's own date is the 2023 broadcast.
  - Crims (manual map) still works.
  - Breaking Bad → [].
  - `3alc:` ids unchanged.
- Gotcha: the 3Cat PUF_PEL film list only returns the full 317 films with the `origen=llistat&fills=…&perfils_extra=…` params; without them it returns 2 items.
- The bridge commit was dropped from ritchie history (it was never pushed). The rebase rewrote the two context commits to 810eb1f/a282fff.
- Pending, needs the user's go-ahead:
  - push the addon to GitHub + beamup;
  - add it to AIOStreams;
  - decide whether the row-1 pin may fall back to 3Cat links, which `cached()` excludes.

### 2026-10-18 12:33 — 3alacarta 0.0.6 live on beamup; manual IMDb map gone (b01999e)

- Hosting decision (user): stays on beamup for now, `https://60b9a578d49f-3alacarta-stremio-addon.baby-beamup.club`.
  - Cloudflare caches responses for 4h, so add `?x=` to bust the cache when checking.
  - Moving to the cluster is viable. From Hetzner (DE), 3Cat media.jsp returns the same `-es` URLs as from Spain; geo is enforced at playback.
- 4 of the 6 manual entries already resolved by title: Crims, Està passant, Joc de cartes, Tor.
- Dubbed titles: the addon now falls back to Wikidata's Catalan label/aliases:
  1. search `haswbstatement:P345=<tt>`;
  2. `wbgetentities` with `languages=ca`.
  - Dragon Ball → "Bola de Drac", DBZ → "Bola de Drac Z". `mappings.js` is deleted.
- Season splits: 3Cat splits seasons differently from IMDb.
  - Bola de Drac: 3Cat 4 seasons (18/65/49/21 = 153) vs IMDb tt0280249 5 seasons (28/25/48/21/31 = 153, plus S0 specials).
  - DBZ: 3Cat 6 seasons = 291 vs IMDb 9 seasons = 291.
  - Absolute numbering and airing order agree on both sides. Spot-checked episode titles at season boundaries: abs 29 "The Roaming Lake" = "El llac màgic", abs 117 "Krillin's Proposal" = "Una afirmació d'en Krilin".
  - Rule: when the Cinemeta regular-episode count (season > 0) equals 3Cat's, pick the 3Cat video by position in airing order. Otherwise use direct season/episode.
  - Verified: DB 1x1/2x1/5x31 and DBZ 4x10/9x38 hit the correct abs episodes.
- Live beamup 0.0.6 results:

  | Request | Streams |
  |---|---|
  | DB 2x1 | 3 |
  | DBZ 9x38 | 3 |
  | Crims 1x1 | 3 |
  | Gènesi 1x1 | 2 |
  | Merlí 2x3 | 3 |
  | Alcarràs | 3 |
  | Breaking Bad | 0 |
- Next: add the addon to AIOStreams as a custom preset. In row 1, fall back to the best C-tier stream from `addon(streams,'3alacarta')` when nothing is cached.

### 2026-10-18 12:49 — 3alacarta wired into AIOStreams; two addon spec fixes needed

- AIOStreams validates addons strictly, and two gaps in 3alacarta blocked it:
  - **Manifest catalogs had no `name`.** The PUT failed with `USER_INVALID_CONFIG … catalogs.0.name`. Fixed in 0.0.7 (ad97ff6).
  - **Subtitles had no `id`.** Every stream was dropped with "invalid item in response" and the addon showed as "No valid streams found". Fixed in 0.0.8 (146699c), using `id = url`.
- AIOStreams caches manifests by URL, and beamup's Cloudflare edge caches `manifest.json` for 4h (it served a stale 0.0.3). The preset therefore uses `manifest.json?v=<version>`; AIOStreams forwards the query string to stream URLs. **Bump `?v=` after every addon deploy.**
- Live config changes (PUT plus an identical readback):
  - custom preset `3alacarta` (instanceId `3alacarta`, timeout 8000, movie and series);
  - row-1 last fallback is now `count(cached(streams)) > 0 ? slice(cached(streams),0,1) : slice(addon(streams,'3alacarta'),0,1)`.
  - Build script: `.agent-runs/debrid-compare/3cat-aio/build.jq`. Rollback: `3cat-aio/backup-20261018T123235.json`.
- End-to-end results through AIOStreams:

  | Title | Result |
  |---|---|
  | Gènesi 1x1 | 3Cat 1080p and 720p shown |
  | Merlí 2x3 | 3Cat 1080p/720p/480p shown |
  | Crims 1x1 | 3Cat 1080p/720p/480p shown |
  | Alcarràs | 3Cat 720p/480p shown |
  | DB / DBZ | no 3Cat rows; enough cached torrents |
  | Breaking Bad | unchanged |

  - 3Cat rows render as `🎬 P2P ⏳`: there is no debrid service, so the formatter treats them as uncached P2P. They tag as Original because the file has no language tag, and Original = Unknown.
- **Open issue:** Merlí 2x3 used to show cached Comet rows at 1080p (978 MB) and 720p. Now 3Cat takes those resolution slots, because `perGroup(resolution, 1)` keeps one row per resolution and the sort put 3Cat first. Row 1 also lost its instant pin ("0 pinned"). Under investigation.
