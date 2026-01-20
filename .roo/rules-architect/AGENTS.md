# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- ArgoCD runs an “app-of-apps” model: [`apps/root.yaml`](apps/root.yaml:1) reconciles everything under `apps/` with automated `prune` + `selfHeal`; plan changes as Git commits, not as manual cluster drift.
- This repo intentionally mixes 3 layers: provisioning (`clusters/neumann/` for `hetzner-k3s`), GitOps apps (`apps/`), and Helm charts (`charts/`). Keep responsibilities separated when adding new components.

