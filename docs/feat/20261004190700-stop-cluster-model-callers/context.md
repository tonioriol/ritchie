# Stop cluster model callers

**Goal:** nothing on the cluster sends model API requests. ccx runs only on the laptop (launchd `com.user.ccx`).

### 2026-10-04 19:07 — ccx, openclaw, nullclaw scaled to zero
- **Change:** `replicaCount: 0` added to the helm values in [`apps/ccx.yaml`](apps/ccx.yaml:1) and [`apps/openclaw.yaml`](apps/openclaw.yaml:1) (commit 4182d3f, pushed). ArgoCD's `root` app needed a hard refresh before the child Application specs picked it up.
- **nullclaw** has no ArgoCD Application (an orphan Deployment, `tools/nullclaw`). It was scaled with `kubectl -n tools scale deploy/nullclaw --replicas=0`. Nothing reconciles it, so it stays at 0.
- **ccx CI:** the Docker build/push job was removed from ccx `.github/workflows/release.yml` (ccx f7c36ea), so pushes no longer produce images for the image updater.
- **Evidence:** the `tools` namespace shows `ccx 0/0`, `openclaw 0/0`, `nullclaw 0/0`, and no ccx or claw pods. Before stopping, the ccx pod (image 1.22.1, accounts `personal`, `work`) logged only LiteLLM price fetches in 24h, so it was not hammering the API.
- **Kept, not deleted:** the PVCs (including the old copies of the Claude credentials), ExternalSecrets, the `ccx.tonioriol.com` cloudflared route and DNS, and the image-updater entries. Removing them fully is irreversible and was not requested.
- **Revert:** delete the `replicaCount: 0` lines and push; for nullclaw, `kubectl -n tools scale deploy/nullclaw --replicas=1`.
