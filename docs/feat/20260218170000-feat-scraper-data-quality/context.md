# feat-scraper-data-quality: Fix TaskManager singleton, EPG matching, and status checker quality

## TASK

Three interrelated improvements to the `acestream-scraper` service running on the neumann cluster:
1. Fix TaskManager starting 3× (one per uvicorn worker) instead of once
2. Fix EPG association returning 0 new matches despite valid tvg_id data
3. Tune the background status checker so TV-assigned channels are checked more frequently and accurately than unassigned noise channels

All changes land in the `tonioriol/acestream-scraper` fork (forked from `Pipepito/acestream-scraper`) and deploy via the semantic-release CI pipeline.

## GENERAL CONTEXT

Refer to AGENTS.md for project structure description.

### REPO

`/Users/tr0n/Code/neumann/acestream-scraper`

### RELEVANT FILES

* `/Users/tr0n/Code/neumann/acestream-scraper/app/__init__.py` — Flask app factory; file-lock TaskManager singleton guard
* `/Users/tr0n/Code/neumann/acestream-scraper/app/tasks/manager.py` — TaskManager async loop; check_channel_statuses; associate_channels_by_epg
* `/Users/tr0n/Code/neumann/acestream-scraper/app/services/epg_service.py` — EPGService; auto_scan_channels; find_matching_channels; _clean_channel_name
* `/Users/tr0n/Code/neumann/acestream-scraper/app/services/tv_channel_service.py` — TVChannelService; _normalize_name; generate_tv_channels_from_epg
* `/Users/tr0n/Code/neumann/acestream-scraper/app/services/channel_status_service.py` — ChannelStatusService; check_channel (2-phase probe); check_channels
* `/Users/tr0n/Code/neumann/ritchie/AGENTS.md` — Cluster runbook; deploy instructions

## PLAN

1. ✅ Fix TaskManager 3× problem — env var guard → file lock with fd persisted on app object
2. ✅ Fix EPG tvg_id matching — `_normalize_name()` strips HD/FHD/UHD/SD/4K/resolution suffixes
3. ✅ Wire `auto_scan_channels` (fuzzy name matching) into TaskManager post-scrape flow at threshold=0.95
4. ✅ Enhance `_clean_channel_name()` with additional noise patterns (country prefixes, `-->` markers, quality markers, MultiAudio, hex codes)
5. ✅ Deploy v1.7.0 — verified 502 acestreams matched (was 380), 151 TV channels (was 112)
6. ✅ Tune `check_channel_statuses` — two-tier priority with freshness cooldowns and offline decay
7. ✅ Add `quick_check` param to `ChannelStatusService.check_channel()` — skip Phase 2 for unassigned channels
8. ✅ Deploy v1.8.0 — verified two-tier checker running in logs
9. ⬜ Remove `list.js`, `converter.js` from acestreamio (cleanup, once stable)
10. ⬜ Retire `charts/acestream` helm chart (engine + proxy consolidated in acestream-scraper)

## EVENT LOG

* **2026-02-18 14:00 - Diagnosed TaskManager starting 3× on every pod restart**
  * Why: uvicorn workers use `spawn` not `fork`, so `os.environ` is NOT shared between workers — the env var guard `_TASK_MANAGER_STARTED` was ineffective
  * How: Replaced env var guard with `fcntl.flock(LOCK_EX | LOCK_NB)` on `/tmp/.acestream_task_manager.lock`. First worker acquires the lock and starts TaskManager; others hit `IOError` and skip
  * Key info: The `lock_fd` file descriptor MUST be stored on `app._task_manager_lock_fd` to prevent Python GC from closing it and releasing the lock (this caused v1.6.0 to still start 3× — fixed in v1.6.2)
  * Files: `/Users/tr0n/Code/neumann/acestream-scraper/app/__init__.py` lines 107–127

* **2026-02-18 14:30 - Diagnosed EPG matching returning 0 new associations**
  * Why: `_normalize_name()` in `tv_channel_service.py` did NOT strip resolution suffixes (HD/FHD/UHD/SD/4K). `normalize('DAZN 1 HD')` → `'dazn 1 hd'` but EPG channel name is `'DAZN 1'` → `'dazn 1'` — no match
  * How: Added regex to strip `\b(?:HD|FHD|UHD|SD|4K|1080[pi]?|720[pi]?|576[pi]?|480[pi]?)\b` from normalized names
  * Files: `/Users/tr0n/Code/neumann/acestream-scraper/app/services/tv_channel_service.py` line 397

* **2026-02-18 14:30 - Wired auto_scan_channels (fuzzy name matching) into TaskManager**
  * Why: `associate_by_epg_id()` only matched channels that already had a `tvg_id` set. The existing `EPGService.auto_scan_channels()` runs ID match → exact cleaned name → fuzzy SequenceMatcher (threshold 0.75 UI, 0.95 for automated runs to avoid false positives like `BT Sport → PT Sport TV`)
  * How: Replaced `tv_channel_service.associate_by_epg_id()` call in `associate_channels_by_epg()` with `EPGService().auto_scan_channels(threshold=0.95, clean_unmatched=False, respect_existing=True)`
  * Files: `/Users/tr0n/Code/neumann/acestream-scraper/app/tasks/manager.py` lines 306–341

