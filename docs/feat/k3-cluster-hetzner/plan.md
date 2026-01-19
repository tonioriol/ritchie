# Neumann Cluster - Implementation Plan

## Overview

Deploy a k3s cluster on Hetzner Cloud using hetzner-k3s. Use **ArgoCD** for GitOps with a web UI.

---

## Flux vs ArgoCD: Which is More Modern?

### Timeline

| Year | Flux | ArgoCD |
|------|------|--------|
| 2016 | Flux v1 created (Weaveworks) | - |
| 2018 | - | ArgoCD created (Intuit) |
| 2020 | Flux v2 rewrite (complete rewrite) | - |
| 2022 | CNCF Graduated | CNCF Graduated |
| 2024 | Weaveworks shut down, Flux continues | Active development |

**Both are "modern"** - Flux v2 was a ground-up rewrite in 2020, ArgoCD has continuous evolution.

### Current State (2024-2026)

| Metric | Flux | ArgoCD |
|--------|------|--------|
| GitHub Stars | ~6k | ~18k |
| Contributors | ~200 | ~900 |
| CNCF Status | Graduated | Graduated |
| Backing | Community (Weaveworks gone) | Intuit + Akuity (commercial) |
| Release Cadence | Monthly | Monthly |

### Industry Adoption

**ArgoCD is more widely adopted:**
- More GitHub stars (3x)
- More Stack Overflow questions
- More job postings mention ArgoCD
- Larger ecosystem (plugins, integrations)

**But Flux has strong supporters:**
- GitLab uses Flux internally
- AWS recommends Flux for EKS
- More "Kubernetes-native" philosophy

### Philosophy Difference

| Aspect | Flux | ArgoCD |
|--------|------|--------|
| **Approach** | Toolkit of controllers | Integrated platform |
| **UI** | None (add Weave GitOps) | Built-in |
| **CRDs** | Many small CRDs | Few large CRDs |
| **Learning** | Steeper (more concepts) | Easier (all-in-one) |

### Honest Assessment

**Neither is "more modern."** Both:
- Have active development
- Are CNCF graduated
- Support Helm + Kustomize
- Auto-reconcile from git

**ArgoCD is:**
- More popular (by metrics)
- Easier to start with
- Has built-in UI
- Better for: Most users, teams wanting visibility

**Flux is:**
- More modular/composable
- Lighter resource footprint
- Preferred by: Pure GitOps purists, CLI-only workflows
- Backing concern: Weaveworks shutdown (but CNCF adopted fully)

### FLOSS Comparison

**Both are 100% FLOSS.** But there are nuances:

| Aspect | Flux | ArgoCD |
|--------|------|--------|
| **License** | Apache 2.0 | Apache 2.0 |
| **Core** | Fully open | Fully open |
| **Premium features** | None (all free) | None (all free) |
| **Governance** | CNCF (neutral) | CNCF (neutral) |
| **Commercial version** | Weave GitOps (was) | Akuity Platform |
| **Open-core model** | ❌ No | ❌ No |

**Key point:** Neither has an "enterprise edition" with locked features. Everything is open.

### Commercial Entities

| Project | Company | What They Sell |
|---------|---------|----------------|
| **Flux** | ~~Weaveworks~~ (defunct) | Was: Weave GitOps (UI) |
| **ArgoCD** | Akuity | Managed ArgoCD (SaaS) |

**Important distinction:**
- Akuity sells **hosting**, not features
- The open source ArgoCD has ALL features
- You're not missing anything by self-hosting

### Historical FLOSS Concerns

**Flux:**
- Created by Weaveworks (venture-backed company)
- Weaveworks shut down in 2024
- CNCF took over governance completely
- Now: Pure community project with no corporate owner
- **Most "libre" now** - no company has financial interest

**ArgoCD:**
- Created by Intuit (giant corporation)
- Akuity (startup) now main commercial supporter
- Akuity founders are ArgoCD maintainers
- Some worry: Could Akuity "capture" the project?
- Reality: CNCF governance prevents this

### Verdict on FLOSS

| Factor | Winner |
|--------|--------|
| License | Tie (both Apache 2.0) |
| Open governance | Tie (both CNCF) |
| No corporate owner | **Flux** (Weaveworks gone) |
| Community independence | **Flux** (pure community) |
| Long-term sustainability | **ArgoCD** (Akuity funding) |

**If you prioritize "no corporate strings":** Flux

**If you prioritize "someone is paid to maintain this":** ArgoCD

