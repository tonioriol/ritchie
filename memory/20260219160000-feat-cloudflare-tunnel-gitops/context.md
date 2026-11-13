# Cloudflare Tunnel GitOps — credentials-file mode + external-dns

## TASK

Switch the Cloudflare Tunnel from **token-based** (remote config, requires API calls via `sync-cloudflare-tunnel.sh`) to **credentials-file mode** (local ConfigMap drives routing, pure GitOps). Deploy **external-dns with Cloudflare provider** to auto-create/update DNS CNAME records from Service annotations. Delete the manual sync script.

User mandate: *"no hacks and pragmatic fuckery, just do it RIGHT"*

## GENERAL CONTEXT

Refer to AGENTS.md for project structure description.

### REPO

`/Users/tr0n/Code/neumann/ritchie`

### CREDENTIALS (all in `ritchie/.env`, gitignored)

| Var | Value | Usage |
|-----|-------|-------|
| `CF_EMAIL` | `tonioriol@gmail.com` | Cloudflare account email |
| `CF_API_KEY` | `75cb98aaf93c07e617ec3492c5b7acf1e4af7` | Global API key (used by external-dns) |
| `CF_ACCOUNT_ID` | `6e73d8e42d0b50e37efc1b20401e35a0` | Account identifier |
| `CF_TUNNEL_ID` | `85e6bc75-0025-4fc3-9341-d4e517fea614` | Tunnel UUID |

**Tunnel CNAME target**: `85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com`

**Zone**: `tonioriol.com` (one-level subdomains only due to Universal SSL)

### CURRENT STATE (token-based tunnel, semi-manual)

The tunnel runs with `--token $(TUNNEL_TOKEN)`. In this mode, **Cloudflare's remote config overrides the local ConfigMap**. The ConfigMap is documentation-only.

To add/change a hostname you must:
1. Edit `charts/cloudflared/values.yaml`
2. Run `scripts/sync-cloudflare-tunnel.sh` — PUTs ingress config to CF API + upserts DNS CNAMEs
3. Commit and push

This is **not pure GitOps** — step 2 is an imperative API call.

### CURRENT TUNNEL HOSTNAMES (from `charts/cloudflared/values.yaml`)

| Hostname | k8s Service target | Namespace |
|----------|-------------------|-----------|
| `acestreamio.tonioriol.com` | `acestreamio.media.svc.cluster.local:80` | `media` |
| `ace.tonioriol.com` | `acexy.media.svc.cluster.local:8080` | `media` |
| `tv.tonioriol.com` | `iptv-relay.media.svc.cluster.local:80` | `media` |
| `scraper.tonioriol.com` | `acestream-scraper.default.svc.cluster.local:8000` | `default` |
| `neumann.tonioriol.com` | `argocd-server.argocd.svc.cluster.local:80` | `argocd` |

### RELEVANT FILES

**Cloudflared chart (TO BE MODIFIED)**:
- `ritchie/charts/cloudflared/Chart.yaml` — `name: cloudflared`, `version: 0.1.0`, `appVersion: 2025.2.0`
- `ritchie/charts/cloudflared/values.yaml` — image `cloudflare/cloudflared:2025.2.0`, `tunnelTokenSecret.name: cloudflared-tunnel`, `hosts:` array with 5 entries
- `ritchie/charts/cloudflared/templates/deployment.yaml` — runs `cloudflared tunnel --no-autoupdate --config /etc/cloudflared/config/config.yaml run --token $(TUNNEL_TOKEN)`, mounts ConfigMap at `/etc/cloudflared/config`, has checksum annotation for pod restart on config change
- `ritchie/charts/cloudflared/templates/configmap.yaml` — generates `config.yaml` with `ingress:` rules from `.Values.hosts`, comment says "Token-based tunnel"
- `ritchie/apps/cloudflared.yaml` — ArgoCD Application, destination namespace `cloudflared`, source `charts/cloudflared`