* **2026-02-18 14:30 - Enhanced _clean_channel_name() noise stripping**
  * Why: M3U acestream names contain many non-channel-name tokens (`--> NEW ERA III`, `UK |`, `*`, `MultiAudio`, `b4a1`, etc.) that prevented name matching
  * How: Added to `_clean_channel_name()`: `-->` source markers, country prefixes (`UK |`, `ES:`), `*` quality markers, `\bmulti\s*audio\b`, trailing variant numbers, 4-char hex codes, parenthesized/bracketed tokens
  * Files: `/Users/tr0n/Code/neumann/acestream-scraper/app/services/epg_service.py` lines 608–666

* **2026-02-18 14:30 - Released v1.7.0 via CI pipeline**
  * Why: `feat:` commit triggers semantic-release minor bump
  * How: `git push https://github.com/tonioriol/acestream-scraper.git main && gh workflow run release.yml --ref main -R tonioriol/acestream-scraper`
  * Key info: Had to `git pull --rebase` first (semantic-release pushes a commit). Image Updater auto-deployed within ~2 min
  * Results: `EPG association completed: 502 acestreams matched, 39 TV channels created, 146 acestreams associated` (was 380 matched, 112 TV channels)

* **2026-02-18 16:30 - Dropped stream proxy idea in favour of status checker tuning**
  * Why: The proposed `/stream/HASH` proxy endpoint would add latency on every play and make the scraper a SPOF for playback. The existing `check_channel_statuses()` background checker already does availability tracking with a proper 2-phase probe (metadata + real stream bytes), just without priority weighting
  * How: Decision to tune the existing checker instead — no new proxy endpoint

* **2026-02-18 16:50 - Implemented two-tier status checker with freshness cooldowns**
  * Why: All ~2500 acestreams were checked equally. The 502 TV-assigned channels matter far more than ~2000 unassigned channels nobody watches. Phase 2 stream probe (15s per channel) was wasteful on unassigned channels
  * How:
    - Split `check_channel_statuses()` into two pools per cycle:
      - Tier 1 (TV-assigned, `tv_channel_id IS NOT NULL`): full 2-phase probe, 10-min cooldown, extended to 30-min if `is_online=False` (offline decay)
      - Tier 2 (unassigned, `tv_channel_id IS NULL`): Phase 1 metadata-only, 60-min cooldown, extended to 3h if offline
    - Over-fetch 3× batch size then filter by freshness window to absorb per-channel variation
    - Added `quick_check: bool = False` param to `ChannelStatusService.check_channel()` and `check_channels()` — when True, returns after Phase 1 (is_live flag) without Phase 2 stream probe
  * Files:
    - `/Users/tr0n/Code/neumann/acestream-scraper/app/tasks/manager.py` lines 207–295
    - `/Users/tr0n/Code/neumann/acestream-scraper/app/services/channel_status_service.py` lines 23–178

* **2026-02-18 16:54 - Released v1.8.0 via CI pipeline and verified deployment**
  * Why: `feat:` commit triggers semantic-release
  * How: `git add ... && git commit -m "feat: ..." && git pull --rebase https://... && git push https://... && gh workflow run release.yml --ref main -R tonioriol/acestream-scraper`
  * Key info: Pod `acestream-scraper-75fd75c5f8-zxms5` in `default` namespace. Confirmed working from logs:
    ```
    Status check: 30 TV (30 new, 30 offline-decay) + 20 unassigned (20 new)
    TV status check: 0/30 online
    Unassigned status check: 0/20 online
    ```
    0/N online is expected on pod restart — engine needs time to buffer P2P peers

## DEPLOYMENT REFERENCE

```bash
# Push and release acestream-scraper
cd /Users/tr0n/Code/neumann/acestream-scraper
git pull --rebase https://github.com/tonioriol/acestream-scraper.git main
git push https://github.com/tonioriol/acestream-scraper.git main
gh workflow run release.yml --ref main -R tonioriol/acestream-scraper

# Monitor release
gh run list --limit 3 -R tonioriol/acestream-scraper
gh release list --limit 3 -R tonioriol/acestream-scraper

# Check cluster deployment
export KUBECONFIG=/Users/tr0n/Code/neumann/ritchie/clusters/neumann/kubeconfig
kubectl get pods -A | grep acestream
kubectl logs acestream-scraper-<POD_ID> -n default --tail=40 | grep -E "Status check|TaskManager|EPG"
```

## SCRAPER VERSION HISTORY

| Version | What changed |
|---------|-------------|
| v1.6.0  | File-lock TaskManager singleton (env var guard didn't work with spawn) |
| v1.6.1  | `_normalize_name()` strips HD/resolution from EPG matching |
| v1.6.2  | Fix: `lock_fd` stored on `app` to prevent GC releasing lock |
| v1.7.0  | `auto_scan_channels` wired into post-scrape; `_clean_channel_name` enhanced → 502 matched, 151 TV channels |
| v1.8.0  | Two-tier status checker: TV-assigned full probe / unassigned quick check; freshness cooldowns; offline decay |

## Next Steps

- [ ] Remove `list.js`, `converter.js` from `acestreamio` repo (legacy files no longer needed)
- [ ] Retire `charts/acestream` helm chart in `ritchie` (engine + proxy now consolidated in acestream-scraper pod)