Both are genuine FLOSS with no proprietary features.

---

### My Recommendation

**For you: ArgoCD** (despite Flux being "more libre")

Why:
1. You want a web UI → ArgoCD has it built-in
2. You're learning → ArgoCD is easier to start
3. Larger community → More help available
4. Commercial backing → Akuity ensures long-term support (paid maintainers)

**If FLOSS purity is your top priority:** Go with Flux + Weave GitOps UI (also open source)

If you later decide you don't need the UI and want minimal footprint, migrating to Flux is possible (same concepts, different CRDs).

---

## Weave GitOps: The Flux Dashboard

### What Is It?

**Weave GitOps** is an open source web UI for Flux. It's the "ArgoCD dashboard" equivalent for Flux users.

```
Flux (no UI) + Weave GitOps = Similar experience to ArgoCD
```

### Comparison

| Aspect | ArgoCD UI | Weave GitOps |
|--------|-----------|--------------|
| **Built for** | ArgoCD | Flux |
| **License** | Apache 2.0 | Apache 2.0 |
| **GitHub Stars** | Part of ArgoCD (~18k) | ~600 standalone |
| **Maturity** | Very mature | Less mature |
| **Install** | Built into ArgoCD | Separate install |
| **Memory** | Part of ArgoCD ~500MB | ~100MB additional |
| **Backing** | Akuity (active) | ~~Weaveworks~~ (defunct) |
| **Future** | Active, well-funded | Community-driven now |

### Feature Comparison

| Feature | ArgoCD UI | Weave GitOps |
|---------|-----------|--------------|
| View applications | ✅ | ✅ |
| Sync status | ✅ | ✅ |
| Pod logs | ✅ | ✅ |
| Trigger sync | ✅ | ✅ |
| **Visual diff** | ✅ | ❌ |
| **Resource tree graph** | ✅ | ❌ |
| **Rollback UI** | ✅ | ❌ |
| **App creation in UI** | ✅ | ❌ |
| Multi-cluster view | ✅ | ✅ |
| RBAC | ✅ | ✅ |

### Visual Comparison

**ArgoCD UI:**
```
┌────────────────────────────────────────────────────────────┐
│ Applications                                      [+ NEW]   │
├────────────────────────────────────────────────────────────┤
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│ │acestream │ │ mysql    │ │ nginx    │ │wireguard │       │
│ │ ● Synced │ │ ● Synced │ │⚠ OutSync │ │ ● Synced │       │
│ │ Healthy  │ │ Healthy  │ │ Degraded │ │ Healthy  │       │
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
│                                                            │
│ Click app → Tree view, logs, diff, rollback buttons       │
└────────────────────────────────────────────────────────────┘
```

**Weave GitOps UI:**
```
┌────────────────────────────────────────────────────────────┐
│ Applications                                                │
├────────────────────────────────────────────────────────────┤
│ NAME          KIND            STATUS      MESSAGE          │
│ acestream     Kustomization   ✓ Ready     Applied rev...   │
│ mysql         HelmRelease     ✓ Ready     Release rec...   │
│ nginx         HelmRelease     ✗ Failed    Install fail...  │
│                                                            │
│ Click → Details panel, events, reconcile button            │
└────────────────────────────────────────────────────────────┘
```

### Honest Assessment

**ArgoCD UI is more polished and feature-rich:**
- Visual resource tree (see deployments → pods → containers)
- Visual diff (see exactly what changed)
- One-click rollback
- More intuitive for beginners

**Weave GitOps is functional but simpler:**
- List view (less visual)
- No diff view
- Basic but works
- Uncertain future after Weaveworks shutdown

### Popularity Reality

| Metric | ArgoCD | Flux + Weave GitOps |
|--------|--------|---------------------|
| GitHub stars | ~18,000 | ~6,000 + ~600 |
| Job postings | Many | Few |
| Tutorials | Abundant | Limited |
| StackOverflow | 3,000+ Qs | ~500 Qs |

**When people want a GitOps UI, they usually choose ArgoCD.**

### Bottom Line

| If you want... | Choose |
|----------------|--------|
| Best UI experience | **ArgoCD** |
| Most FLOSS-pure + UI | Flux + Weave GitOps |
| Minimal resources + UI | Flux + Weave GitOps |
| Largest community | **ArgoCD** |
| Long-term support confidence | **ArgoCD** |

---

## ArgoCD: Your Questions Answered

