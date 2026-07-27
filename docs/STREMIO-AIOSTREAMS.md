# Stremio + AIOStreams — operator notes

Everything needed to work on this setup, and the misconceptions that cost time the
first go round. Read the "Non-obvious" section before changing anything.

Deployment specifics (Helm chart, ArgoCD, tunnel, secrets) live in
[`docs/feat/20260726235500-feat-aiostreams-deployment/context.md`](docs/feat/20260726235500-feat-aiostreams-deployment/context.md:1).

---

## The shape of the system

```
Stremio client
  └── ONE addon: AIOStreams  (https://aiostreams.tonioriol.com)
        ├── scrapers:  Comet · MediaFusion · Torrentio (wrapped)
        └── debrid:    TorBox (1st) · Real-Debrid (2nd)
```

AIOStreams is an aggregator. Debrid credentials are stored **once** in it and
auto-applied to every compatible scraper, so a key rotation is one API call
instead of reinstalling N addons.

| Piece | Where |
|---|---|
| Instance | `https://aiostreams.tonioriol.com` (namespace `media`, image `ghcr.io/viren070/aiostreams`) |
| Chart / App | [`charts/aiostreams`](charts/aiostreams/Chart.yaml:1) · [`apps/aiostreams.yaml`](apps/aiostreams.yaml:1) |
| Config page | `https://aiostreams.tonioriol.com/stremio/configure` (login with UUID + password) |
| Secrets | 1Password `neumann/aiostreams` |

### 1Password contents (vault `neumann`)

| Field / document | Purpose |
|---|---|
| `secret_key` | encrypts stored configs — **never rotate**, it orphans every config |
| `torbox_api_key`, `realdebrid_api_key` | debrid credentials |
| `tmdb_api_key` | enables title matching |
| `config_uuid`, `config_password` | login for the config page and the API |
| `torrentio_wrapper_*` | the wrapped-Torrentio instance credentials |
| doc `aiostreams-config-template` | credential-free copy of the working config shape and expressions |
| doc `stremio-addons-full-backup` | pre-migration Stremio collection (29 addons) |
| doc `stremio-addons-current` | post-migration collection |
| doc `stremio-removed-debrid-addons` | the 5 removed debrid addons, restorable |

The credential-free AIOStreams template restores config shape and expressions;
live TorBox and Real-Debrid credentials remain in `neumann/aiostreams` and are
still required for a complete service restore.

---

## Editing the config

The configure page works, but everything here was done over the API — it is
scriptable and diffable. Read–modify–write, **always send the whole object**
(`PUT` replaces; there is no partial update).

```bash
export OP_ACCOUNT=PRBEZ6ELGNCMDIK6YVMRW5TTXQ
B=https://aiostreams.tonioriol.com
U=$(op read "op://neumann/aiostreams/config_uuid" --account $OP_ACCOUNT)
P=$(op read "op://neumann/aiostreams/config_password" --account $OP_ACCOUNT)
AUTH="Authorization: Basic $(printf '%s' "$U:$P" | base64)"

curl -s "$B/api/v1/user?raw=true" -H "$AUTH" | jq '.data.userData' > cfg.json
jq '.resultLimits.resolution = 4' cfg.json > new.json          # edit
jq -n --slurpfile c new.json '{config:$c[0]}' > put.json
curl -s -X PUT "$B/api/v1/user" -H "$AUTH" \
     -H 'Content-Type: application/json' -d @put.json | jq -r '.detail // .error.message'
```

Changes take effect immediately — no reinstall in Stremio unless the *manifest*
changes (catalogs added/reordered, or a new resource type such as subtitles).

Stream endpoint for testing (note `encryptedPassword`, not the raw one):

```
$B/stremio/<uuid>/<encryptedPassword>/stream/movie/tt0133093.json
$B/stremio/<uuid>/<encryptedPassword>/stream/series/tt0903747:1:1.json
```

### Representative movie sizes

Movie blocks use 12 ordered `requiredStreamExpressions` to select up to four
distinct files per debrid provider and resolution:

| Resolution | Choices |
|---|---|
| 2160p | largest cached-first result, then ≤20 GB, ≤10 GB, ≤5 GB |
| 1080p | largest cached-first result, then ≤10 GB, ≤5 GB, ≤2 GB |
| 720p | largest cached-first result, then ≤2 GB, ≤1 GB, ≤500 MB |

Expressions are evaluated after sorting. Earlier selections are removed before
the next expression, so overlapping ceilings yield distinct rows. Missing
tiers are omitted rather than duplicated. The unconstrained selectors preserve a
fallback when surviving candidates lack useful size metadata; the capped
selectors retain the `1MB` lower bound because they promise meaningful ceilings.
`queryType != 'movie'` returns all streams, leaving series and anime unchanged.
The existing 4-per-resolution, per-service conjunctive limit remains the final
safety cap.

Verified 2026-07-27: the strengthened three-movie audit reported no `FAIL`
across six post-change samples, all three repeated movie pairs matched exactly,
`breakingbad` and `attackontitan` normalized output stayed unchanged, all-endpoint
latency moved from median 3.002 s to 3.150 s below the 3.752 s rejection
threshold, and movie-only latency moved from median 3.456 s to 3.337 s below the
4.320 s rejection threshold.

---

## Managing the Stremio addon collection

There is no supported API. The unofficial one at `api.strem.io` is what the
official web client uses:

```bash
# login -> authKey
jq -n --arg e "$EMAIL" --arg p "$PASS" '{type:"Auth",type_:"Login",email:$e,password:$p}' |
  curl -s -X POST https://api.strem.io/api/login -H 'Content-Type: application/json' -d @- |
  jq -r '.result.authKey'

# read / write the whole collection
POST /api/addonCollectionGet  {type:"AddonCollectionGet", authKey, update:true}
POST /api/addonCollectionSet  {type:"AddonCollectionSet", authKey, addons:[...]}
```

`AddonCollectionSet` **replaces the entire array** — always `Get` first, modify,
then `Set`. Preserve each entry's `transportUrl`, `transportName`, `manifest` and
`flags` verbatim.

Restore helper (dry-run tested):
[`restore-stremio-addons.sh`](docs/feat/20260726235500-feat-aiostreams-deployment/restore-stremio-addons.sh:1)

```bash
./restore-stremio-addons.sh removed   # re-add the 5 removed debrid addons
./restore-stremio-addons.sh full      # restore the whole pre-migration collection
```

Credentials are in 1Password `Shared/Stremio` (`tonioriol+stremio@gmail.com`).
There is a second Stremio account (`Private/Stremio jj oriol`) — not this one.

---

## Non-obvious things (read this)

Each of these cost real time. They are all verified against the running v2.31.1
image, not inferred from docs.

### Stremio has a ~20 KB **per-addon** descriptor limit

`addonCollectionSet` fails with `Max descriptor size reached` when **one single
addon** is too large. It is not a limit on the collection.

Proof: a 27-addon / 52.9 KB collection saves fine, while a 22-addon / 48.5 KB one
containing a 23.6 KB addon fails. `Cinemeta + AIOMetadata` — just two addons —
fails.

Culprits are catalog-heavy addons: AIOMetadata (36 catalogs, 23.6 KB) and
Cyberflix (60, 22.6 KB). Both are installed with **trimmed** `manifest.catalogs`.
**Reconfiguring either from its own configure page restores the full list and
makes the whole collection unwritable again.**

When trimming, select catalogs by id — do not truncate the array. `search`
catalogs are ordered last, so `catalogs[0:20]` silently deletes search from
Stremio's Discover.

Also: padding a descriptor's `description` to 28 KB *was* accepted, so the
threshold is not a naive byte count. Test with real catalog data.

### `sortCriteria` is a no-op without the matching `preferred*` list

```js
case 'quality': { if (!userData.preferredQualities) { return 0; } ... }
```

