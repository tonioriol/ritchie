# AIOStreams deployment (Stremio addon aggregator)

## Restoring the Stremio addon collection

Backups of the pre-migration collection live in 1Password (vault `neumann`) as
documents, so recovery does not depend on any local file:

| Document | Contents |
|---|---|
| `stremio-addons-full-backup` | complete pre-migration collection (29 addons, credentials included) |
| `stremio-removed-debrid-addons` | just the 5 removed debrid addons, full fidelity |

```bash
./restore-stremio-addons.sh removed   # re-add the 5 removed debrid addons
./restore-stremio-addons.sh full      # restore the entire pre-migration collection
```

The script logs in via the `Stremio` 1Password item, merges without creating
duplicates, and verifies the result. Note that `full` will fail with
`Max descriptor size reached` because the original collection contains the
oversized AIOMetadata/Cyberflix descriptors — see the per-addon limit section.

## Stream result tuning

A minimal config (no `deduplicator`, no `resultLimits`) returned **4049 streams**
for one movie — 1194 unique files, each listed up to 24 times, because every
scraper × service × cache-state combination is a separate stream.

Applied:

```jsonc
"deduplicator": {
  "enabled": true,
  "keys": ["infoHash", "filename", "smartDetect"],
  "cached": "per_service",     // keep the best cached copy from TorBox AND Real-Debrid
  "uncached": "single_result",
  "p2p": "single_result"
},
"resultLimits": { "global": 40, "service": 25, "addon": 8, "resolution": 5 },
"preferredResolutions": ["2160p","1080p","1440p","720p","576p","480p","Unknown"],
"preferredQualities":   ["BluRay REMUX","BluRay","WEB-DL","Unknown"],
"excludedResolutions":  ["480p","360p","240p","144p"],
"sortCriteria": { "global": [
  {"key":"cached","direction":"desc"}, {"key":"quality","direction":"desc"},
  {"key":"resolution","direction":"desc"}, {"key":"size","direction":"desc"}
]},
"size": {
  "global":     { "movies": [0,32212254720], "series": [0,10737418240] },
  "resolution": { "2160p": { "movies":[0,32212254720], "series":[0,10737418240] },
                  "1080p": { "movies":[0,21474836480], "series":[0,5368709120] },
                  "720p":  { "movies":[0,10737418240], "series":[0,3221225472] } }
}
```

Result: **4049 → 11 streams** for a movie, 1564 → 19 for an episode, with both
services still represented and all four scrapers able to appear.

Notes learned while tuning:

- `size` ranges are **tuples** `[min,max]`, not `{min,max}` objects — the object
  form fails with `expected tuple, received object`.
- Dedup modes: `single_result` / `per_service` / `per_addon`. Detection keys:
  `filename` / `infoHash` / `smartDetect`.
- Limit groups: `global`, `service`, `addon`, `resolution`, `quality`, `indexer`,
  `releaseGroup`, `streamType`. They apply *after* sorting.
- Sort keys available in v2.31.1: `addon`, `age`, `audioTag`, `bitrate`, `cached`,
  `encode`, `language`, `library`, `quality`, `regexPatterns`, `resolution`,
  `seeders`, `service`, `size`, `streamType`, `visualTag`.
- `size` before `quality` in the sort order surfaced 300 GB remuxes first; the
  per-resolution size caps plus `quality` ahead of `size` fixed the ordering.
- An `addon` limit that is too low lets one prolific scraper (Comet) crowd the
  others out — 8 leaves room for all four.

A credential-free copy of the working config is in 1Password as document
`aiostreams-config-template`.

### Sorting by resolution/quality needs the `preferred*` lists

`sortCriteria` keys `resolution`, `quality`, `visualTag`, `audioTag`, `language`,
`encode`, `streamType` and `releaseGroup` rank by **index into the matching
`preferred*` array**. Without it the comparator returns `0` and the key is a
silent no-op:

```js
case 'quality': { if (!userData.preferredQualities) { return 0; } ... }
```

So `sortCriteria` alone did nothing — resolutions came back interleaved. Setting
`preferredResolutions` and `preferredQualities` made the ordering take effect.

Valid values in v2.31.1 — resolutions: `2160p`, `1440p`, `1080p`, `720p`, `576p`,
`480p`, `360p`, `240p`, `144p`, `Unknown`; qualities: `BluRay REMUX`, `BluRay`,
`WEB-DL`, `WEBRip`, `HDRip`, `DVDRip`, `Unknown`.

Also set a size *floor* — several results reported 0 bytes and sorted above real
files. `excludedResolutions` removes the 480p-and-below junk.

### How providers and addons are picked per result

Two orderings drive it, both taken from the config arrays:

- **Service order** (`services[]`) — TorBox, then Real-Debrid. Used as the dedup
  priority and by the `service` sort key.
- **Addon order** (`presets[]`) — Comet, MediaFusion, Torz, Torrentio. Used as
  the dedup tiebreaker within a service.

With `deduplicator.cached: "per_service"`, each unique file keeps its best copy
**per service** — so one TorBox row and one Real-Debrid row can both survive, and
the addon order decides which scraper's copy represents each. That is why the
same file appears twice as `(Instant TB)` and `(Instant RD)`.

