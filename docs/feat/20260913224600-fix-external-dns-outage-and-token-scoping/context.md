---
title: "Recover from external-dns record wipe, pin chart versions, migrate annotation prefix, scope the Cloudflare credential"
status: active
repos: [ritchie]
tags: [deployment, dns, incident, secrets]
related: [20260219160000-feat-cloudflare-tunnel-gitops, 20260131111332-feat-external-dns]
created: 2026-09-13
---

# Recover from external-dns record wipe, pin chart versions, migrate annotation prefix, scope the Cloudflare credential

## TASK

**Goal:** Restore the DNS records external-dns deleted when it self-upgraded to
chart 1.22.0, then remove the three conditions that allowed it: floating chart
ranges, dependence on the legacy annotation prefix, and an account-wide
Cloudflare credential.

**Done when:** every public hostname resolves and responds; no ArgoCD
Application tracks a floating `targetRevision`; external-dns reads its own
v0.22.0 default annotation prefix rather than an override; and it authenticates
with a token scoped to the `tonioriol.com` zone. All four are met — see the
2026-09-14 00:00 verification entry.

## SPEC

No separate spec — remediation of a live incident, scope agreed turn by turn in
conversation. The approved shape is recorded in the LOG decisions below.

## FILES

- apps/external-dns.yaml — pinned chart, default prefix, `CF_API_TOKEN`
- apps/external-secrets.yaml — pinned `0.20.4`
- apps/onepassword-connect.yaml — pinned `1.17.1`
- charts/external-secrets-config/templates/external-dns-cloudflare.yaml — ExternalSecret for the scoped token
- charts/*/templates/service.yaml, charts/argocd-ingress/templates/ingress.yaml — 12 dual-annotated sources
- AGENTS.md — credential model

## PLAN

**Plan:** no plan.md — four sequential work units, all complete.
**Cursor:** Main task complete. Two operator follow-ups remain, both awaiting a
user decision: retire the superseded Global API key, and decommission
nullclaw/openclaw (teardown order drafted in the 2026-09-14 00:03 entry, not
approved).
**Status:** active

## LOG

### 2026-09-13 22:50 — Diagnosed: external-dns deleted its own records

- Why: `https://aiostreams.tonioriol.com/` unreachable. `curl` exit code 6, so
  the failure was name resolution, not the app.
- How: the pod was healthy and `curl http://aiostreams.media.svc/manifest.json`
  returned 200 in-cluster, isolating the fault to public DNS. Cloudflare's
  authoritative nameservers returned NXDOMAIN for `aiostreams`, `ccx`, `code`,
  `claw` and `detour`.
- Evidence: the Cloudflare audit log showed 10 record deletions at
  `2026-09-11T09:02:47Z` from `5.75.129.215` — the cluster master node — seven
  seconds after the external-dns Deployment updated at `09:02:40Z`.
- Key info: `apps/external-dns.yaml` tracked `targetRevision: "1.*"`, so chart
  1.22.0 (app v0.22.0) installed unattended. That release changed the default
  annotation prefix from `external-dns.alpha.kubernetes.io/` to
  `external-dns.kubernetes.io/` **with no fallback**, so every Service became
  invisible; under `policy: sync` external-dns then deleted the records its TXT
  registry said it owned. Attribution to `tonioriol@gmail.com` was an artifact
  of it holding the account Global API key — **investigatory**, and the reason
  the credential was later scoped.

### 2026-09-13 22:56 — Restored the records (a868f40)

- Why: recover service before addressing the underlying causes.
- How: pinned `targetRevision: "1.22.0"` and set
  `annotationPrefix: external-dns.alpha.kubernetes.io/` so v0.22.0 would read
  the annotations already on the Services. Pushed, then hard-refreshed the
  **`root`** Application — patching the `external-dns` child does nothing, since
  `apps/` is owned by the app-of-apps parent.
- Verification: all five hostnames recreated and returning 200 from inside the
  cluster and via `curl --resolve`.
- Key info: the developer Mac kept reporting `http=000` afterwards. This was a
  stale negative cache in Tailscale MagicDNS (`100.100.1.1`) honouring the
  zone's 1800s negative SOA TTL — not a deployment fault. Proven by querying
  `8.8.8.8` and `9.9.9.9` directly. **Implemented.**

### 2026-09-13 23:43 — Pinned the remaining floating chart ranges (5e73a96)

- Why: the same wildcard pattern that caused the outage existed elsewhere.
- How: audited every `ritchie/apps/*.yaml`; two more tracked ranges —
  `external-secrets` `"0.*"` → `0.20.4`, `onepassword-connect` `"1.*"` →
  `1.17.1`.
- Decision: pin exact versions everywhere and upgrade deliberately. A minor bump
  shipping a breaking default is exactly what happened here, so semver ranges
  are not a safe contract for this cluster. **Implemented.**

### 2026-09-13 23:46 — Migrated to the new annotation prefix (5e73a96, da2c63e)

- Why: `annotationPrefix` was a holding fix that pinned the cluster to a
  deprecated spelling.
- Decision: dual-annotate, then flip. Upstream's
  `--enable-legacy-annotation-prefix` escape hatch merged only in September 2026,
  *after* v0.22.0 shipped, so it was unavailable on the pinned chart. Rejected
  flipping the controller first, which would have re-orphaned every record.
- How: added `external-dns.kubernetes.io/*` beside the existing
  `external-dns.alpha.kubernetes.io/*` on 12 sources (11 Services plus
  `argocd-ingress`), pushed, and confirmed live Services carried both prefixes —
  hard-refreshing `detour-radio-web`, `acestream-scraper` and `acexy`, which
  lagged. Only then removed the `annotationPrefix` override.
- Verification: dry run under the new default prefix reported 0 changes before
  the flip; afterwards external-dns logged `AnnotationPrefix:external-dns.kubernetes.io/`
  and `All records are already up to date`, with all 9 records intact.
- Key info: the legacy annotations remain in place as a fallback and are safe to
  remove later. **Implemented.**

### 2026-09-14 00:00 — Replaced the Global API key with a scoped token (aca5521, 9534ccb, 3847ee6)

- Why: external-dns authenticated as the account owner, so its DNS writes were
  indistinguishable from human action in the audit log, and the credential could
  reach every zone and service in the account.
- How: created token `external-dns-neumann`
  (ID `d7860720590ddbe6229d9176625ceed4`) with `Zone:Read` + `DNS:Write` scoped
  to zone `d2a1b3b499edccf20913d621ffa6fbb1` (`tonioriol.com`); stored it in
  1Password (`neumann` vault, item `cloudflare-external-dns`, field
  `api_token`); added an ExternalSecret to `charts/external-secrets-config`
  producing `external-dns/external-dns-cloudflare-token` → `CF_API_TOKEN`;
  switched `apps/external-dns.yaml` from `CF_API_KEY` + `CF_API_EMAIL`.
- Decision: the ExternalSecret lives in `charts/external-secrets-config`, not
  the external-dns Application, because that Application renders the upstream
  chart and has no hook for local manifests. Committed the ExternalSecret
  *before* the cutover so the Secret existed when the Deployment rolled. Also
  added `secret.reloader.stakater.com/reload` so a 1Password rotation rolls the
  pod automatically.
- Verification: ESO `SecretSynced`; in-cluster secret prefix matched 1Password
  (`cfut_NQT`); pod `external-dns-67dfbddfb8-qdsvd` running
  `registry.k8s.io/external-dns/external-dns:v0.22.0` on `CF_API_TOKEN`; three
  consecutive reconcile loops logged `All records are already up to date` with
  no auth errors; zone diffed before and after the cutover — **26 records,
  byte-identical**; all 10 hostnames responding (`aiostreams` 200, `scraper` 401,
  `acestreamio` 200, `ccx` 401, `code` 302, `claw` 302, `detour` 200, `neumann`
  200, `adamnfinecupof.coffee` 200, `ace` 404 — the last two auth-gated or
  path-less, as expected); every ArgoCD Application `Synced`.
- Key info: `neumann.tonioriol.com` logs a benign recurring warning —
  `contains conflicting record type candidates; discarding CNAME record` —
  predating this work. **Implemented.**

### 2026-09-14 00:02 — Confirmed the Cloudflare data path was untouched

- Why: user asked whether Cloudflare still proxies aiostreams after the
  credential change.
- Evidence: `CNAME aiostreams.tonioriol.com → 85e6bc75-…cfargotunnel.com`,
  `proxied=true`; response headers `server: cloudflare`,
  `cf-ray: a3aa70063b00d8ff-MAD`.
- Key info: two separate mechanisms are easy to conflate. The **tunnel**
  (`cloudflared`, credential `cloudflared-credentials`) carries traffic and was
  not touched; **external-dns** only writes records. `DNS:Write` cannot alter
  proxying, TLS, caching or WAF. The `cloudflare-proxied: "true"` annotation
  must stay — `cfargotunnel.com` resolves to a private IPv6 address when
  grey-clouded, which breaks routing. **Investigatory.**

### 2026-09-14 00:03 — Drafted nullclaw/openclaw decommission; awaiting approval

- Why: user reported using neither service and asked to turn both down.
- Evidence: `claw.tonioriol.com` is owned by **nullclaw**, not openclaw — TXT
  registry reads `external-dns/resource=service/tools/nullclaw` — while
  `charts/cloudflared/values.yaml:46` routes that hostname to
  `openclaw.tools.svc`. `nullclaw` has **no ArgoCD Application** (chart exists in
  git, never wired), so it is unmanaged drift. `nullclaw-data` PVC has been
  `Terminating` since `2026-03-01T10:41:25Z` on a `kubernetes.io/pvc-protection`
  finalizer held by the still-running pod — a 10Gi Hetzner volume billed for
  ~196 days. `openclaw` is `Degraded`: pod `openclaw-86cbdd675-hcnvr` stuck
  `Init:0/2` with **453** restarts on `install-deps`, while a 173-day-old pod
  still serves. `nullclaw-secrets` reads from the **shared** `openclaw`
  1Password item.
- Proposed order: remove the cloudflared route (local values **and** the remote
  Cloudflare tunnel config, which overrides it); delete ArgoCD app `openclaw`
  plus both charts; delete the unmanaged nullclaw resources directly, releasing
  the stuck PVC; let `policy: sync` prune the `claw` CNAME and TXT; optionally
  delete the 1Password item last, since both consume it.
- Key info: **not executed** — irreversible (destroys two 10Gi volumes and stops
  `claw.tonioriol.com` resolving), so it is held for explicit approval per the
  safety guard. **Partial.**
