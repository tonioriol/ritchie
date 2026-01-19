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
export HETZNER_TOKEN="your-token-here"
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
| Server | CX22 (2 vCPU, 4GB) | ~€4 |
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

---

## Next Steps

- [ ] Set `HETZNER_TOKEN` environment variable
- [ ] Run `hetzner-k3s create --config clusters/neumann/cluster.yaml`
- [ ] Install ArgoCD on cluster (Phase 2 commands)
- [ ] Update `apps/acestream.yaml` repoURL to actual GitHub URL
- [ ] Apply ArgoCD Application: `kubectl apply -f apps/acestream.yaml`
