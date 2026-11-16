# ClickHouse backups

`data/clickhouse-backup` runs at 03:15 UTC. Its init container creates a ClickHouse-native backup of `ccx` and `ccx_neumann` in Hetzner Object Storage. Sundays take a full backup; other days take an incremental based on `LATEST_FULL`. The Drive container starts only after that succeeds.

The third copy lives in the Google Drive folder [ccx-clickhouse-backup](https://drive.google.com/drive/folders/1YMY4Y8hjlCa_K0s3aC_Pxd6RwJO4_xMx), under `ccx`. It includes every existing full, incremental and `LATEST_FULL`, not just the latest chain. `rclone copy` never deletes source or destination objects. Each run checks every relative path and size before reporting success.

## Credentials

- Existing S3/admin credentials: 1Password `neumann / clickhouse`, consumed through `data/clickhouse-backup`.
- Drive and monitor credentials: 1Password `neumann / clickhouse-drive-backup`, fields `rclone_config` and `heartbeat_token`, consumed through `data/clickhouse-drive-backup` and `tools/gatus-smtp` via ESO.
- Drive has a dedicated refresh token scoped only to `https://www.googleapis.com/auth/drive.file`. The broader Google CLI credential is not deployed. The token can operate only on files used with that OAuth app.
- The read-only Secret config is copied into a memory-backed pod volume before rclone refreshes its token. A fresh job can always refresh from the stored refresh token; access-token changes need not be saved back to 1Password.
- Reauthorize only this dedicated grant if its refresh token expires or is revoked. Do not revoke the shared OAuth app: other Google clients use it.

## Alerts

Gatus sends email to `tonioriol@gmail.com` through its existing Gmail SMTP configuration:

- `backups_clickhouse-backup`: immediate notification on script failure; missing heartbeat after 26 hours.
- `backups_clickhouse-drive-copy`: immediate notification on copy or verification failure; missing heartbeat after 30 hours.
- Each uses failure/success thresholds of one and sends a recovery email.
- A pod that cannot start or is killed before its shell can notify is caught by the missing-heartbeat check. Gatus itself runs in the same cluster, so this is not an external whole-cluster outage detector.

## Operations

Run the whole ordered job:

```sh
KUBECONFIG=clusters/neumann/kubeconfig kubectl -n data create job \
  --from=cronjob/clickhouse-backup clickhouse-backup-manual-$(date -u +%Y%m%d%H%M%S)
```

Inspect both container logs separately (`backup` is an init container):

```sh
KUBECONFIG=clusters/neumann/kubeconfig kubectl -n data logs job/JOB_NAME -c backup
KUBECONFIG=clusters/neumann/kubeconfig kubectl -n data logs job/JOB_NAME -c drive-copy
```

A copy-only verification job can be created from the CronJob's job template after removing `spec.template.spec.initContainers`; this does not create another S3 backup. Preserve the `drive-copy` container and its Secret/volume references.

Do not use `rclone sync`, remove backup objects, or add a lifecycle retention rule. Incrementals need their referenced full, and request data is retained permanently. Watch Drive capacity as the archive grows; a quota error fails the copy and alerts through Gatus.
