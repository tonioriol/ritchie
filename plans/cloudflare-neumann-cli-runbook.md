# Cloudflare Tunnel + DNS cutover (CLI-first runbook)

This runbook is designed to solve the DIGI Spain “blocks Hetzner IP ranges during matches” issue by making clients connect to Cloudflare anycast IPs instead of the Hetzner node IP (`5.75.129.215`).

Current situation:
- During the ISP block, traffic to Hetzner ranges fails, regardless of port (your public apps are already HTTPS on 443 via hostNetwork Traefik in [`apps/traefik.yaml`](apps/traefik.yaml:14)).

Target end state:
- **Edge**: use 1-level hostnames covered by Cloudflare Universal SSL on the free plan:
  - `acestreamio.tonioriol.com`
  - `ace.tonioriol.com`
  - `neumann.tonioriol.com`
- **Origin**: `cloudflared` runs **inside the k3s cluster** and forwards requests to in-cluster Services.

Why not `*.neumann.tonioriol.com`?

- Cloudflare Universal SSL (Free) only covers `tonioriol.com` and `*.tonioriol.com`.
- Nested names like `acestreamio.neumann.tonioriol.com` require a paid SSL option (e.g. Advanced Certificate Manager) or a custom certificate upload.

---

## 0) Credentials (do not commit, do not paste in chat)

### DigitalOcean
- DO API token with write access (used by `doctl`).

### Cloudflare
- Cloudflare API token (preferred) OR Global API Key (legacy).

If you use the **Global API Key**:
- you must authenticate with `X-Auth-Email` + `X-Auth-Key` headers (NOT `Authorization: Bearer ...`).
- the key is extremely powerful; use it only to bootstrap a least-privilege API token, then stop using it.

Recommended: keep tokens in your local [`.env`](.env:1) (gitignored by [`.gitignore`](.gitignore:1)) and load via direnv using [`.envrc`](.envrc:1).

---

## 1) Cloudflare API token permissions (minimum practical)

Create an API token in Cloudflare with **these permissions**:

1) **Account**: Read
   - Needed to discover `account_id` via API (optional if you already know it)

2) **Zone**: Edit
   - Needed to create the new zone `neumann.tonioriol.com`

3) **Zone / DNS**: Edit
   - Needed if you want to create DNS records via API (optional if you only use `cloudflared tunnel route dns` later)

Resource scope:
- For zone creation, the token must apply to the **account** where you will create the zone.
- You cannot scope zone-creation permissions to a specific zone that does not exist yet.

---

## 1b) Global API Key (legacy) auth headers

If you are using the Global API Key, use these headers instead of `Authorization: Bearer ...`:

```bash
-H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
-H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
```

And export:

```bash
export CF_AUTH_EMAIL='you@example.com'
export CF_GLOBAL_API_KEY='...'
```

Best practice: use the Global API Key only to create a least-privilege API token, then revoke/stop using the Global API Key for automation.

## 2) Create the zone in Cloudflare (CLI via API)

Local environment variables (example):

```bash
export CF_API_TOKEN='...'  # preferred
export CF_AUTH_EMAIL='...' # only needed for Global API Key auth
export CF_GLOBAL_API_KEY='...' # only needed for Global API Key auth
export CF_ZONE_NAME='neumann.tonioriol.com'
```

Discover your account ID (API token auth):

```bash
curl -sS \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  https://api.cloudflare.com/client/v4/accounts \
  | jq -r '.result[] | [.id,.name] | @tsv'
```

Discover your account ID (Global API Key auth):

```bash
curl -sS \
  -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
  -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
  https://api.cloudflare.com/client/v4/accounts \
  | jq -r '.result[] | [.id,.name] | @tsv'
```

Pick the account you want, then:

```bash
export CF_ACCOUNT_ID='...'
```

Create the zone (API token auth):

```bash
curl -sS -X POST \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H 'Content-Type: application/json' \
  https://api.cloudflare.com/client/v4/zones \
  --data "{\"name\":\"${CF_ZONE_NAME}\",\"account\":{\"id\":\"${CF_ACCOUNT_ID}\"},\"jump_start\":false,\"type\":\"full\"}" \
  | tee /tmp/cf-neumann-zone.json

jq -r '.result.id' /tmp/cf-neumann-zone.json
jq -r '.result.name_servers[]' /tmp/cf-neumann-zone.json
```

Create the zone (Global API Key auth):

```bash
curl -sS -X POST \
  -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
  -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
  -H 'Content-Type: application/json' \
  https://api.cloudflare.com/client/v4/zones \
  --data "{\"name\":\"${CF_ZONE_NAME}\",\"account\":{\"id\":\"${CF_ACCOUNT_ID}\"},\"jump_start\":false,\"type\":\"full\"}" \
  | tee /tmp/cf-neumann-zone.json

jq -r '.result.id' /tmp/cf-neumann-zone.json
jq -r '.result.name_servers[]' /tmp/cf-neumann-zone.json
```

Save outputs locally:
- `CF_ZONE_ID` (the zone id)
- the two `name_servers` (you’ll delegate to these in DigitalOcean)

---

## 3) (Historical) Delegating a sub-zone

Important: the parent zone is `tonioriol.com` (DigitalOcean). Delegation is done by adding **NS** records for `neumann`.

Because `neumann.tonioriol.com` currently exists as an **A** record pointing to Hetzner, you must delete that A record first (DNS rules: NS cannot coexist with other record types on the same name).

Authenticate `doctl`:

```bash
export DO_TOKEN='...'
doctl auth init --access-token "${DO_TOKEN}"
```

List records:

```bash
doctl compute domain records list tonioriol.com --format ID,Type,Name,Data,TTL
```

Delete the conflicting A record for `neumann` (replace `<ID>`):

```bash
doctl compute domain records delete tonioriol.com <ID>
```

Create NS delegation records (replace with the two Cloudflare nameservers):

```bash
doctl compute domain records create tonioriol.com \
  --record-type NS \
  --record-name neumann \
  --record-data <ns1>.ns.cloudflare.com \
  --record-ttl 30

doctl compute domain records create tonioriol.com \
  --record-type NS \
  --record-name neumann \
  --record-data <ns2>.ns.cloudflare.com \
  --record-ttl 30
```

At this point, `neumann.tonioriol.com` (and everything under it) is now served by Cloudflare DNS.

---

## 4) Create the Tunnel + DNS routes (CLI via cloudflared)

This is the most stable CLI path for tunnels.

Install `cloudflared` on your laptop (one-time). Example via Homebrew:

```bash
brew install cloudflare/cloudflare/cloudflared
```

Authenticate (one-time). This command typically opens a browser to authorize your Cloudflare account:

```bash
cloudflared tunnel login
```

Create a named tunnel:

```bash
cloudflared tunnel create neumann
```

Create DNS routes pointing hostnames at the tunnel:

```bash
cloudflared tunnel route dns neumann acestreamio.tonioriol.com
cloudflared tunnel route dns neumann ace.tonioriol.com

# Recommended: keep ArgoCD UI hostname working after delegation
cloudflared tunnel route dns neumann neumann.tonioriol.com
```

Get the tunnel token (to run the connector in Kubernetes):

```bash
cloudflared tunnel token neumann
```

Keep that token locally; you will create a Kubernetes Secret from it (see next section).

---

## 5) Cluster side (GitOps) – what will change in this repo

We will implement these repo changes (in code mode):

1) Add a new Helm chart:
- `charts/cloudflared/` (Deployment + ConfigMap for `config.yaml`)

2) Add a new ArgoCD Application:
- `apps/cloudflared.yaml`

3) Ensure no automation is forcing the proxied hostnames back to Hetzner IPs.

Tunnel ingress mapping (cloudflared will forward to Services directly):
- addon: `http://acestreamio.media.svc.cluster.local:80` (service from [`charts/acestreamio/templates/service.yaml`](charts/acestreamio/templates/service.yaml:1))
- proxy: `http://acestream-proxy.media.svc.cluster.local:80` (service from [`charts/acestream/templates/proxy-service.yaml`](charts/acestream/templates/proxy-service.yaml:1))
- argocd UI: `http://argocd-server.argocd.svc.cluster.local:80` (ingress host from [`charts/argocd-ingress/values.yaml`](charts/argocd-ingress/values.yaml:1))

Kubernetes Secret (created out-of-band, not in git):

```bash
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig

kubectl create namespace cloudflared --dry-run=client -o yaml | kubectl apply -f -

kubectl -n cloudflared create secret generic cloudflared-tunnel \
  --from-literal=TUNNEL_TOKEN='paste-token-here' \
  --dry-run=client -o yaml \
  | kubectl apply -f -
```

---

## 6) Validation checklist (home ISP without VPN)

1) DNS should *not* resolve to `5.75.129.215`:

```bash
dig +short A acestreamio.tonioriol.com
dig +short A ace.tonioriol.com
dig +short A neumann.tonioriol.com
```

2) Endpoints should respond:

```bash
curl -I https://acestreamio.tonioriol.com/manifest.json

# Pick a known ID and test the proxy HLS endpoint
curl -I 'https://ace.tonioriol.com/ace/manifest.m3u8?id=<ID>&pid=stremio-test'
```

---

## 7) Admin access (kubectl) during ISP blocks (separate workstream)

Cloudflare Tunnel solves the *end-user HTTPS ingress* issue.

It does **not** fix `kubectl` during blocks, because your kube-apiserver is still on the Hetzner public IP `:6443`.

Best practice: add an overlay network (Tailscale or WireGuard) so you can reach the API via a private overlay IP.

### Option A (recommended): Cloudflare WARP Private Network route to the kube-apiserver

This keeps the existing Cloudflare Tunnel connector and adds a **private** route so your laptop (running WARP) can reach the k3s API via the node private IP.

What we route:

- `10.0.0.2/32` (the neumann node private IP from [`clusters/neumann/cluster.yaml`](clusters/neumann/cluster.yaml:3))

Steps:

1) Install Cloudflare WARP on your laptop and login to your Zero Trust org.

2) Ensure the tunnel has `warp-routing` enabled in its remote config.

3) Create a Teamnet route `10.0.0.2/32` -> the tunnel.

4) Create a second kubeconfig (overlay) that points the server to `https://10.0.0.2:6443`.

Example (copy your existing config and only change the server field):

```bash
cp ./clusters/neumann/kubeconfig ./clusters/neumann/kubeconfig.warp

# Edit the server line in kubeconfig.warp:
# server: https://10.0.0.2:6443
```

Use it:

```bash
KUBECONFIG=./clusters/neumann/kubeconfig.warp kubectl get nodes -o wide
```

Notes:

- The API certificate already includes `10.0.0.2` as a SAN (k3s default).
- Keep the public API (`5.75.129.215:6443`) open until you have confirmed the WARP route works.
