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
