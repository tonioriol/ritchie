---
title: "Gatus uptime checks for the public URLs with email alerts"
status: done
repos: [ritchie]
tags: [deployment, monitoring]
created: 2026-11-09
---

# Gatus uptime checks for the public URLs with email alerts

## TASK

**Goal:** Check every public neumann URL from the public side (through Cloudflare) on the cluster, and email tonioriol@gmail.com when one goes down and when it recovers.

**Done when:** Argo app Synced/Healthy, pod running, all 9 targets green, a forced failure produced an alert email and a resolve email in the inbox, and the test target is gone. All met 2026-11-09.

## FILES

- `apps/gatus.yaml` — ArgoCD Application, namespace `tools`, no public hostname (ClusterIP only).
- `charts/gatus/values.yaml` — image `twinproduction/gatus:v5.38.0`, resources (10m/24Mi request, 200m/96Mi limit), and the whole Gatus config under `config:` (endpoints + email alerting).
- `charts/gatus/templates/` — `configmap.yaml` (config rendered with `toYaml`), `deployment.yaml`, `externalsecret.yaml`, `service.yaml`.

## DESIGN

- Gatus: one Go pod, config as code, native SMTP email with `send-on-resolved`. Measured at 3m CPU / 12Mi.
- Endpoints: 9 URLs, every 1m. Default alert: down after 3 consecutive failures, resolved after 2 successes.
- Acexy is checked at `https://ace.tonioriol.com/ace/status` expecting **401**: the bare `/` answers 404 from Acexy, and any token-gated path answers 401 while Acexy is up (5xx or timeout means down).
- SMTP: Gmail app password `neumann-gatus` on tonioriol@gmail.com (created 2026-11-09 in myaccount.google.com/apppasswords), stored in 1Password `neumann` / item `gatus` (id `4vbicsmwa7tkcovnz6juo36qj4`), field `smtp_password`. ExternalSecret `tools/gatus-smtp` → env `SMTP_PASSWORD`, which Gatus expands from `${SMTP_PASSWORD}` in the config. Reloader rolls the pod when the secret changes.
- Mail goes from and to tonioriol@gmail.com; Gmail labels it `SENT,INBOX`, so it does land in the inbox.
- Config changes are hot-reloaded: the ConfigMap is mounted as a directory (no `subPath`) and the pod is deliberately not rolled on config changes. Triggered alert state survived a reload: flipping the test endpoint to passing via a ConfigMap change sent the resolve email from the same pod.
- Storage is sqlite on an `emptyDir` (history and alert state are lost only when the pod is replaced). Status API, in-cluster: `kubectl get --raw '/api/v1/namespaces/tools/services/gatus:80/proxy/api/v1/endpoints/statuses'`.

## LOG

- 2026-11-09 `357d32c` feat: chart + app, 9 endpoints plus a temporary `alert-test` endpoint (catalog `/health` expecting 418, threshold 2). Synced/Healthy, pod `gatus-59985bf545-7rdrr` running, all 9 public endpoints OK.
- 2026-11-09 08:16:04Z email **"test/alert-test: Alert triggered"** received (Gmail id `1a1bf60f3ce98686`, labels `UNREAD,SENT,INBOX`).
- 2026-11-09 `ddd299d` test endpoint made passing → 08:24:07Z email **"test/alert-test: Alert resolved"** received (Gmail id `1a1bf6854a9ce5fe`, `INBOX`).
- 2026-11-09 `b96ccd8` test endpoint removed. Gatus reports 9 endpoints, all green at 08:26:08Z (8× 200, acexy 401).
