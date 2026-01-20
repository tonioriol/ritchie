# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- Keep changes GitOps-first: edit `apps/*.yaml`, `charts/*`, and `manifests/*` rather than issuing imperative `kubectl` changes.
- Don’t commit secrets or kubeconfigs: [`.gitignore`](.gitignore:1) ignores [`.env`](.env:1), `clusters/*/kubeconfig`, and root `kubeconfig`.
- When changing ArgoCD ingress/TLS, preserve the redirect-loop fix: [`manifests/argocd/argocd-cmd-params-cm.yaml`](manifests/argocd/argocd-cmd-params-cm.yaml:1) must keep `server.insecure: "true"` when TLS is terminated upstream.

