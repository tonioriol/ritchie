# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- Local `KUBECONFIG` is auto-exported by [`.envrc`](.envrc:1) to `clusters/neumann/kubeconfig`; if kubectl points to the wrong cluster, check direnv/devbox env first.
- `kubectl top` requires metrics-server; it’s installed via ArgoCD in [`apps/metrics-server.yaml`](apps/metrics-server.yaml:1) and uses `--kubelet-insecure-tls` for k3s.

