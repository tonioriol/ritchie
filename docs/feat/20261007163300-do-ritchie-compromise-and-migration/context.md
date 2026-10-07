# DO ritchie compromise + migration of remaining sites to neumann

## TASK

bertomeuiglesias.com (and siblings) on the legacy DigitalOcean droplet `ritchie` serve Japanese SEO spam. Contain, preserve data (DBs especially), rebuild the sites on the neumann k3s cluster, then destroy the droplet.

## STATE (2026-10-07)

### Droplet
- `ritchie` droplet ID 45487222, ams2, 188.226.140.165, reserved IP 188.166.129.145 (tonioriol.com A record points there). Ubuntu 16.04, PHP 7.1, Laravel Forge layout (`/home/forge/<site>`), sudo via `FORGE_PASSWORD` in `.env`.
- SSH port 22 to both DO and Hetzner is blocked from the home ISP (WARP does not help). Working access: relay pod `do-ssh-relay` (alpine/socat, ns `default`, label `purpose=do-migration`) → `kubectl port-forward pod/do-ssh-relay 2222:2222` (wrapped in a restart loop; it drops on large transfers) → `ssh -o HostKeyAlias=188.226.140.165 -p 2222 forge@127.0.0.1`. Use rsync `--partial` for big files. Delete the pod when done.

### Compromise findings
- All four Forge sites infected: bertomeuiglesias.com, boira.band (WP 4.7.5), lodrago.net (WP 4.7.3, renamed `__fb74a97` in May), tonioriol.com (`public/admin.php`, `public/index.php` backdoors).
- Cloaked Japanese SEO spam (served to Googlebot UA). Active: files modified 2026-10-07 14:15.
- Earliest traces 2026-05 in lodrago (wp-file-manager, fake plugins cacheengine / wp-compatibility-layer / click-widget). Rogue WP admins: lodragonet `bot`, `zibucyem`, `user_4076`, `root` (May 2026); boira `root` (2026-05-25). lodragonet has ~2.4k spam posts from 2026; legit content ≤2025 (author 3 `t20n` + older).
- Bertomeu markers: `index.php` loader including `.git/refs/remotes/origin/sym3.php`, 413-byte droppers (`file_get_contents` from `51la.lo61.xyz`), `.htaccess` allowlist, `.git/refs/remotes/.ent` wp-config injector.
- No extra system users, no new SSH keys, no root crontab seen; compromise appears to be at `forge` (web user) level. MySQL/Postgres/Redis/memcached/beanstalkd listen on 0.0.0.0.
- bertomeuiglesias.com git HEAD (bitbucket `tonioriol/web-bertomeu-iglesias`, last commit 2017) is clean; content in `db/texts.json`.

### Backups (local, verified md5)
`/Users/tr0n/Backups/ritchie-do-20261007/`: `boira.sql.gz`, `lodragonet.sql.gz` (full mysqldump), `boira-uploads.tgz`, `lodrago-uploads.tgz` (lodrago uploads contain planted `.php` — strip before reuse), `infected-webroots-EVIDENCE.tgz` (do not deploy).

## PLAN
1. Contain: DO snapshot, nginx 503 for the four sites on the droplet (keep `ace` until confirmed unused).
2. bertomeuiglesias.com: nginx+php container from clean git HEAD, Helm chart in `charts/`, Cloudflare tunnel route.
3. boira.band / lodrago.net: rebuild from cleaned DBs (drop rogue admins, spam posts, fake plugins) + uploads minus `.php`; static export or fresh WP — user decision pending.
4. tonioriol.com: Cloudflare redirect rule to GitHub.
5. Search Console cleanup; keep Google Workspace MX.
6. Destroy droplet, release reserved IP, remove `do-ssh-relay`.

## Next Steps
- [ ] User decisions: containment go-ahead; boira/lodrago keep as static vs WP; tonioriol.com redirect
- [ ] Execute plan above
