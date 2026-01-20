# install-metrics Install metrics-server on neumann

## TASK

Install `metrics-server` on the `neumann` k3s cluster so `kubectl top nodes/pods --containers` works for basic CPU/memory visibility during debugging.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/docs/feat/install-metrics/context.md`
* `/Users/tr0n/Code/ritchie/apps/root.yaml`
* `/Users/tr0n/Code/ritchie/docs/feat/fix-ace-neumann/context.md`

## PLAN

This cluster currently does **not** have `metrics-server`, so `kubectl top nodes/pods` won’t work.

### Is it overkill?

No. For a single-node k3s cluster, `metrics-server` is a small, standard add-on.

It enables:

- `kubectl top nodes`
- `kubectl top pods -A --containers`
- Better visibility for debugging resource-related issues (CPU spikes / OOM)

It does **not** include long-term storage or dashboards by itself; it just provides the metrics API.

### Install (vanilla manifests)

```bash
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
kubectl top nodes
kubectl top pods -A --containers
```

### k3s note (TLS)

If you see errors like x509 / unable to validate the Kubelet certificate, add:

```yaml
args:
  - --kubelet-insecure-tls
```

to the `metrics-server` deployment.

### GitOps recommendation

Prefer managing this via ArgoCD:

- Create an ArgoCD Application (or Helm chart) for `metrics-server`.
- Keep it in `kube-system`.

This keeps the cluster fully GitOps-driven and avoids drift.

## EVENT LOG