### Can You Still Do Everything via CLI/Git?

**YES, 100%.** ArgoCD has three interfaces - use whichever you want:

| Interface | Use Case |
|-----------|----------|
| **Git** | Push YAML → auto-sync (primary workflow) |
| **CLI** | `argocd app sync myapp` (scripting, automation) |
| **Web UI** | Visual monitoring, manual triggers, debugging |

The UI is **optional**. You can ignore it completely and just use git. The UI is for visibility, not a requirement.

```
Your Workflow Options:

Option A: Git Only (most declarative)
┌─────────────────────────────────────────────────────────┐
│  Edit YAML → git push → ArgoCD auto-syncs → Done       │
│  (Never open the UI)                                    │
└─────────────────────────────────────────────────────────┘

Option B: Git + UI for Monitoring
┌─────────────────────────────────────────────────────────┐
│  Edit YAML → git push → ArgoCD syncs                   │
│  Open UI occasionally to check status/logs             │
└─────────────────────────────────────────────────────────┘

Option C: UI for Everything
┌─────────────────────────────────────────────────────────┐
│  Use UI to trigger syncs, view diffs, rollback         │
│  (Less declarative, but possible)                      │
└─────────────────────────────────────────────────────────┘
```

---

### ArgoCD Performance Overhead

**Real-world numbers on a small cluster:**

| Component | Memory | CPU (idle) |
|-----------|--------|------------|
| argocd-server | ~100MB | <1% |
| argocd-repo-server | ~150MB | <1% |
| argocd-application-controller | ~200MB | <1% |
| argocd-redis | ~50MB | <1% |
| argocd-dex (optional, SSO) | ~50MB | <1% |
| **Total** | **~500-600MB** | **<5%** |

**On a CX22 (4GB RAM):**
- ArgoCD uses ~15% of RAM
- Leaves ~3.4GB for your workloads
- Completely fine for your use case

**If you want to minimize:**
```yaml
# Reduce replicas (for single-node clusters)
argocd-server: 1 replica (default is 1)
argocd-repo-server: 1 replica
# Disable dex if you don't need SSO
```

---

### ArgoCD UI vs Dockge

**Short answer: ArgoCD is MORE powerful but DIFFERENT.**

| Feature | Dockge | ArgoCD |
|---------|--------|--------|
| **Purpose** | Docker Compose manager | Kubernetes GitOps |
| **Stacks view** | ✅ Shows compose files | ✅ Shows "Applications" |
| **Logs** | ✅ Container logs | ✅ Pod logs |
| **Start/Stop** | ✅ One click | ✅ Sync/Delete |
| **Edit config** | ✅ Edit compose.yaml | ❌ Edit in git, not UI |
| **Status** | ✅ Running/Stopped | ✅ Synced/OutOfSync/Healthy |
| **Visual diff** | ❌ | ✅ Shows what changed |
| **Rollback** | ❌ | ✅ One-click rollback |
| **Git integration** | ❌ | ✅ Native |
| **Dependency graph** | ❌ | ✅ Shows resource tree |

**ArgoCD UI Screenshot Description:**

```
┌─────────────────────────────────────────────────────────┐
│  ArgoCD Dashboard                                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  APPLICATIONS                                            │
│  ┌─────────────────────────────────────────────────────┐│
│  │ ● acestream        Healthy  Synced   media         ││
│  │ ● mysql            Healthy  Synced   database      ││
│  │ ● nginx            Degraded OutOfSync web          ││
│  │ ● wireguard        Healthy  Synced   vpn           ││
│  └─────────────────────────────────────────────────────┘│
│                                                          │
│  Click on any app to see:                               │
│  - Resource tree (deployment → replicaset → pods)       │
│  - Live logs from any pod                               │
│  - Events and errors                                    │
│  - Diff between git and live state                      │
│  - Sync history and rollback options                    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Key differences from Dockge:**

1. **ArgoCD is read-mostly** - You edit YAML in git, not in the UI
2. **ArgoCD shows git state vs live state** - Know if someone changed something manually
3. **ArgoCD has rollback** - Click to go back to previous version
4. **ArgoCD is Kubernetes-native** - Shows pods, deployments, services (not containers)

---

## Final Recommendation: ArgoCD

Given that you want:
- ✅ Admin panel/monitoring UI
- ✅ Still use CLI/git as primary workflow
- ✅ Maximum declarativeness
- ✅ Future-proof (industry standard)

**ArgoCD is the right choice.**

---

## The Stack

```
┌─────────────────────────────────────────────────────────┐
│                    NEUMANN CLUSTER                       │
├─────────────────────────────────────────────────────────┤
│  Infrastructure:  hetzner-k3s                           │
│  GitOps:          ArgoCD                                │
│  Apps:            Helm charts in git                    │
│  Source of Truth: GitHub (ritchie repo)                 │
│  UI:              ArgoCD dashboard                      │
└─────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
/Users/tr0n/Code/ritchie/
├── clusters/
│   └── neumann/
│       ├── cluster.yaml          # hetzner-k3s config
│       └── kubeconfig            # Generated
│
├── apps/                         # ArgoCD Application manifests
│   ├── acestream.yaml
│   ├── mysql.yaml
│   └── nginx.yaml
│
├── charts/                       # Custom Helm charts
│   └── acestream/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│
├── values/                       # Values overrides
│   ├── acestream.yaml
│   ├── mysql.yaml
│   └── nginx.yaml
│
└── bootstrap/
    └── argocd-apps.yaml          # App of Apps pattern