**Service templates (TO BE ANNOTATED for external-dns)**:
- `ritchie/charts/acexy/templates/service.yaml` — ClusterIP, port from `.Values.service.port` (8080), name `{{ .Release.Name }}`
- `ritchie/charts/acestreamio/templates/service.yaml` — ClusterIP, port 80, name `{{ .Release.Name }}`
- `ritchie/charts/acestream-scraper/templates/service.yaml` — ClusterIP, port from `.Values.service.port` (8000), name `{{ .Release.Name }}`
- `ritchie/charts/iptv-relay/templates/service.yaml` — ClusterIP, port from `.Values.service.port` (80), name `{{ .Release.Name }}`
- ArgoCD: no Service template — uses `argocd-server` in `argocd` namespace (installed by ArgoCD itself). DNS for `neumann.tonioriol.com` handled via the `argocd-ingress` chart Ingress resource at `ritchie/charts/argocd-ingress/templates/ingress.yaml`.

**Sync script (TO BE DELETED)**:
- `ritchie/scripts/sync-cloudflare-tunnel.sh` — reads `values.yaml`, PUTs tunnel config to CF API, upserts DNS CNAMEs

**Documentation (TO BE UPDATED)**:
- `ritchie/AGENTS.md` lines 42-78 — "Cloudflare Tunnel config (token-based, remote-managed)" section

**Old external-dns context (SUPERSEDED)**:
- `ritchie/docs/feat/2026-01-31-11-13-32-feat-external-dns/context.md` — was for DigitalOcean DNS with `*.neumann.tonioriol.com`, already marked superseded

## ARCHITECTURE (target state)

```
  git push values.yaml
       |
       v
  ArgoCD auto-sync
       |
       +----> cloudflared Deployment restarts
       |      reads ConfigMap ingress rules directly
       |      routes traffic through tunnel
       |      NO remote config override
       |
       +----> external-dns Deployment
              watches annotated Services/Ingresses
              creates/updates CNAME records
              target: 85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com
              via CF_API_KEY + CF_EMAIL

  No manual scripts. No imperative API calls. Pure GitOps.
```

## PLAN

### Phase 1: Extract tunnel credentials + create k8s Secret

The `TUNNEL_TOKEN` is a base64-encoded JSON containing `AccountTag`, `TunnelID`, `TunnelSecret`. We need to decode it and create a credentials file Secret.

```bash
# 1. Get the existing TUNNEL_TOKEN from the cluster
export KUBECONFIG=ritchie/clusters/neumann/kubeconfig
TUNNEL_TOKEN=$(kubectl -n cloudflared get secret cloudflared-tunnel -o jsonpath='{.data.TUNNEL_TOKEN}' | base64 -d)

# 2. The token itself is base64 — decode to get the JSON credentials
echo "$TUNNEL_TOKEN" | base64 -d > /tmp/credentials.json
cat /tmp/credentials.json
# Expected: {"AccountTag":"6e73d8e42d0b50e37efc1b20401e35a0","TunnelID":"85e6bc75-0025-4fc3-9341-d4e517fea614","TunnelSecret":"<secret>"}

# 3. Create the new credentials Secret
kubectl -n cloudflared create secret generic cloudflared-credentials \
  --from-file=credentials.json=/tmp/credentials.json \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Clean up
rm /tmp/credentials.json
```

### Phase 2: Update cloudflared chart — switch to credentials-file mode

**`charts/cloudflared/values.yaml`** — replace:
```yaml
# Old:
tunnelTokenSecret:
  name: cloudflared-tunnel
  key: TUNNEL_TOKEN

# New:
tunnelId: "85e6bc75-0025-4fc3-9341-d4e517fea614"
credentialsSecret:
  name: cloudflared-credentials
  key: credentials.json
```

**`charts/cloudflared/templates/configmap.yaml`** — change to:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
data:
  config.yaml: |
    tunnel: {{ .Values.tunnelId }}
    credentials-file: /etc/cloudflared/credentials/credentials.json
    ingress:
{{- range .Values.hosts }}
      - hostname: {{ .hostname | quote }}
        service: {{ .service | quote }}
{{- end }}
      - service: http_status:404
