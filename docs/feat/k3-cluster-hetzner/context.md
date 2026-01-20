# K3S-HETZNER Setup: Neumann Cluster

## TASK

Set up a hetzner-k3s cluster named "neumann" on Hetzner Cloud. Use ArgoCD for GitOps-based deployment management with web UI. Deploy acestream-http-proxy as the first service.

## GENERAL CONTEXT

### Stack

- **Infrastructure**: hetzner-k3s (declarative cluster provisioning)
- **GitOps**: ArgoCD (auto-sync from git, web UI)
- **Apps**: Helm charts in git repository
- **Source of Truth**: GitHub (ritchie repo)

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/docs/feat/k3-cluster-hetzner/context.md` - This file
* `/Users/tr0n/Code/ritchie/clusters/neumann/cluster.yaml` - hetzner-k3s config (to create)
* `/Users/tr0n/Code/ritchie/charts/acestream/` - Custom Helm chart (to create)
* `/Users/tr0n/Code/ritchie/apps/acestream.yaml` - ArgoCD Application (to create)
* `/Users/tr0n/Code/ritchie/.env` - Local secret env vars (gitignored)
* `/Users/tr0n/Code/ritchie/.gitignore` - Ignores `.env` and generated kubeconfigs

---

## PLAN

### Directory Structure

```
/Users/tr0n/Code/ritchie/
├── clusters/
│   └── neumann/
│       ├── cluster.yaml          # hetzner-k3s config
│       └── kubeconfig            # Generated after create
├── charts/
│   └── acestream/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           └── service.yaml
├── apps/
│   └── acestream.yaml            # ArgoCD Application
└── values/
    └── acestream.yaml            # Optional overrides
```

---

### Phase 1: Create Cluster

#### 1.1 Create cluster config

**File: `clusters/neumann/cluster.yaml`**

```yaml
---
hetzner_token: "${HETZNER_TOKEN}"
cluster_name: neumann
kubeconfig_path: "./kubeconfig"
k3s_version: v1.31.4+k3s1

networking:
  ssh:
    port: 22
    use_agent: true
  allowed_networks:
    ssh:
      - 0.0.0.0/0
    api:
      - 0.0.0.0/0

masters_pool:
  instance_type: cx22
  instance_count: 1
  location: fsn1

worker_node_pools: []
```

#### 1.2 Deploy cluster

```bash
export HCLOUD_TOKEN="your-token-here"
cd /Users/tr0n/Code/ritchie/clusters/neumann
hetzner-k3s create --config cluster.yaml
```

#### 1.3 Verify

```bash
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig
kubectl get nodes
```

---

### Phase 2: Install ArgoCD

#### 2.1 Install

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### 2.2 Wait for ready

```bash
kubectl -n argocd wait --for=condition=Ready pods --all --timeout=300s
```

#### 2.3 Get admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### 2.4 Expose UI via NodePort

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
kubectl get svc argocd-server -n argocd
```

Access at: `https://<NODE_IP>:<NODEPORT>`

---

### Phase 3: Create Acestream Helm Chart

#### 3.1 Chart.yaml

**File: `charts/acestream/Chart.yaml`**

```yaml
apiVersion: v2
name: acestream
description: Acestream HTTP Proxy
version: 0.1.0
appVersion: "latest"
```

#### 3.2 values.yaml

**File: `charts/acestream/values.yaml`**

```yaml
image:
  repository: ghcr.io/martinbjeldbak/acestream-http-proxy
  tag: latest
  pullPolicy: Always

service:
  type: NodePort
  port: 6878
  nodePort: 30878
```

#### 3.3 deployment.yaml

**File: `charts/acestream/templates/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: acestream
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
```

#### 3.4 service.yaml

**File: `charts/acestream/templates/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
      {{- if eq .Values.service.type "NodePort" }}
      nodePort: {{ .Values.service.nodePort }}
      {{- end }}
  selector:
    app: {{ .Release.Name }}
```

---

### Phase 4: Deploy via ArgoCD

#### 4.1 Create ArgoCD Application

**File: `apps/acestream.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: acestream
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USER/ritchie
    targetRevision: main
    path: charts/acestream
  destination:
    server: https://kubernetes.default.svc
    namespace: media
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### 4.2 Apply

```bash
kubectl apply -f apps/acestream.yaml
```

#### 4.3 Verify

```bash
argocd app list
kubectl -n media get pods
kubectl -n media get svc
```

Access acestream at: `http://<NODE_IP>:30878`

---

### Quick Reference Commands

```bash
# Set kubeconfig
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig

# Cluster
hetzner-k3s create --config clusters/neumann/cluster.yaml
hetzner-k3s delete --config clusters/neumann/cluster.yaml

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# ArgoCD CLI
argocd login localhost:8080
argocd app list
argocd app sync acestream

# Check pods
kubectl get pods -A
kubectl -n media logs -l app=acestream
```

---

### Cost Summary

| Component | Type | Cost/Month |
|-----------|------|------------|
| Server | CX23 (2 vCPU, 4GB) | ~€4 |
| Load Balancer | Not used (NodePort) | €0 |
| **Total** | | **~€4** |