```

---

## Implementation Steps

### Phase 1: Cluster Setup

1. Create cluster config
2. Deploy with hetzner-k3s
3. Verify nodes

### Phase 2: ArgoCD Installation

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl -n argocd wait --for=condition=Ready pods --all --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI (port-forward for now)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open: https://localhost:8080
# Login: admin / <password from above>
```

### Phase 3: Configure ArgoCD to Watch Repo

```yaml
# apps/acestream.yaml - ArgoCD Application
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
    helm:
      valueFiles:
        - ../../values/acestream.yaml
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

### Phase 4: Deploy via Git

```bash
# Add acestream app to ArgoCD
kubectl apply -f apps/acestream.yaml

# Or use CLI
argocd app create acestream \
  --repo https://github.com/YOUR_USER/ritchie \
  --path charts/acestream \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace media

# Now any git push auto-syncs!
```

---

## Files to Create

### `clusters/neumann/cluster.yaml`

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

### `charts/acestream/Chart.yaml`

```yaml
apiVersion: v2
name: acestream
description: Acestream HTTP Proxy
version: 0.1.0
appVersion: "latest"
```

### `charts/acestream/values.yaml`

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

### `charts/acestream/templates/deployment.yaml`

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

### `charts/acestream/templates/service.yaml`

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

### `apps/acestream.yaml`

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

---

## Daily Workflow

### Add New Service

1. Add Helm chart to `charts/` (or use existing from bitnami)
2. Add values to `values/`
3. Create ArgoCD Application in `apps/`
4. `git push`
5. Watch ArgoCD sync automatically (or check UI)

### Check Status

```bash
# CLI
argocd app list
argocd app get acestream

# Or just open the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

### Manual Sync (if needed)

```bash
argocd app sync acestream
# Or click "Sync" in UI
```

---

## Exposing ArgoCD UI

### Option A: Port Forward (Development)
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Option B: NodePort (Simple)
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
kubectl get svc argocd-server -n argocd
# Access via http://<node-ip>:<nodeport>
```

### Option C: Ingress with Traefik (Production)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
    - host: argocd.your-domain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
```

---

## Quick Reference

```bash
# Cluster
export HETZNER_TOKEN="xxx"
hetzner-k3s create --config clusters/neumann/cluster.yaml
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig

# ArgoCD install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# CLI login
argocd login localhost:8080

# Deploy app
kubectl apply -f apps/acestream.yaml
# OR
argocd app create acestream --repo ... --path ...

# Status
argocd app list
argocd app get acestream

# Sync
argocd app sync acestream
```

---

## Cost Summary

| Component | Type | Cost/Month |
|-----------|------|------------|
| Server | CX22 (2 vCPU, 4GB) | ~€4 |
| ArgoCD overhead | ~500MB RAM | €0 (included) |
| Load Balancer | Optional | ~€5 |
| **Total** | | **€4-9** |

---

## Summary: Why ArgoCD

| Need | Solution |
|------|----------|
| Web UI for monitoring | ✅ ArgoCD dashboard |
| Declarative/immutable | ✅ Git is source of truth |
| CLI/git workflow | ✅ Primary interface |
| Future-proof | ✅ CNCF graduated, industry standard |
| Low overhead | ✅ ~500MB, fine for 4GB server |
| Rollback capability | ✅ One-click in UI or CLI |
| Auto-sync from git | ✅ Push and forget |