```

**`charts/cloudflared/templates/deployment.yaml`** — change to:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: cloudflared
  template:
    metadata:
      labels:
        app.kubernetes.io/name: cloudflared
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      containers:
        - name: cloudflared
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command: ["cloudflared"]
          args:
            - tunnel
            - --no-autoupdate
            - --config
            - /etc/cloudflared/config/config.yaml
            - run
          # No --token, no TUNNEL_TOKEN env var. Credentials come from file.
          volumeMounts:
            - name: config
              mountPath: /etc/cloudflared/config
              readOnly: true
            - name: credentials
              mountPath: /etc/cloudflared/credentials
              readOnly: true
          resources:
{{- toYaml .Values.resources | nindent 12 }}
      volumes:
        - name: config
          configMap:
            name: cloudflared-config
        - name: credentials
          secret:
            secretName: {{ .Values.credentialsSecret.name }}
```

### Phase 3: Deploy external-dns with Cloudflare provider

**Create k8s Secret for external-dns** (run once, not committed):
```bash
kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -
kubectl -n external-dns create secret generic external-dns-cloudflare \
  --from-literal=CF_API_KEY="$CF_API_KEY" \
  --from-literal=CF_API_EMAIL="$CF_EMAIL" \
  --dry-run=client -o yaml | kubectl apply -f -
```

> **Future hardening**: Create a scoped CF API Token (Zone:DNS:Edit + Zone:Zone:Read for tonioriol.com) and switch to `CF_API_TOKEN` env var. Lower blast radius than the global key.

**Create `ritchie/apps/external-dns.yaml`** — ArgoCD Application:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-dns
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: external-dns
    targetRevision: "8.*"
    helm:
      values: |
        provider: cloudflare
        cloudflare:
          email: tonioriol@gmail.com
          apiKey: ""
          secretName: external-dns-cloudflare
        domainFilters:
          - tonioriol.com
        policy: sync
        txtOwnerId: neumann
        sources:
          - service
          - ingress
        extraEnvVarsSecret: external-dns-cloudflare
  destination:
    server: https://kubernetes.default.svc
    namespace: external-dns
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Note: Bitnami external-dns chart with `cloudflare` provider reads `CF_API_KEY` and `CF_API_EMAIL` from the secret specified by `extraEnvVarsSecret`. The `secretName` field is for the Bitnami chart's built-in secret creation — we skip that and inject env vars directly from our own secret.

### Phase 4: Add external-dns annotations to Service templates

Each public Service needs two annotations:
- `external-dns.alpha.kubernetes.io/hostname` — the DNS name to create
- `external-dns.alpha.kubernetes.io/target` — the CNAME target (tunnel endpoint)

**`charts/acexy/templates/service.yaml`** — add to metadata:
```yaml
  annotations:
    external-dns.alpha.kubernetes.io/hostname: ace.tonioriol.com
    external-dns.alpha.kubernetes.io/target: "85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com"
```

**`charts/acestreamio/templates/service.yaml`** — add:
```yaml
  annotations:
    external-dns.alpha.kubernetes.io/hostname: acestreamio.tonioriol.com
    external-dns.alpha.kubernetes.io/target: "85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com"
```

**`charts/acestream-scraper/templates/service.yaml`** — add:
```yaml
  annotations:
    external-dns.alpha.kubernetes.io/hostname: scraper.tonioriol.com
    external-dns.alpha.kubernetes.io/target: "85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com"
```

**`charts/iptv-relay/templates/service.yaml`** — add:
```yaml
  annotations:
    external-dns.alpha.kubernetes.io/hostname: tv.tonioriol.com
    external-dns.alpha.kubernetes.io/target: "85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com"
```

**ArgoCD (`neumann.tonioriol.com`)** — already has an Ingress at `charts/argocd-ingress/templates/ingress.yaml` with `host: {{ .Values.host }}` = `neumann.tonioriol.com`. external-dns with `sources: [service, ingress]` will pick this up automatically. Add annotation to the Ingress:
```yaml
  annotations:
    external-dns.alpha.kubernetes.io/target: "85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com"
```
(hostname is inferred from `spec.rules[].host`)