`resultLimits` has no `mode` set, so limits are **disjunctive**: `global`,
`service`, `addon` and `resolution` are independent counters applied after
sorting, not per-block quotas. Setting `mode: "conjunctive"` instead builds a
composite key per combination and caps each at `min(enabled limits)` — that is
the option to use for true "N per resolution *per* service" blocks.

## Goal

Consolidate the Stremio debrid setup behind a single self-hosted addon so the
TorBox and Real-Debrid API keys live in exactly one place instead of being
embedded in individual addon manifest URLs.

Before: the only debrid scraper installed in Stremio was a Torrentio URL with
both keys inline (`torrentio.strem.fun/…|realdebrid=…|torbox=…/manifest.json`).
Torrentio uses the *first* configured service, so Real-Debrid always won and the
TorBox subscription was unused. Changing services meant reinstalling the addon.

After: one AIOStreams addon wraps Comet, MediaFusion and StremThru Torz. Keys are
stored server-side; swapping or rotating a service is an API call, not a
reinstall.

## What was deployed

| Piece | Location |
|---|---|
| Helm chart | [`charts/aiostreams`](../../../charts/aiostreams/Chart.yaml:1) |
| ArgoCD Application | [`apps/aiostreams.yaml`](../../../apps/aiostreams.yaml:1) |
| Tunnel route | [`charts/cloudflared/values.yaml`](../../../charts/cloudflared/values.yaml:32) |
| Public URL | `https://aiostreams.tonioriol.com` |
| Namespace | `media` (Deployment, Service, 10Gi PVC, ExternalSecret) |
| Image | `ghcr.io/viren070/aiostreams:v2.31.1` (public, pinned tag) |

## Secrets

1Password item `neumann/aiostreams`, pulled by ESO into `aiostreams-secrets`:

| 1P field | Secret key | Purpose |
|---|---|---|
| `secret_key` | `SECRET_KEY` | Encrypts stored configs. **Never change** — rotating it makes every saved config undecryptable. |
| `torbox_api_key` | `TORBOX_API_KEY` | TorBox credential |
| `realdebrid_api_key` | `REALDEBRID_API_KEY` | Real-Debrid credential |
| `config_uuid` / `config_password` | — | Login for `/stremio/configure` |

Stakater Reloader rolls the pod when `aiostreams-secrets` changes.

## Findings worth keeping

These cost time to discover and are not in the upstream docs.

### `POST /api/v1/user` rejects an empty config

The docs show `{"config": {}}`, but the schema requires three keys minimum:

```json
{ "presets": [], "sortCriteria": { "global": [] }, "formatter": { "id": "torbox" } }
```

`formatter.id` is an enum: `gdrive`, `prism`, `tamtaro`, `lightgdrive`,
`minimalisticgdrive`, `torrentio`, `torbox`, `custom`.

### Every preset needs `useMultipleInstances`

Omitting it fails with `Option useMultipleInstances is required, got undefined`.

### `DEFAULT_SERVICE_CREDENTIALS` does not populate stored configs

Verified against v2.31.1: the env var only pre-fills the Services *form* on the
configure page. Configs created through the API must carry the keys in their own
`services[]` array. Service order sets dedup/sort priority — TorBox is first,
Real-Debrid second.

### Preset IDs are inconsistent, and there is no endpoint listing them

`stremthruTorz` is camelCase while its neighbours are kebab-case
(`torbox-search`, `anime-kitsu`). No `/api/v1/presets` route exists. The
authoritative list lives in the image:

```bash
CID=$(docker create ghcr.io/viren070/aiostreams:v2.31.1)
docker cp "$CID:/app/packages/core/dist/presets" /tmp/aio-presets
grep -ohE "ID = ['\"][^'\"]+['\"]" /tmp/aio-presets/*.js | sed -E "s/.*['\"]([^'\"]+)['\"]/\1/" | sort -u
```

The image is distroless — no `sh` utilities and `node` is not on `PATH`, so
inspect it locally with `docker cp` rather than `kubectl exec`.

### Torrentio 403s from this cluster — solved by wrapping

`torrentio.strem.fun` deliberately blocks datacenter IPs. A direct
`{"type":"torrentio"}` preset fails config validation with
`Failed to fetch manifest for Torrentio: 403`.

Evidence gathered (in this order):

| Test | Result |
|---|---|
| `wget`/`curl` from home, any User-Agent (incl. none) | 200 |
| Browser User-Agent **from the pod** | 403 → not a header/UA issue |
| Response shape | Cloudflare error page, **no `cf-mitigated` header** → WAF IP rule, not a solvable JS challenge |
| Cloudflare WARP sidecar (`caomingjun/warp`) | connects (`warp=on`), Torrentio still **403** |
| PureVPN via gluetun | TUN device works with `privileged` + `hostPath /dev/net/tun`, but `AUTH_FAILED` — the 1Password `PureVPN` password is not the OpenVPN password |
| `torrentio.elfhosted.com` mirror | also blocked |

