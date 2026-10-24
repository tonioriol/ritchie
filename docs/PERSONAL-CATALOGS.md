# Personal catalogs

Independent private household catalog addon at `https://catalogs.tonioriol.com`, deployed in `media` by the `personal-catalogs` ArgoCD application.

## Release and runtime

Source is the private `tonioriol/personal-catalogs` repository. GitHub Actions tests on Node.js 24 and publishes a private `ghcr.io/tonioriol/personal-catalogs:sha-<full-commit>` image. Update the chart's pinned image tag through GitOps; there is no Image Updater for this application. The existing `media/ghcr-pull` registry credential is used for image pulls.

One non-root container, port 7000, with an explicit Recreate strategy avoids overlapping SQLite writers during upgrades. Startup/readiness use `/readyz`; liveness uses `/healthz`. Warmup can take several minutes, so the startup probe permits ten minutes. Container resources start at 50m CPU/128Mi memory requests, 1 CPU/512Mi limits; measure before increasing.

## Persistent data and credentials

SQLite state lives under `/data` on a dedicated RWO `hcloud-volumes` PVC. The PVC is protected from ArgoCD prune/application deletion and marked keep for Helm. After initial binding, set its backing PV reclaim policy to Retain. Deleting retained data requires an explicit separate decision. Never assume a Helm keep annotation changes the StorageClass reclaim policy.

Hetzner minimum volume size is 10GB. At the account API's October 2026 rate of EUR0.0572/GB/month net, a 10GB allocation costs approximately EUR0.572/month net (EUR0.69212 including the returned tax rate). Kubernetes requests 10Gi; inspect the actual provisioned provider allocation before reporting final cost. Provider volumes have no automatic server-backup coverage.

External Secrets Operator maps the dedicated `neumann/personal-catalogs` 1Password item to `media/personal-catalogs-secrets`. It holds provider keys, Nuvio account/backend configuration, the two random profile capability tokens, and a separate 32-byte base64 state-encryption key. Never print any values or install URLs. The encryption key must not rotate casually: existing persisted sessions and snapshots require it. Back up the key separately from the database. Profile capabilities are bearer credentials; access logs must not contain request paths and intermediaries must not cache private responses publicly.

## HTTPS routing

The Service's external-dns annotations create a proxied CNAME to the existing tunnel. Both the checked-in Cloudflare route and the remote tunnel configuration include this service. Read the live tunnel configuration before any future route change: the inspected tunnel reports `config_src=cloudflare`, and remote configuration is authoritative despite the credentials-file runtime flag. Preserve every existing remote route and the final 404 fallback when updating it. Do not replace the full route collection from a partial local chart.

## Backup and recovery

Use SQLite's online backup API to create a consistent copy, or stop the sole writer before copying the complete database. Copying only a live WAL-mode main database is not a valid backup. Verify the backup's integrity and its state keys against the source; verify decryptability with the independently stored encryption key. Keep an encrypted database backup outside the cluster, for example as a private 1Password document. Do not commit the database, history, profile URLs or secrets.

Restore into an isolated writable directory/volume first, validate integrity and decryptability, then stop the service before replacing production data. Preserve the pre-restore database until acceptance. An image rollback must remain compatible with the stored schema and encryption format. No recurring off-cluster backup scheduler is supplied by this chart; the operational owner must maintain the agreed backup cadence.