---

## EVENT LOG

* **2026-01-19 09:01 - Initial planning session**
  * Evaluated deployment options: Kustomize, Helmfile, Flux, ArgoCD
  * Decision: ArgoCD for GitOps with web UI
  * Reasons: Built-in UI, largest community, CNCF graduated, ~500MB overhead acceptable

* **2026-01-19 10:00 - Plan finalized**
  * Full implementation plan documented in this context file
  * Ready for implementation in code mode

* **2026-01-19 19:22 - Implementation started**
  * Created cluster config: `clusters/neumann/cluster.yaml`
  * VSCode showed schema validation errors (RKE schema incorrectly applied to hetzner-k3s file)
  * Verified config matches official hetzner-k3s docs - errors are false positives

* **2026-01-19 19:53 - Helm chart created**
  * Created `charts/acestream/` with Chart.yaml, values.yaml, templates/
  * Deployment exposes port 6878, Service uses NodePort 30878
  * Ran `helm lint` - passed (only info: icon recommended)

* **2026-01-19 19:54 - ArgoCD Application created**
  * Created `apps/acestream.yaml` pointing to `charts/acestream/`
  * Auto-sync enabled with prune and selfHeal
  * Creates `media` namespace automatically

* **2026-01-19 19:57 - Simplification pass**
  * Removed empty `# yaml-language-server: $schema=` comment from cluster.yaml
  * Removed `values/acestream.yaml` (contained only comments, no actual overrides)

* **2026-01-19 20:00 - Stack clarification**
  * Helm = packaging format (templates in `charts/`)
  * ArgoCD = GitOps controller (replaces Helmfile/Flux CLI tools)
  * ArgoCD natively renders Helm charts - no separate helm commands needed

* **2026-01-19 21:14 - Cluster provisioned successfully (neumann)**
  * Persisted Hetzner API token locally via `/Users/tr0n/Code/ritchie/.env` and added `/Users/tr0n/Code/ritchie/.gitignore` entries to prevent committing secrets and generated kubeconfigs
  * Discovered `hetzner-k3s` v2.4.5 expects `HCLOUD_TOKEN` (not `HETZNER_TOKEN`); validation error: "Hetzner API token is missing, please set it in the configuration file or in the environment variable HCLOUD_TOKEN"
  * Updated `/Users/tr0n/Code/ritchie/clusters/neumann/cluster.yaml`:
    * Fixed server type from `cx22` to `cx23` (verified via `hcloud server-type list`)
    * Enabled single-node scheduling by setting `schedule_workloads_on_masters: true` (otherwise `hetzner-k3s` aborts with "At least one worker node pool is required in order to schedule workloads")
    * Switched location from `fsn1` to `nbg1` after Hetzner API error `resource_unavailable: server location disabled`
    * Added SSH key configuration for remote access
    * Configured both IPv4 and IPv6 public networking
    * Enabled private networking with subnet 10.0.0.0/16
  * Ran cluster creation:
    * `export HCLOUD_TOKEN=$(grep HCLOUD_TOKEN .env | cut -d '=' -f2) && cd /Users/tr0n/Code/ritchie/clusters/neumann && hetzner-k3s create --config cluster.yaml`
    * Generated kubeconfig at `/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig`
  * Verified cluster readiness:
    * `export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig && kubectl get nodes -o wide`
    * Confirmed single node `neumann-master1` in Ready state with roles control-plane,etcd,master
    * Node has external IP 5.75.129.215 and internal IP 10.0.0.2

* **2026-01-19 21:14 - ArgoCD installed and exposed via NodePort**
  * Installed ArgoCD into `argocd` namespace:
    * `kubectl create namespace argocd`
    * `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
    * Waited for readiness: `kubectl -n argocd wait --for=condition=Ready pods --all --timeout=300s`
  * Retrieved initial admin password:
    * `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
  * Exposed ArgoCD server via NodePort:
    * `kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'`
    * Confirmed ports via `kubectl get svc argocd-server -n argocd` (HTTPS NodePort allocated on 31796)
  * ArgoCD UI accessible at: `https://5.75.129.215:31796`

* **2026-01-19 21:14 - Acestream deployed via ArgoCD Application**
  * Confirmed `/Users/tr0n/Code/ritchie/apps/acestream.yaml` repoURL points to `https://github.com/tonioriol/ritchie`
  * Applied ArgoCD Application:
    * `kubectl apply -f /Users/tr0n/Code/ritchie/apps/acestream.yaml`
  * Verified deployment:
    * `kubectl -n media get pods` (acestream running)
    * `kubectl -n media get svc` (NodePort 30878)
  * Acestream service accessible at: `http://5.75.129.215:30878`
  * Note: `argocd` CLI is not installed locally (`argocd: command not found`); operations can be performed via the ArgoCD UI or via `kubectl` against ArgoCD CRs