**Make annotations values-driven**: To avoid hardcoding the tunnel CNAME in every template, each chart's `values.yaml` should have:
```yaml
externalDns:
  enabled: false
  hostname: ""
  target: ""
```
And the Service template conditionally renders annotations:
```yaml
{{- if .Values.externalDns.enabled }}
  annotations:
    external-dns.alpha.kubernetes.io/hostname: {{ .Values.externalDns.hostname }}
    external-dns.alpha.kubernetes.io/target: {{ .Values.externalDns.target | quote }}
{{- end }}
```
Then set the actual values in `apps/<name>.yaml` ArgoCD Application `helm.values`.

### Phase 5: Delete sync script + clean up

```bash
rm ritchie/scripts/sync-cloudflare-tunnel.sh
# If scripts/ is now empty:
rmdir ritchie/scripts/
```

### Phase 6: Update AGENTS.md

Rewrite lines 42-78 from "Cloudflare Tunnel config (token-based, remote-managed)" to "Cloudflare Tunnel config (credentials-file, GitOps)":
- Explain credentials-file mode
- Explain external-dns auto-DNS
- New workflow: edit `values.yaml` → git push → done
- Remove sync script docs
- Keep env var table (update to reflect new vars)

### Phase 7: Verify end-to-end

```bash
export KUBECONFIG=ritchie/clusters/neumann/kubeconfig

# 1. cloudflared running in credentials-file mode
kubectl -n cloudflared logs deploy/cloudflared --tail=20
# Should show: "Connection registered" with tunnel connectors, NO "remote config" messages

# 2. external-dns reconciling
kubectl -n external-dns logs deploy/external-dns --tail=50
# Should show: "Desired change: CREATE/UPDATE ace.tonioriol.com CNAME ..."

# 3. DNS records
dig +short ace.tonioriol.com
dig +short acestreamio.tonioriol.com
dig +short scraper.tonioriol.com
dig +short tv.tonioriol.com
dig +short neumann.tonioriol.com
# All should resolve (either to CF proxy IPs or to the tunnel CNAME)

# 4. Tunnel routing
curl -s https://ace.tonioriol.com/ace/status
curl -s https://scraper.tonioriol.com/
```

### Phase 8: Commit and push

```bash
cd ritchie && git add -A && git commit -m "feat: cloudflare tunnel credentials-file mode + external-dns" && git push
```

## KEY DECISIONS

| Decision | Rationale |
|----------|-----------|
| Credentials-file over token | Token mode = remote config overrides local ConfigMap. Credentials-file = local ConfigMap IS the config. Pure GitOps. |
| external-dns over manual script | Kubernetes-native, watches annotations, auto-reconciles. No imperative API calls. |
| CF_API_KEY now, scoped token later | We already have the global key in .env. Works today. Upgrade to scoped token as a future hardening step. |
| Service annotations over Ingress-only | Most services dont have Ingress resources — traffic routes through CF tunnel directly to ClusterIP Services. |
| Values-driven annotations | Avoids hardcoding tunnel CNAME in templates. Actual hostnames/targets set in ArgoCD app values. |
| `target` annotation on Services | external-dns needs to know the CNAME target. Since theres no LoadBalancer IP, we explicitly set the tunnel CNAME. |

## SUPERSEDES

- `ritchie/docs/feat/2026-01-31-11-13-32-feat-external-dns/context.md` — DigitalOcean DNS provider with `*.neumann.tonioriol.com` naming. Now using Cloudflare DNS with `*.tonioriol.com`.
- `ritchie/scripts/sync-cloudflare-tunnel.sh` — manual sync script, deleted.

## EVENT LOG

* **2026-02-19 11:49 - Context review and plan validation**
  * Why: Needed to validate the plan against actual file state before implementing
  * How: Read all relevant files — cloudflared chart (values, configmap, deployment), all 4 Service templates, 5 ArgoCD Application manifests, argocd-ingress Ingress, AGENTS.md, sync script
  * Key info: Plan confirmed accurate. All files matched expected state. Created todo list for tracking.