Root cause: **IP reputation of the Hetzner range (`5.75.129.215`)**, enforced at
Cloudflare. Upstream confirms there is "no reliable workaround"; WARP and cheap
VPN exits are themselves already blocked.

**Working solution — instance wrapping.** Torrentio runs on a public AIOStreams
instance whose IP is not blocked, and our instance wraps it via the `aiostreams`
preset:

```jsonc
{ "type": "aiostreams", "instanceId": "wtio", "enabled": true,
  "options": { "name": "Torrentio",
               "manifestUrl": "https://aiostreams.fortheweak.cloud/stremio/<uuid>/<encpw>/manifest.json" } }
```

The wrapper config holds the same TorBox + Real-Debrid keys, so cache lookups
still resolve against our own accounts. Its UUID/password are stored in
1Password (`torrentio_wrapper_*` fields). Verified: 221 Torrentio streams for a
movie, 148 for a series, alongside Comet/Torz/MediaFusion.

Tradeoff: this depends on a third-party instance staying up, and our debrid keys
are held by it. If it disappears, swap `manifestUrl` for another public instance
from the AIOStreams docs — the rest of the config is unaffected.

If a VPN egress is ever wanted instead, gluetun needs working OpenVPN
credentials plus:

```
ADDON_PROXY=http://gluetun:8080
ADDON_PROXY_CONFIG=*:false,*.strem.fun:true
```

### Probe endpoint

`/api/v1/status` returns 200 and a version payload; `/health` is 404.

## Stremio's per-addon descriptor limit

Installing into the account initially failed with `Max descriptor size reached`
from `addonCollectionSet`. The limit is **per addon descriptor (~20 KB)**, not a
cap on the collection as a whole. Evidence:

| Payload | Largest addon | Result |
|---|---|---|
| Cinemeta + MediaFusion | 12.6 KB | OK |
| Cinemeta + AIOMetadata | 23.6 KB | rejected |
| Cinemeta + Cyberflix | 22.6 KB | rejected |
| 27 addons, 52.9 KB total, none oversized | — | OK |
| 22 addons, 48.5 KB total, one oversized | 23.6 KB | rejected |

A 27-addon / 52.9 KB collection succeeds while a 22-addon / 48.5 KB one fails,
so total size is not the constraint — the presence of a single oversized
descriptor is.

`AIOMetadata` (36 catalogs) and `Cyberflix Catalog` (60 catalogs) each exceed the
limit on their own. Trimming the `manifest.catalogs` array brings them under it:

| Addon | Catalogs | Size | Result |
|---|---|---|---|
| AIOMetadata | 20 | 16.6 KB | OK |
| AIOMetadata | 24 | 21.6 KB | rejected |
| Cyberflix | 12 | 5.5 KB | OK |

Size does not scale linearly with catalog count — a few catalogs carry large
`extra`/`genres` arrays. Selecting *which* catalogs to keep beats truncating the
array: filtering by id kept 26 AIOMetadata + 24 Cyberflix catalogs at 15.5 KB,
whereas a blind `[0:20]` truncation kept only 20 at 16.6 KB.

Applied selection:

- **AIOMetadata (36 → 26)** — kept all `*search*` catalogs,
  `tmdb.{top,trending,year,language}`, `tvdb.{trending,genres,collections}`,
  `mal.{airing,upcoming,schedule,seasons,top_anime,genres}`.
  Dropped: MAL decade lists, `mal.studios`, `mal.most_*`, `mal.top_{movies,series}`.
- **Cyberflix (60 → 24)** — kept `premieres.*`, `trending.*` and the Netflix,
  Disney+, HBO Max, Amazon Prime and Apple TV+ rows.
  Dropped: Hulu, Paramount+, Peacock and the remaining regional services.

Keep the `search` catalogs: dropping them removes search from Stremio's Discover
for those content types. A naive `catalogs[0:N]` truncation loses them because
they are ordered last.

Reinstalling either addon from its own configure page restores the full catalog
list and makes the collection unwritable again until trimmed.

Beware: padding a descriptor's `description` field to 28 KB *was* accepted, so
the threshold is not a naive byte count of the JSON. Test with real catalog data.

## Verification

- `helm lint` clean; `kubectl apply --dry-run=server` accepted all 4 resources
- Pod `1/1 Running`, ExternalSecret `SecretSynced`, all three keys correct length
- Movie `tt0133093`: 3828 streams — 2027 TorBox-backed, 1801 Real-Debrid
- Series `tt0903747:1:1`: 1416 streams; top result an `Instant TB` 2160p cached hit
- Tunnel update was additive — all 10 pre-existing hostnames verified unchanged

`tv.tonioriol.com` (iptv-relay) returns 502, including in-cluster. Pre-existing
and unrelated to this work.

## Rollback

```bash
git revert <commit> && git push          # ArgoCD prunes the resources
```

The PVC uses `deletionPolicy: Retain` on the ExternalSecret, so the k8s Secret
survives. Also remove `aiostreams.tonioriol.com` from the Cloudflare *remote*
tunnel config, which overrides the local ConfigMap.