* **2026-01-19 21:14 - Updated context.md with implementation details**
  * Documented cluster provisioning with actual timestamps and configuration details
  * Added ArgoCD installation and exposure steps with NodePort information
  * Recorded acestream deployment via ArgoCD Application
  * Updated next steps checklist to reflect completed tasks

 * **2026-01-19 23:55 - ArgoCD secured behind Traefik Ingress + Let's Encrypt**
  * DNS:
    * Created `A` record: `neumann.tonioriol.com` -> `5.75.129.215` (TTL: 30s, DigitalOcean minimum)
  * Hetzner Cloud firewall (`neumann`):
    * Added inbound TCP 80 (HTTP, required for cert-manager HTTP-01)
    * Added inbound TCP 443 (HTTPS)
  * Traefik (deployed via ArgoCD app):
    * Switched from pure NodePort exposure to binding on host ports 80/443 so HTTP-01 works
    * Configured:
      * `hostNetwork: true`
      * `ports.web.port: 80`, `ports.web.containerPort: 80`, `ports.web.hostPort: 80`
      * `ports.websecure.port: 443`, `ports.websecure.containerPort: 443`, `ports.websecure.hostPort: 443`
      * `podSecurityContext.runAsUser: 0` (required to bind privileged ports)
      * `securityContext.capabilities.add: [NET_BIND_SERVICE]`
  * cert-manager:
    * `ClusterIssuer` `letsencrypt-prod` is Ready
    * Issued certificate `argocd-server-tls` for `neumann.tonioriol.com`
  * ArgoCD Ingress:
    * Host: `neumann.tonioriol.com`
    * TLS termination at Traefik using secret `argocd-server-tls`
    * Backend routes to `argocd-server` Service port 80 (HTTP)
  * Redirect-loop fix (TLS terminated at ingress):
    * Added `manifests/argocd/argocd-cmd-params-cm.yaml` setting `server.insecure: "true"`
    * Added `apps/argocd-config.yaml` to manage the config via ArgoCD
    * Restarted `argocd-server` to apply the config
  * Verified:
    * `https://neumann.tonioriol.com` returns HTTP 200 and serves the ArgoCD UI

* **2026-01-20 01:23 - Simplify GitOps manifests & confirm diffs vs baseline commit**
  * Compared current `HEAD` against baseline commit `4cb1bc95da565e6df37208ea60d30861fc175535` to ensure the “ingress + TLS hardening” work remains readable and minimal.
    * `git diff --stat 4cb1bc95da565e6df37208ea60d30861fc175535..HEAD`
  * Applied a small simplification in `/Users/tr0n/Code/ritchie/apps/root.yaml`:
    * Removed `spec.source.directory.recurse: false` (default behaviour is already non-recursive for `directory` sources).
    * Committed as `51cb090` (keeps behaviour unchanged).
  * Noted a suspicious “URL-like” path in the diff stat output; verified it does not exist on disk and is not tracked by git (no follow-up required).
  * Sanity checks:
    * `helm lint /Users/tr0n/Code/ritchie/charts/acestream`
    * `helm lint /Users/tr0n/Code/ritchie/charts/argocd-ingress`
  * Repo state:
    * `main` is pushed to GitHub after `b5a7682` (previous simplify pass) and `51cb090` (root app simplification).

 * **2026-01-20 02:16 - Reduced DigitalOcean DNS TTL for neumann (doctl)**
   * Goal: reduce propagation time for updates to `neumann.tonioriol.com` by setting TTL to DigitalOcean minimum (30s).
   * Located the record and its current TTL:
     * `doctl compute domain records list tonioriol.com --format ID,Type,Name,Data,TTL`
   * Found record: `A neumann -> 5.75.129.215` with record ID `1805008488` and TTL `300`.
   * First update attempt failed due to incorrect `doctl` syntax:
     * Command: `doctl compute domain records update tonioriol.com 1805008488 --record-ttl 30`
     * Error: `(records.update) command contains unsupported arguments`
   * Root cause: `records update` does not accept record ID as a positional argument; must use `--record-id`.
   * Updated TTL to 30s successfully:
     * `doctl compute domain records update tonioriol.com --record-id 1805008488 --record-ttl 30`
     * Verified output shows TTL `30` for record `1805008488`.

 * **2026-01-20 02:22 - Updated ace.tonioriol.com DNS to point to neumann acestream proxy**
   * Goal: route `ace.tonioriol.com` to the new acestream-http-proxy running on the `neumann` cluster.
   * Updated DigitalOcean DNS `A` record:
     * `ace.tonioriol.com` -> `5.75.129.215` (record ID `1777925433`, TTL `30s`)
   * Command:
     * `doctl compute domain records update tonioriol.com --record-id 1777925433 --record-data 5.75.129.215 --record-ttl 30`

---

## Next Steps

- [x] Provision cluster `neumann` via `hetzner-k3s` and generate kubeconfig
- [x] Install ArgoCD and expose UI via NodePort
- [x] Deploy acestream via ArgoCD Application
- [x] (Optional) Install ArgoCD CLI locally for convenience (via devbox)
- [x] (Recommended) Secure ArgoCD access (ingress + TLS, SSO, or IP allowlist); NodePort is currently open
- [x] (Recommended) Commit & push repo changes so ArgoCD remains fully GitOps-driven for future changes
- [x] Reduce DigitalOcean DNS TTL for `neumann.tonioriol.com` to 30s (minimum)
