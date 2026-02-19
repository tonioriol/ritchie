# fix-ace-neumann Fix ace.tonioriol.com on neumann

## TASK

Move `ace.tonioriol.com` from the legacy `ritchie` server to the new AceStream deployment on the `neumann` k3s cluster, preserving the old reverse-proxy behavior (CORS, URL rewrites) and validating playback.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/docs/feat/2026-01-19-21-13-09-feat-k3-cluster-hetzner/context.md`
* `/Users/tr0n/Code/ritchie/docs/feat/2026-01-21-00-13-56-feat-install-metrics/context.md`
* `/Users/tr0n/Code/ritchie/charts/acestream/values.yaml`
* `/Users/tr0n/Code/ritchie/charts/acestream/templates/deployment.yaml`
* `/Users/tr0n/Code/ritchie/charts/acestream/templates/ingress.yaml`
* `/Users/tr0n/Code/ritchie/charts/acestream/templates/proxy-configmap.yaml`
* `/Users/tr0n/Code/ritchie/charts/acestream/templates/proxy-deployment.yaml`
* `/Users/tr0n/Code/ritchie/charts/acestream/templates/proxy-service.yaml`

## PLAN

- Ensure DNS `ace.tonioriol.com` points to neumann node IP.
- Ensure `acestream` app is exposed over HTTPS via Traefik Ingress.
- Keep nginx “compat” proxy in-cluster to mimic legacy ritchie nginx config.
- Verify playback with multiple AceStream IDs and monitor logs for timeouts/errors.
- (Optional) Add metrics-server to enable `kubectl top`.

## EVENT LOG

  * **2026-01-20 - DNS + routing cutover**
  * Updated `ace.tonioriol.com` DNS to point to neumann.
  * Added in-cluster nginx reverse proxy + Traefik Ingress for HTTPS endpoint.
  * Adjusted settings to match legacy behavior and validated playback (some IDs work; others appear dead/slow).

* **2026-01-20 - DNS cutover to neumann (DigitalOcean doctl)**
  * Located the `ace` record in `tonioriol.com`:
    * `doctl compute domain records list tonioriol.com --format ID,Type,Name,Data,TTL`
    * Found: record ID `1777925433` (`A ace -> 188.226.140.165`, TTL `30`).
  * Updated `ace` A record to the neumann node IP:
    * Command: `doctl compute domain records update tonioriol.com --record-id 1777925433 --record-data 5.75.129.215 --record-ttl 30`
    * Verified record updated.

* **2026-01-20 - Investigated playback failures after DNS change**
  * Symptom: `http://ace.tonioriol.com:30878/` returned `500` “couldn't find resource”.
  * Confirmed this is expected for the upstream image: the service does not serve a homepage; functional endpoints are under `/ace/*`.
  * Verified API endpoint works: `/webui/api/service?method=get_version`.
  * Noted timeouts when following redirects to per-stream playlists (`/ace/m/<stream>/<playlist>.m3u8`) for some IDs.

* **2026-01-20 - Compared legacy ritchie Nginx and replicated behavior on neumann**
  * Accessed legacy config via SSH (`forge@ritchie.tonioriol.com`):
    * `/etc/nginx/sites-available/ace.tonioriol.com`
  * Key legacy behaviors:
    * Force CORS headers and hide backend CORS
    * Long proxy timeouts for streaming
    * `sub_filter` and `proxy_redirect` rewriting backend URLs containing `:6878`
    * WebSocket upgrade headers
  * Implemented equivalent behavior on neumann using an in-cluster nginx reverse proxy + Traefik Ingress:
    * Added nginx proxy config:
      * `/Users/tr0n/Code/ritchie/charts/acestream/templates/proxy-configmap.yaml`
    * Added nginx proxy deployment/service:
      * `/Users/tr0n/Code/ritchie/charts/acestream/templates/proxy-deployment.yaml`
      * `/Users/tr0n/Code/ritchie/charts/acestream/templates/proxy-service.yaml`
    * Added public ingress:
      * `/Users/tr0n/Code/ritchie/charts/acestream/templates/ingress.yaml`

* **2026-01-20 - Fixed client probe/HEAD behavior**
  * Observed `501 Not Implemented` on `HEAD` requests against some endpoints.
  * Added nginx logic to convert `HEAD -> GET` when proxying (some clients probe with HEAD):
    * `map $request_method ...` + `proxy_method` in `/Users/tr0n/Code/ritchie/charts/acestream/templates/proxy-configmap.yaml`

* **2026-01-20 - Hardening + parity with legacy Docker container**
  * Ensured remote access is enabled for the engine:
    * Set `ALLOW_REMOTE_ACCESS=yes` in `/Users/tr0n/Code/ritchie/charts/acestream/templates/deployment.yaml`
  * Verified TLS certificate for `ace.tonioriol.com` is valid (Let’s Encrypt) and `https://ace.tonioriol.com/webui/api/service?method=get_version` returns JSON.
  * Temporarily pinned neumann to match legacy ritchie runtime (same image digest + engine version) to reduce variables during debugging.
  * Later switched back to upstream latest testing:
    * Set image tag to `latest` and removed explicit `ACESTREAM_VERSION` override so image defaults decide.
    * Verified engine reported by logs returned to `3.2.11`.

* **2026-01-20 - Node device path availability**
  * Observed repeated warnings about missing `/dev/disk/by-id` inside the pod.
  * Verified `/dev/disk/by-id` exists on the neumann node.
  * Mounted host `/dev/disk/by-id` into the pod to match engine expectations:
    * Added `hostPath` volume + mount in `/Users/tr0n/Code/ritchie/charts/acestream/templates/deployment.yaml`

  * **2026-01-20 - Playback monitoring and findings**
  * Monitored `kubectl logs` for both `acestream` and the nginx proxy.
  * Proxy patterns observed:
    * `206` on `.ts` segments indicates healthy playback.
    * `499` indicates client aborted (player stopped/switched stream).
    * `504` indicates upstream timeout (often dead/slow/blocked IDs).
    * `416` range errors appear from some clients (usually non-fatal).
  * Engine error observed during tests:
    * `apsw.ConstraintError: UNIQUE constraint failed: Torrent.checksum` from `save_torrent_local/addExternalTorrent` (no crash loop, but noisy).
  * `kubectl top` was unavailable because metrics-server is not installed.

* **2026-01-20 - Legacy ritchie validation**
  * Found legacy ritchie also timing out on the same manifest flows.
  * Restarted the legacy container for sanity:
    * `docker restart acestream-http-proxy`

## Next Steps

- [ ] Decide whether to keep nginx proxy + ingress permanently, or expose only NodePort.
- [ ] Investigate/mitigate the `apsw.ConstraintError` spam (if it correlates with playback failures).
- [ ] (Optional) Install metrics-server so `kubectl top` works (see `/Users/tr0n/Code/ritchie/docs/feat/2026-01-21-00-13-56-feat-install-metrics/context.md`).
- [ ] COMPLETED: DNS cutover + working playback verified for at least some IDs.
