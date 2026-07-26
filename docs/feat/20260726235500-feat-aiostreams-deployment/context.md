# AIOStreams deployment (Stremio addon aggregator)

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

### Torrentio 403s from this cluster

`torrentio.strem.fun` blocks Hetzner IP ranges: 403 from the pod, 200 from a
home connection. This is upstream behaviour, not a config error, and it makes
`{"type":"torrentio"}` presets fail config validation with
`Failed to fetch manifest for Torrentio`.

Workaround if Torrentio is ever needed (per upstream deployment docs): route
`*.strem.fun` through a gluetun VPN sidecar.

```
ADDON_PROXY=http://gluetun:8080
ADDON_PROXY_CONFIG=*:false,*.strem.fun:true
```

Comet, MediaFusion and StremThru Torz cover the same trackers and are unaffected.

### Probe endpoint

`/api/v1/status` returns 200 and a version payload; `/health` is 404.

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