* **2026-02-19 14:50 - Phase 1: Extract tunnel credentials + create Secret**
  * Why: credentials-file mode requires a JSON file with AccountTag, TunnelID, TunnelSecret mounted into the pod
  * How: `kubectl -n cloudflared get secret cloudflared-tunnel -o jsonpath='{.data.TUNNEL_TOKEN}' | base64 -d` then `echo "$TUNNEL_TOKEN" | base64 -d > /tmp/credentials.json`
  * Key info: **Discovery** — the TUNNEL_TOKEN decodes to JSON with **abbreviated keys** (`a`, `t`, `s`) not full names. Rewrote JSON with Python to use `AccountTag`, `TunnelID`, `TunnelSecret` before creating Secret. Created `cloudflared/cloudflared-credentials` Secret via `kubectl create secret generic --from-file=credentials.json`. Cleaned up `/tmp/credentials.json`.

* **2026-02-19 15:03 - Phase 2a: Update `charts/cloudflared/values.yaml`**
  * Why: Replace token-based config with credentials-file mode references
  * How: Replaced `tunnelTokenSecret: {name, key}` block with `tunnelId: "85e6bc75-0025-4fc3-9341-d4e517fea614"` + `credentialsSecret: {name: cloudflared-credentials, key: credentials.json}`

* **2026-02-19 15:05 - Phase 2b: Update `charts/cloudflared/templates/configmap.yaml`**
  * Why: ConfigMap must include `tunnel:` and `credentials-file:` directives so cloudflared uses local config (not remote override)
  * How: Added `tunnel: {{ .Values.tunnelId }}` and `credentials-file: /etc/cloudflared/credentials/credentials.json` at top of `config.yaml` block scalar

* **2026-02-19 15:07 - Phase 2c: Update `charts/cloudflared/templates/deployment.yaml`**
  * Why: Remove `--token $(TUNNEL_TOKEN)` arg and `TUNNEL_TOKEN` env var; add credentials volume mount
  * How: Removed `- --token` + `- $(TUNNEL_TOKEN)` args and entire `env:` block; added `credentials` volumeMount at `/etc/cloudflared/credentials` and `credentials` volume from Secret `{{ .Values.credentialsSecret.name }}`

* **2026-02-19 15:10 - Phase 3a: Create `external-dns-cloudflare` Secret**
  * Why: external-dns needs CF_API_KEY + CF_API_EMAIL to authenticate with Cloudflare DNS API; secret must not be committed
  * How: `kubectl create namespace external-dns` + `kubectl -n external-dns create secret generic external-dns-cloudflare --from-literal=CF_API_KEY="..." --from-literal=CF_API_EMAIL="..."`

* **2026-02-19 15:11 - Phase 3b: Create `ritchie/apps/external-dns.yaml`**
  * Why: Deploy external-dns as an ArgoCD-managed Application for GitOps DNS management
  * How: Created ArgoCD Application pointing at Bitnami chart `bitnami/external-dns` version `8.*`, cloudflare provider, `extraEnvVarsSecret: external-dns-cloudflare`, `policy: sync`, `txtOwnerId: neumann`, sources: service + ingress

* **2026-02-19 15:12 - Phase 4a: Add `externalDns` values block to all chart `values.yaml` files**
  * Why: Values-driven pattern avoids hardcoding tunnel CNAME in templates; actual values set in ArgoCD app manifests
  * How: Appended `externalDns: {enabled: false, hostname: "", target: ""}` to acexy, acestreamio, acestream-scraper, iptv-relay `values.yaml`

* **2026-02-19 15:13 - Phase 4b: Add conditional annotations to all Service templates**
  * Why: external-dns watches these annotations to create/update DNS CNAME records
  * How: Added `{{- if .Values.externalDns.enabled }} annotations: external-dns.alpha.kubernetes.io/hostname + target {{- end }}` to all 4 Service templates

* **2026-02-19 15:13 - Phase 4c: Update argocd-ingress chart for external-dns**
  * Why: ArgoCD uses an Ingress (not a Service) — external-dns infers hostname from `spec.rules[].host`, only needs `target` annotation
  * How: Added `externalDns: {enabled: false, target: ""}` to `argocd-ingress/values.yaml`; added conditional `external-dns.alpha.kubernetes.io/target` annotation to `ingress.yaml` template

* **2026-02-19 15:14 - Phase 4d: Set actual externalDns values in all ArgoCD Application manifests**
  * Why: Enable external-dns annotations with correct hostnames and tunnel CNAME target in each app
  * How: Added `externalDns: {enabled: true, hostname: <host>, target: "85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com"}` to helm.values in apps/acexy.yaml, apps/acestreamio.yaml, apps/acestream-scraper.yaml, apps/iptv-relay.yaml; added `externalDns: {enabled: true, target: "...cfargotunnel.com"}` to apps/argocd-ingress.yaml

