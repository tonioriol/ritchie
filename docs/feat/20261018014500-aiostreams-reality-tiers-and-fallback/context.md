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

### 2026-10-18 13:05 — Fixed: 3Cat no longer displaces instant torrents; DB/DBZ now get 3Cat rows

- **Cause of the Merlí regression.** It wasn't the pin. 3Cat streams have no debrid `service`, and the sorter key `cached` is `service?.cached !== false`, so they rank as cached. They therefore took each `perGroup(resolution, 1)` slot from the real ⚡ Comet rows. The row-1 pin itself still works.
- **Fix in AIOStreams.** Wrapped the original/catalan/spanish required rows in `negate(addon(streams,'3alacarta'), …)` and added a sixth required row, `/* 3cat */ slice(addon(streams,'3alacarta'), 0, 1)`. The row-1 fallback is unchanged: the best 3Cat stream when nothing is cached. Built by `3cat-aio/build.jq`; the PUT readback matched.
- **DB/DBZ had no 3Cat rows** because AIOStreams' exact title matching dropped `Bola de Drac S02E01 …` on a "Dragon Ball" request. Addon 0.0.9 (3396429) names files after the Cinemeta/IMDb title, keeping the Catalan title only as a fallback. The preset now uses `?v=0.0.9`.
- **beamup gotcha.** The first `git push beamup` failed with "failed to push some refs" and a second push deployed. During the gap, stale 0.0.8 or empty results appear.
- **E2E (live AIOStreams, after both fixes):**

  | Title | Result |
  |---|---|
  | Gènesi 1x1 | 3Cat 1080p alone (nothing cached, so the fallback pins it) |
  | Merlí 2x3 | ⚡1080p 978 MB · 3Cat 1080p · ⚡720p · ⚡N/A |
  | Alcarràs | ⚡1080p 17 GB · 3Cat 1080p · Catalan/Spanish rows |
  | DB 2x1 | ⚡1080p · 3Cat "Dragon Ball S02E01" · … |
  | DBZ 9x38 | ⚡1080p · 3Cat · ⚡N/A |
  | Crims 1x1 | 3Cat 1080p first, then uncached torrents |
  | Breaking Bad | unchanged (no 3Cat) |

- **Docs.** A "3alacarta (3Cat)" section was added to `docs/STREMIO-AIOSTREAMS.md` covering location, deploy, the `?v=` bump, matching rules, schema requirements and geo. The workspace `AGENTS.md` Key URLs table has a row for it.

### 2026-10-18 14:27 — Diagnosis: 3Cat rows show "P2P ⏳", lose subtitles, and carry only Catalan audio

- **"P2P ⏳" is a formatter label, not the stream type.** In our custom formatter, `{service.shortName::exists[...||"P2P"]}` prints P2P whenever a stream has no debrid service, and `service.cached::istrue[" ⚡"||" ⏳"]` prints ⏳ for the same reason. AIOStreams parses 3Cat as `type: 'live'` (its URL ends in `.m3u8`) and the MP4s as `http`. Both are direct and instant. The fix belongs in the formatter, e.g. `stream.type` / `addon.name` → "3Cat ▶".
- **Subtitles are dropped.** The addon sends `subtitles: [{id,url,lang:'ca'}]`, but AIOStreams' `StreamParser.parse` never copies `stream.subtitles`, so the Stremio output has `subtitles: null`. The way through is the addon `subtitles` resource: AIOStreams aggregates that (`getSubtitles`) and passes it to the player.
- **Audio.** Sampling 20 films plus Merlí, DB and Gènesi: every HLS master has exactly one audio rendition (`LANGUAGE="ca"`) and no in-manifest subtitle renditions. Subtitles are external `.vtt` files (Catalan only). The only other "audio" is the Audiodescripció variant, which the addon already filters out. So 3Cat is always Catalan audio, one track.
- **Language tag.** The filename says "Catalan", and the `catalan-name` regex matches it, but the stream was still tagged O (Unknown). The O/C/S tagging is irrelevant here anyway, because 3Cat is negated out of those rows and has its own row.

### 2026-10-18 14:36 — 3alacarta 0.0.10 serves subtitles through the subtitles resource (deployed, AIOStreams not yet updated)

- Addon commit `8ff352a` (3alacarta-stremio-addon), deployed to beamup; the live manifest reports `version: 0.0.10`:
  - The manifest adds `{ name: 'subtitles', types: ['movie','series'], idPrefixes: ['tt'] }`.
  - `defineSubtitlesHandler` returns the first stream's 3Cat subtitles.
  - Subtitle `lang` is now `cat` (ISO 639-2) instead of `ca`.
- Verified locally:
  - `/subtitles/series/tt4580372:2:3.json` (Merlí) and `/subtitles/movie/tt11930126.json` (Alcarràs) each return one `statics.3cat.cat/.../*.vtt` with `lang: cat`.
  - A non-3Cat title returns `[]`.
- Pending: the AIOStreams config change. The live PUT was blocked twice by a 1Password approval timeout. `build.jq` is ready and does two things:
  - bumps the preset to `manifest.json?v=0.0.10`;
  - replaces the formatter name so 3alacarta streams show `🇦🇩 3Cat ▶ <res>`, with the O/C/S flags and ⚡/⏳ shown only for streams that have a service (⏳ only on `service.cached` false).

### 2026-10-18 16:36 — AIOStreams on 3alacarta 0.0.10: 3Cat label and subtitles verified live

