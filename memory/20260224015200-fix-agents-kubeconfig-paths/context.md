---
title: "Update outdated cluster docs and fix kubeconfig paths"
status: done
repos: [ritchie]
tags: [agents, documentation, kubernetes, kubeconfig]
created: 2026-02-24
---
# Update outdated cluster docs and fix kubeconfig paths

## TASK

Audit and update all outdated documentation in `ritchie/` to reflect the current cluster state: fix kubeconfig paths for monorepo workspace root, update component lists, mark completed TODO items, and refresh the acestream-scraper integration plan.

## GENERAL CONTEXT

The `neumann` monorepo contains multiple sub-projects. The `ritchie/` subdirectory holds all Kubernetes/GitOps config. Agents operate from the workspace root (`/Users/tr0n/Code/neumann`), not from `ritchie/`. The `.envrc` uses direnv to set `KUBECONFIG`, but direnv is not available to agents.

### Current Cluster State (2026-02-24)

- **Node**: `neumann-master1` — k3s v1.31.4, Hetzner, Ubuntu 24.04, CPU 15%, Memory 78%
- **18 ArgoCD apps** all Healthy/Synced: acestream, acestream-scraper, acestreamio, acexy, argocd-config, argocd-image-updater, argocd-ingress, cert-manager, cloudflared, external-dns, external-secrets, external-secrets-config, iptv-relay, metrics-server, onepassword-connect, root, traefik, vscode
- **14 namespaces**: 1password, argocd, cert-manager, cloudflared, default, external-dns, external-secrets, kube-node-lease, kube-public, kube-system, media, system-upgrade, tools, traefik
- **Notable restarts**: external-dns (44), argocd-image-updater (11), cert-manager (8)

### REPO

tonioriol/neumann → `ritchie/`

### RELEVANT FILES

* `ritchie/AGENTS.md`
* `ritchie/README.md`
* `ritchie/TODO.md`
* `ritchie/plans/acestream-scraper-integration.md`
* `ritchie/clusters/neumann/kubeconfig`
* `ritchie/.envrc`
* `ritchie/apps/external-dns.yaml`

## PLAN

- ✅ Fix all `KUBECONFIG=` references in AGENTS.md to use `ritchie/clusters/neumann/kubeconfig`
- ✅ Add note that direnv is not available to agents
- ✅ Verify the fix works by running `kubectl get nodes` with the corrected path
- ✅ Update README.md: fix kubeconfig paths, add missing components (1Password, ESO, Acexy)
- ✅ Update TODO.md: mark completed items (CI + Image Updater), add new items from audit
- ✅ Update acestream-scraper-integration.md: mark completed phases, update architecture diagram
- ✅ Verify all TODO items are still open (list.js, playlists/, converter.js, chart rename, proxy)
- ✅ Investigate external-dns restart loop (44 restarts)

## EVENT LOG

* **2026-02-24 01:49 - Attempted kubectl with default context, hit wrong cluster (EKS)**
  * Why: The default kubeconfig context pointed at an AWS EKS cluster, not the Hetzner k3s neumann cluster
  * How: `kubectl get nodes -o wide` returned EKS nodes in eu-north-1

* **2026-02-24 01:50 - Read AGENTS.md to find documented kubeconfig path**
  * Why: User feedback said to use the correct context as documented
  * How: Read `ritchie/AGENTS.md` — found instructions at line 206-210 referencing `${PWD}/clusters/neumann/kubeconfig`

* **2026-02-24 01:52 - Fixed all kubeconfig paths in AGENTS.md**
  * Why: `${PWD}/clusters/neumann/kubeconfig` only works when CWD is `ritchie/` — agents run from `neumann/` (workspace root)
  * How: Updated 4 locations in `ritchie/AGENTS.md`:
    * Line 7: Added note that direnv is not available to agents
    * Lines 137-139: `KUBECONFIG=clusters/neumann/kubeconfig` → `KUBECONFIG=ritchie/clusters/neumann/kubeconfig`
    * Lines 190-196: Deploy verification commands now use inline `KUBECONFIG=ritchie/...` prefix
    * Lines 206-210: Rewrote "kubectl context" section with correct relative path and warning

* **2026-02-24 01:53 - Verified fix works**
  * Why: Confirm the corrected path reaches the neumann k3s cluster
  * How: `KUBECONFIG=ritchie/clusters/neumann/kubeconfig kubectl get nodes -o wide` → `neumann-master1` (k3s v1.31.4)

* **2026-02-24 01:53 - Retrieved full cluster status**
  * Why: Need actual state to compare against docs
  * How: `kubectl get namespaces`, `kubectl get pods --all-namespaces`, `kubectl top nodes`, `kubectl get applications`

* **2026-02-24 01:56 - Updated TODO.md**
  * Why: Two items already completed (CI + Image Updater)
  * How: Marked `[x]` for acestreamio CI and ArgoCD Image Updater tasks

* **2026-02-24 01:57 - Updated README.md**
  * Why: Missing 1Password Connect, External Secrets, Acexy in component list; kubeconfig paths used `./clusters/` instead of `ritchie/clusters/`
  * How: Added 1Password/ESO/Acexy to component list; fixed all `KUBECONFIG` command examples; clarified acestream chart description

* **2026-02-24 01:57 - Updated acestream-scraper-integration.md**
  * Why: Phases 1 and 2 fully completed; architecture diagram showed old acestream-proxy topology
  * How: Marked Phase 1 and 2 as ✅; updated mermaid diagram to show Acexy, Cloudflare Tunnel, and correct namespaces

* **2026-02-24 02:02 - Verified all TODO items are still open**
  * Why: User asked to confirm items weren't already done
  * How: Checked `acestreamio/list.js` (still exists, used as fallback in `channels.js:8`), `acestreamio/playlists/` (6 files), `converter.js` (exists), `ritchie/charts/acestream/Chart.yaml` (still named `acestream`), `acestream-proxy` pod (Running 1/1, 0 restarts). All items confirmed still open.

* **2026-02-24 02:03 - Investigated external-dns restart loop (44 restarts in 4d)**
  * Why: Appeared in cluster status as concerning
  * How: `kubectl logs --previous` showed crash cause: `level=fatal msg="Failed to do run once: error reading response body: unexpected EOF"`. This is a known transient Cloudflare API issue — connection drops cause `unexpected EOF`, external-dns exits fatal, k8s restarts it. Pod always recovers immediately and DNS syncs fine ("All records are already up to date" every ~1min). **Benign — no action needed.** Liveness probe is not the cause (process crashes on its own before probe fails).

## Next Steps

COMPLETED