* **2026-02-19 15:14 - Phase 5: Delete sync script + scripts/ dir**
  * Why: Script is now superseded by external-dns; keeping it would create false impression it's still needed
  * How: `rm ritchie/scripts/sync-cloudflare-tunnel.sh && rmdir ritchie/scripts/`

* **2026-02-19 15:19 - Phase 6: Update AGENTS.md**
  * Why: Documentation must reflect new credentials-file mode + external-dns workflow
  * How: Rewrote lines 42-78 — replaced "token-based, remote-managed" section with "credentials-file, GitOps" section explaining new architecture, required secrets, and new pure-GitOps workflow (edit values.yaml → push → done)

* **2026-02-19 15:20 - Phase 7/8: Lint, commit, push**
  * Why: Validate all chart changes before pushing; commit `e96a9de`
  * How: `helm lint` on all 6 charts — 0 failures. `git add -A && git commit -m "feat: cloudflare tunnel credentials-file mode + external-dns"` — 23 files changed, 551 insertions, 215 deletions. `git push` to `main`.

* **2026-02-19 15:22 - ArgoCD sync + cloudflared verification**
  * Why: Confirm cloudflared restarts in credentials-file mode
  * How: Triggered root app hard refresh. cloudflared pod restarted (`cloudflared-7f6946565c-j47w2`), Synced+Healthy. Logs confirmed 4 tunnel connections registered at `fra10`/`fra16` — no `--token`, no remote config override.

* **2026-02-19 15:24 - external-dns ErrImagePull: docker.io/bitnami image not found**
  * Why: Bitnami stopped pushing to Docker Hub; images moved to `registry.bitnami.com`
  * How: Attempted fix with `image.registry: registry.bitnami.com` in Bitnami chart values + `global.security.allowInsecureImages: true` (chart v8+ blocks non-docker.io registries). Fixed image template rendering locally but `registry.bitnami.com` DNS unreachable from cluster node.

* **2026-02-19 15:48 - Switch to kubernetes-sigs/external-dns chart**
  * Why: `registry.bitnami.com` DNS resolution fails on k3s node; `registry.k8s.io` is always reachable
  * How: Replaced Bitnami chart with `kubernetes-sigs/external-dns` chart from `https://kubernetes-sigs.github.io/external-dns/`. Changed credentials injection from `extraEnvVarsSecret` to explicit `env[].valueFrom.secretKeyRef`. Confirmed template renders `registry.k8s.io/external-dns/external-dns:v0.20.0`. Deleted stuck ArgoCD Application + old Deployment simultaneously, triggered root hard refresh.

* **2026-02-19 15:50 - external-dns running, DNS reconciliation confirmed**
  * Why: Verify external-dns connects to Cloudflare and reconciles DNS records
  * How: `kubectl -n external-dns logs deploy/external-dns --tail=30` — shows `Provider: cloudflare`, `Policy: sync`, `TXTOwnerID: neumann`, `"All records are already up to date"` — all 5 CNAME records confirmed correct.

* **2026-02-19 15:51 - End-to-end tunnel routing verified**
  * Why: Confirm traffic routes correctly through the tunnel
  * How: `curl https://ace.tonioriol.com/ace/status → 401` (Acexy token auth, expected); `curl https://scraper.tonioriol.com/api/health → 308` (HTTP→HTTPS redirect, expected). DNS returns Cloudflare proxy IPs (not CNAME) because hostnames are orange-cloud proxied.

* **2026-02-19 15:55 - Simplify pass: annotation quoting + comment trim**
  * Why: `hostname` annotation was unquoted while `target` used `| quote` — inconsistent; deployment comment was verbose
  * How: Added `| quote` to `external-dns.alpha.kubernetes.io/hostname` in all 4 Service templates. Trimmed 3-line deployment comment to 2 concise lines. All 6 charts lint clean. Commit `f9aa750`.

## Next Steps

COMPLETED