`resolution`, `quality`, `visualTag`, `audioTag`, `language`, `encode`,
`streamType` and `releaseGroup` all rank by **index into the corresponding
`preferred*` array**. Set the sort key alone and nothing happens — silently.
Same mechanism for `service` (indexes `services[]`), which is how TorBox is
grouped ahead of Real-Debrid.

### `quality` is a filename tag, not a measure of quality

`BluRay REMUX` / `BluRay` / `WEB-DL` / `WEBRip` / `HDRip` / `DVDRip`, matched by
regex on the filename. **No relation to bitrate or size anywhere in the code.**

So an 8 GB 2160p "BluRay" re-encode outranks a 26 GB WEB-DL if `quality` sits
above `size`. At a fixed resolution, size is the honest proxy for bitrate —
hence `size` before `quality`, with `quality` as a tiebreaker only.

HDR / Dolby Vision / Atmos are **separate fields** (`visualTags`, `audioTags`)
and unaffected by that ranking.

### Result limits: disjunctive vs conjunctive

Default (no `mode`) is **disjunctive** — each category is an independent counter,
so `resolution: 4` means 4 *total* across all services.

For "N per resolution **per** provider" set `mode: "conjunctive"`. The limiter
builds a composite key from **only the categories that have a value**, capped at
`min(enabled limits)`. Leave `addon` and `quality` unset or they join the key and
multiply the blocks.

Limits apply **after** sorting, so they keep the top of each group.

### `titleMatching.mode` must be `exact`

`"contains"` barely helps — "The Matrix Revolutions" contains "The Matrix", so
mismatches only fell 4 → 3. With `exact` they went to 0. `exact` is the only
value in the v2.31.1 enum.

It needs a TMDB credential. Ours is a **v3 API key** (`tmdbApiKey`, used as
`?api_key=`), not a v4 bearer token — a v4 token goes in `tmdbAccessToken` and
the two are not interchangeable. Sibling franchises still leak occasionally
(a Walking Dead search can return *Fear the Walking Dead*).

### Torrentio blocks datacenter IPs — wrap it, don't fight it

`torrentio.strem.fun` returns **403 from any hosting IP** (ours: Hetzner
`5.75.129.215`), 200 from a home connection. It is a Cloudflare WAF IP rule, not
a solvable challenge: no `cf-mitigated` header, and a browser User-Agent from the
pod still 403s. Cloudflare WARP connects but its IPs are blocked too. The
`torrentio.elfhosted.com` mirror is blocked as well.

Working solution: Torrentio runs on a **public AIOStreams instance whose IP is
not blocked**, wrapped into ours via the `aiostreams` preset:

```jsonc
{ "type": "aiostreams", "instanceId": "wtio", "enabled": true,
  "options": { "name": "Torrentio",
               "manifestUrl": "https://aiostreams.fortheweak.cloud/stremio/<uuid>/<encpw>/manifest.json" } }
```

The wrapper holds the same debrid keys, so cache lookups still hit our accounts.
Its credentials are in 1Password (`torrentio_wrapper_*`). If that instance dies,
swap `manifestUrl` for another public one — nothing else changes.

### API and schema traps

- `POST /api/v1/user` with `{"config":{}}` is **rejected** despite the docs.
  Minimum viable: `presets`, `sortCriteria.global`, `formatter.id`.
- Every preset requires `useMultipleInstances`.
- `size` ranges are **tuples** `[min,max]`, not `{min,max}` objects.
- Preset ids are inconsistently cased: `stremthruTorz` (camelCase) next to
  `torbox-search`, `anime-kitsu` (kebab). There is **no endpoint listing them**.
- `DEFAULT_SERVICE_CREDENTIALS` only pre-fills the *configure form*. Configs
  created via the API must carry keys in their own `services[]`.
- Inside formatter `::join()` the separator must be quoted — `::join(' · ')`.
  Unquoted emits the template literally into the UI.
- `hideErrors: true` suppresses `[❌] <addon>: aborted due to timeout` rows that
  otherwise appear as fake streams.
- Health probe: `/api/v1/status`. `/health` is 404.