- The config was PUT from `build.jq` and the readback diff is empty. Exactly two fields changed:
  - the preset `manifest.json?v=0.0.10`;
  - the formatter name (3alacarta → `🇦🇩 3Cat ▶`; flags and ⚡/⏳ only when a service exists; ⏳ only on `service.cached` false).
- Live e2e:
  - Merlí 2×3, Alcarràs and Dragon Ball 2×1 each show `🇦🇩 3Cat ▶ 1080p` as row 2 under the cached TorBox row 1.
  - AIOStreams `/subtitles/…` returns the 3Cat `lang: cat` VTT for all three.
  - Breaking Bad 1×1 returns only TB rows and no subtitles (no 3Cat match, as expected).
- STREMIO-AIOSTREAMS.md (3alacarta section) now documents the label, the direct-not-P2P typing, single Catalan audio and the subtitles resource.

### 2026-10-18 16:45 — Catalan originals: row 1 is a cached ≥1080p O/C torrent, else 3Cat; 3Cat label ⚡

- Superseded 2026-10-18 17:19: the following special-case interpretation was rejected by the user; see the next entry. Originally interpreted as: for Catalan-original titles 3Cat wins unless a cached 4K/1080p Catalan release exists. 3Cat is instant, so it carries ⚡.
- Row-1 rule, prepended to the existing chain:
  - if `originalLanguage == 'Catalan'` (the TMDB `original_language` constant in the expression engine), pin the first cached 2160p/1080p stream from merge(O, C);
  - else pin 3Cat;
  - otherwise the unchanged O → C → S → any → 3Cat chain.
- Formatter: `🇦🇩 3Cat ▶` → `🇦🇩 3Cat ⚡`.
- PUT and readback OK. Live check on 16 TMDB `original_language=ca` titles plus 2 controls:
  - Merlí, Alcarràs and two other titles with cached 1080p: TB stays row 1 with 3Cat row 2.
  - Two Catalan originals with no cached ≥1080p torrent: 3Cat is row 1 at 1080p.
  - tt8517780: the cached 1080p 🇦🇩 TB beats 3Cat (merge O/C works).
  - tt4379450: 3Cat 576p is row 1 over an uncached 720p.
  - Dragon Ball (ja original): unchanged. Breaking Bad: unchanged.
- Measured trade-off: Merlí's row 1 is a 978 MB 1080p torrent over 3Cat 1080p, as the user's rule asks.

### 2026-10-18 17:19 — 3Cat competes normally; stream size reporting verified

- **Decision / implemented:** user clarified no special treatment for 3Cat. Removed the Catalan-original row-1 override, O/C/S exclusions and separate 3Cat row. Normal one-per-resolution/language selectors now include every provider. Row 1 keeps O → C → S → anything priority among instant streams, defined by excluding explicit uncached streams and P2P. The ⚡ label remains correct for direct playback.
- **Implemented:** addon 0.0.13 reports `behaviorHints.videoSize`: exact MP4 bytes from successful video HEAD; estimated HLS bytes from highest variant average bandwidth × duration / 8 (peak bandwidth fallback). Changes shipped in addon commits 2fbfaee, f691e52 and d13758b. Geo-blocked Spanish responses return 403 with a misleading 72-byte text body; those are rejected, and measurement retries the same path on `-int` hosts. Some lower-resolution files return 404 internationally, so size remains unknown. Playback URLs are unchanged.
- **Verification:** local Merlí 2×3 reports 1.53/1.54/0.99 GB for HLS/720p/480p; tt4379450 reports 0.39/0.38 GB. Live beamup AIOStreams preset now uses `?v=0.0.13`; PUT succeeded and readback diff is empty. Live Merlí row 1 = 3Cat 1080p 1.53 GB; Alcarràs row 1 = TB 1080p 17.17 GB; Dragon Ball row 1 = TB 1080p 2.42 GB with 3Cat 720p below; tt4379450 = 3Cat 576p 387.25 MB pinned above uncached 720p. Breaking Bad unchanged.
- **Limits / complete:** some live lower-resolution 3Cat rows lack size because beamup cannot measure them, correctly left blank. HLS totals are estimates, not exact file lengths or proof of perceptual quality. Normal slot limiting may hide a 3Cat rendition when a torrent wins. No device-level visual playback test performed. Operator documentation reconciled; no further ranking change pending.

### 2026-10-18 17:27 — Gènesi missing sizes traced to media-host access, not AIOStreams

- **Diagnosed:** live addon `/stream/series/tt38483587:1:1.json?v=0.0.13` already lacks `behaviorHints.videoSize` for both streams; AIOStreams correctly renders no size. No config or parser change can recover absent upstream measurements.
- **Evidence:** from Spain the 720p MP4 HEAD returns 200 and 1,469,815,196 bytes; HLS master returns 200, highest average bandwidth 4,133,429 bit/s, duration 2,808 s (~1,450,834,629 bytes estimated). The same HLS path on `adaptive-int` returns 404, and MP4 on `mp4-down-high-int` returns 403. Thus the international measurement fallback does not cover this title, unlike titles where size is shown.
- **Correction:** this Gènesi HLS master contains Català plus Audiodescripció audio renditions, contradicting the earlier universal single-track claim. The addon filters standalone audio-description variants, but HLS itself can contain both tracks. No playback URL changed.
- **Outcome:** investigation complete; sizes remain honestly unknown from beamup. General live coverage would require Spain-based measurement (or an official metadata size/bitrate source); no new infrastructure or hard-coded per-title sizes added.
