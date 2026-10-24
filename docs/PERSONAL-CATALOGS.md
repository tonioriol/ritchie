# Personal catalogs

Independent private household catalog addon at `https://catalogs.tonioriol.com`, deployed in `media` by the `personal-catalogs` ArgoCD application.

## Release and runtime

Source is the private `tonioriol/personal-catalogs` repository. GitHub Actions tests on Node.js 24 and publishes a private `ghcr.io/tonioriol/personal-catalogs:sha-<full-commit>` image. Update the chart's pinned image tag through GitOps; there is no Image Updater for this application. The existing `media/ghcr-pull` registry credential is used for image pulls.

One non-root container, port 7000, with an explicit Recreate strategy avoids overlapping SQLite writers during upgrades. Startup/readiness use `/readyz`; liveness uses `/healthz`. Warmup can take several minutes, so the startup probe permits ten minutes. Container resources start at 50m CPU/128Mi memory requests, 1 CPU/512Mi limits; measure before increasing.

## Persistent data and credentials

SQLite state lives under `/data` on a dedicated RWO `hcloud-volumes` PVC. The PVC is protected from ArgoCD prune/application deletion and marked keep for Helm. The backing PV was explicitly set to Retain after initial binding. Recheck this if replacing the PVC. Deleting retained data requires an explicit separate decision. Never assume a Helm keep annotation changes the StorageClass reclaim policy.

Hetzner minimum volume size is 10GB. At the account API's October 2026 rate of EUR0.0572/GB/month net, a 10GB allocation costs approximately EUR0.572/month net (EUR0.69212 including the returned tax rate). Kubernetes requests 10Gi; the initial provider allocation was verified as 10GB. Provider volumes have no automatic server-backup coverage.

External Secrets Operator maps the dedicated `neumann/personal-catalogs` 1Password item to `media/personal-catalogs-secrets`. It holds provider keys, Nuvio account/backend configuration, the two random profile capability tokens, and a separate 32-byte base64 state-encryption key. Never print any values or install URLs. The encryption key must not rotate casually: existing persisted sessions and snapshots require it. Back up the key separately from the database. Profile capabilities are bearer credentials; access logs must not contain request paths and intermediaries must not cache private responses publicly.

## HTTPS routing

The Service's external-dns annotations create a proxied CNAME to the existing tunnel. Both the checked-in Cloudflare route and the remote tunnel configuration include this service. Read the live tunnel configuration before any future route change: the inspected tunnel reports `config_src=cloudflare`, and remote configuration is authoritative despite the credentials-file runtime flag. Preserve every existing remote route and the final 404 fallback when updating it. Do not replace the full route collection from a partial local chart.

## Backup and recovery

Use SQLite's online backup API to create a consistent copy, or stop the sole writer before copying the complete database. Copying only a live WAL-mode main database is not a valid backup. Verify the backup's integrity and its state keys against the source; verify decryptability with the independently stored encryption key. Keep an encrypted database backup outside the cluster, for example as a private 1Password document. Do not commit the database, history, profile URLs or secrets.

Restore into an isolated writable directory/volume first, validate integrity and decryptability, then stop the service before replacing production data. Preserve the pre-restore database until acceptance. An image rollback must remain compatible with the stored schema and encryption format. No recurring off-cluster backup scheduler is supplied by this chart; the operational owner must maintain the agreed backup cadence.

## Initial acceptance (2026-10-24)

The first deployed source revision was `e604f17374729debe77c9b18facbad338711b32f`, pinned to image digest `sha256:e8bea9110765cbd79eab100206f52a2d210de103d2188f0ddc043513a7981d9a`. GitHub Actions was prevented from starting by the account billing/spending restriction. The approved fallback built a clean source archive locally for Linux AMD64 and published only to the private package; no billing setting changed.

All thirteen catalogs in each profile were fetched over certificate-validated HTTPS, including all pages through skip=150 and repeated first/second pages. Profile identities and generations differed; paging, global per-profile deduplication, actual item types, private/no-store responses and invalid-capability rejection passed. A subsequent GitOps digest pin replaced the pod; both generations and every captured page hash remained identical. Cold initial population took approximately 173 seconds; the persisted-state restart was immediately ready without repeating the initial provider load.

A SQLite online backup was uploaded to the private 1Password document `neumann/personal-catalogs-database-20261024`. Downloading that document into an isolated directory reproduced the exact 3,534,848-byte backup (SHA-256 `a85b08138f33a544045a3555aba17126a1d194703f8e3f02af133e7b18a1c6b8`). SQLite integrity, decryption of all stored state, and both thirteen-catalog snapshots passed. This is a one-time verified recovery point, not an automated backup schedule.

The new DNS name initially remained absent in a local resolver's negative cache after public DNS was correct. Acceptance used public DNS resolution with the original HTTPS hostname/SNI and full certificate validation; no machine/router DNS setting was changed. The deployed external-dns version requires the current annotation namespace, so this chart includes both current and legacy annotations like the existing addon services.