Getting the authoritative preset/enum list — the image is distroless, so no `sh`
utilities and `node` is not on `PATH`; inspect it locally:

```bash
CID=$(docker create ghcr.io/viren070/aiostreams:v2.31.1)
docker cp "$CID:/app/packages/core/dist" /tmp/aio-dist
docker rm -f "$CID"
grep -ohE "ID = ['\"][^'\"]+['\"]" /tmp/aio-dist/presets/*.js | sed -E "s/.*['\"]([^'\"]+)['\"]/\1/" | sort -u
```

### One slow addon sets the response time

Addons are queried in parallel and the response waits for the slowest. Default
preset timeouts are 15–20 s, which let StremThru Torz (7.5 s alone, vs ~1.8 s for
the others) dominate every request. Torz is **disabled** — it contributed 1–2
streams per title. Responses went 7–12 s → ~2 s.

Harmless noise on every request: `Trakt aliases 403`, and TVDB warnings (no TVDB
key set).

---

## Current configuration (live)

```jsonc
services:   [torbox, realdebrid]          // order = dedup priority + service sort
presets:    Comet, MediaFusion, Torrentio(wrapped)   // all timeout 8000; Torz disabled
resultLimits: { mode: "conjunctive", global: 60, resolution: 4, service: 4 }
requiredStreamExpressions: 12 movie-only representative-size selectors
sortCriteria.global: [service, cached, resolution, size, quality]
deduplicator: { enabled: true, keys: [infoHash, filename, smartDetect],
                cached: "per_service", uncached: "single_result", p2p: "single_result" }
titleMatching: { enabled: true, mode: "exact" }
preferredResolutions: [2160p, 1080p, 720p]
excludedResolutions:  [1440p, 576p, 480p, 360p, 240p, 144p, Unknown]
size: movies 0.5–30 GB, series 0.1–10 GB (plus per-resolution caps)
formatter: custom · hideErrors: true
```

`cached: "per_service"` is deliberate: the same file survives once per debrid
service, so there is a TorBox row *and* a Real-Debrid row as a fallback if one
link fails.

Renders as:

```
TB ⚡ 2160p · 27.41 GB
BluRay · HDR10+ DV · TrueHD
Land.of.Bad.2024.UHD.BluRay.2160p...
Comet
```

`⚡` cached (instant) · `⏳` uncached · `TB`/`RD` the debrid service.

Result: ~12–21 rows per title in ~1–3 s, 4 per resolution per provider.
Movie blocks now expose up to four representative sizes per resolution/provider
instead of four near-identical largest rows.

---

## TorBox vs Real-Debrid (measured 2026-07-27)

15 titles across recent/classic/vintage/foreign/animation/series, 9,795 streams,
limits and dedup temporarily disabled to see the full pool.

| | streams | cached | hit rate |
|---|---|---|---|
| TorBox | 5,175 | 1,773 | **34%** |
| Real-Debrid | 4,620 | 450 | **10%** |

TorBox won on **all 15 titles**. Cached 4K existed for 13/15 on both; titles
where only RD had a cached 4K: **0**. All 26 best-4K links played; throughput was
comparable (RD often faster).

Three RD links stalled ~21 s at HTTP 200 — those came from **MediaFusion's
proxy**, not Real-Debrid. Do not attribute it to RD.

Conclusion: Real-Debrid is not earning its place. Caveat: cache state is a
point-in-time snapshot skewed by which hashes our scrapers surface.

To re-run: disable `resultLimits`/`deduplicator`, fetch the stream endpoint for a
title list, then count `⚡` per `TB`/`RD` prefix. Restore the config afterwards.

---

## Rules of thumb

- Verify against the image or a live request. The docs are wrong about
  `config: {}`, and `titleMatching` modes are incompletely described.
- Back up before writing to the Stremio collection — `Set` is destructive.
- Never commit debrid keys, the TMDB key, or the config password. Strip
  `services[].credentials`, `tmdbApiKey`, `uuid` and preset `manifestUrl` from
  anything exported.
- Confirm a change with a real stream request, not just an HTTP 200 on the `PUT`.
