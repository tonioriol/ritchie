---
title: "AIOStreams max/mid/min tiers with untagged fallback after Real-Debrid expiry"
status: active
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
- Commit: this entry.
