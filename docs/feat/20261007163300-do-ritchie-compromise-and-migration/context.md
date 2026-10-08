# DO ritchie compromise + migration of remaining sites to neumann

## TASK

bertomeuiglesias.com (and siblings) on the legacy DigitalOcean droplet `ritchie` served cloaked Japanese SEO spam. Contain, preserve data, rebuild the sites on the neumann cluster, destroy the droplet.

## STATUS: DONE (2026-10-07)

| Site | Now | Repo / chart |
|------|-----|--------------|
| bertomeuiglesias.com (+www) | static nginx on neumann, rendered from clean 2017 git HEAD (ca/es/fr) | `tonioriol/bertomeuiglesias.com`, `charts/bertomeuiglesias.com`, `apps/bertomeuiglesias.com.yaml` |
| boira.band (+www) | static WordPress export (15 pages, 351 MB incl. media) | `tonioriol/boira.band`, `charts/boira.band`, `apps/boira.band.yaml` |
| lodrago.net (+www) | static export of the 2-page (ca/en) homepage; all blog posts were spam | `tonioriol/lodrago.net`, `charts/lodrago.net`, `apps/lodrago.net.yaml` |
| tonioriol.com apex | Cloudflare dynamic redirect rule → `https://github.com/tonioriol` (301); DNS is a proxied `AAAA 100::` placeholder | — |
| ace.tonioriol.com | already on cluster (acexy); DO copy was unused | — |

- Repos are **public**: private repos fail Actions with "recent account payments have failed" (GitHub billing). Images on GHCR follow the adamnfinecupof.coffee flow (semantic-release → `ghcr.io/tonioriol/<repo>:X.Y.Z`, Image Updater).
- DNS: proxied CNAMEs to `85e6bc75-0025-4fc3-9341-d4e517fea614.cfargotunnel.com`, managed by hand (external-dns token only covers tonioriol.com). MX (Google Workspace) untouched. Tunnel routes added to both `charts/cloudflared/values.yaml` and the remote tunnel config.
- nginx in each image returns **410** for `*.php`, `/shop/`, WP endpoints and any unknown path, so Google drops the spam URLs.
- DO: droplet 45487222, its snapshots (`ritchie-compromised-20261007`, `last-after-moving-to-ritchie`) and reserved IP 188.166.129.145 deleted. Remaining DO resource: snapshot `acestream-proxy-backup-20251102` (5.49 GiB, of an earlier droplet) — left for the user to decide.

## Compromise findings
- Entry: WordPress 4.7.x (2017) on lodrago.net; earliest traces 2026-05. Most likely an authenticated admin login (reused/guessed password via wp-login/xmlrpc, no rate limit), not a plugin RCE: `wp-file-manager` is 8.0.4 (post-CVE-2020-25213) with files dated 2026-05-19, i.e. attacker-installed after access; random-named plugins likewise. Old revslider 5.3.1.5 / js_composer 5.0.1 / CF7 4.7 have no fitting unauthenticated RCE. Rogue WP admins: lodragonet `bot`, `zibucyem` (lodragosq@gmail.com), `user_4076`, `root`; boira `root`. All sites shared the `forge` user, so it spread to bertomeuiglesias.com and tonioriol.com.
- lodrago `dazzle-child/functions.php` backdoor contained credentials `oriol`/`sapdesus75` (likely the real WP password → treat as leaked) and recreated hidden admin `root`.
- No sign of root-level compromise (no new users/keys/root cron), but the box was destroyed anyway.
- forge SSH key (`SHA256:DeYgEqCFLwxSz8+Htv7T3VV2cebgY8rTzpQX3E+ZXLo`) not found on GitHub account keys or any repo deploy key. Bitbucket (repo `tonioriol/web-bertomeu-iglesias`) not checkable without Bitbucket creds.

## Backups (local)
`/Users/tr0n/Backups/ritchie-do-20261007/`: `boira.sql.gz`, `lodragonet.sql.gz` (raw, uncleaned dumps), `boira-uploads.tgz`, `lodrago-uploads.tgz` (contains planted .php), `infected-webroots-EVIDENCE.tgz` (hostile, never deploy), `server-config.tgz` (/etc/nginx, /etc/letsencrypt, openvpn-ca), `tunnel-config-before.json`, `dns-*-before.json`.

## Access notes (for future reference)
SSH (port 22) to both DO and Hetzner was blocked from the home ISP even with WARP; the cluster API worked. Workaround used: socat relay pod + `kubectl port-forward` (drops on large transfers; use rsync `--partial` in a retry loop). Relay pod deleted.

## Follow-up round (same day)
- DO: deleted snapshot `acestream-proxy-backup-20251102` too. Account now holds only 4 automatic weekly backups of the destroyed droplet (API refuses to delete backups; DO normally purges them after droplet deletion). October bill ≈ $2.15 + residual; $0 from November (was $9.81/mo).
- Google Maps key "Lodragonet" (GCP project `lodrago-net`) had `*` in allowed referrers → now only `https://lodrago.net/*`, `https://www.lodrago.net/*`.
- Search Console: OAuth credential `~/.config/gws/searchconsole-credentials.json` (scopes webmasters + siteverification, script `authorize-searchconsole.py`). Domain properties `sc-domain:` verified via DNS TXT for bertomeuiglesias.com and boira.band (lodrago.net already was). Sitemaps submitted for all three; spam sitemaps deleted from lodrago (`saiga.php?…`, `ammika.php?…`, `sitemap_880.xml`) and the old http bertomeu one. lodrago had 124 pages with impressions since July, nearly all `/details/<id>` spam → all return 410.
- Planted Google HTML verification files existed in boira (`google46d7b9f76827f940.html`, `google45b08388e2019454.html`) and lodrago (`google06ab4cc68fe53f56.html`): attackers may have verified ownership. The API can't list other owners; they lose ownership when Google re-checks the now-missing files. Owner should check Settings → Users and permissions.
- boira.band and lodrago.net now ship `sitemap.xml` + `Sitemap:` in robots.txt (v1.0.1).
- Image Updater only acts on apps listed in the `ImageUpdater` CR (`apps/argocd-image-updater.yaml`), not on Application annotations: static sites were never auto-updating (adamnfinecupof.coffee stuck at 1.0.0 vs 1.2.0). Added all four static sites; verified updates roll.

- Search Console UI (shared browser, account index `/u/1/` = tonioriol@gmail.com): every property (sc-domain bertomeuiglesias.com, boira.band, lodrago.net, and http://lodrago.net/) has a single owner, tonioriol@gmail.com, with no ownership history events and no leftover tokens. Security issues and manual actions: none on all three. Temporary removal (prefix) requests submitted for `https://lodrago.net/details/`, `/saiga.php`, `/ammika.php`; the 410s make the removal permanent.

- Bitbucket (2026-10-08, logged in via Google as tonioriol@gmail.com): personal workspace `tonioriol` had been deactivated for inactivity (scheduled for deletion); reactivated it. Its 11 private repos (2013-2017) were mirrored (`git clone --mirror` / `push --mirror`, all branches and tags; head/tag SHAs verified identical) to private, archived GitHub repos: `dotfiles-bitbucket`, `laravelicious-bitbucket` (renamed: the existing GitHub repos of those names diverge), `test-sessions-jaff` (source empty; README-only placeholder), `treballadors`, `setapp`, `manilicious`, `web-bertomeu-iglesias`, `lodragonet`, `boira`, `tonioriol.com`, `party-hard-faces`. Local mirrors kept in `~/Backups/bitbucket-20261008/` (425 MB). All 12 account SSH keys (including `Laravel Forge (ritchie)` `SHA256:DeYgEqCF…`, every one "Last used: Never") were deleted via API; the temporary scoped API token was revoked. Still a member of David Castellà's `dcastella` workspace (one repo, `euromod-app`); left untouched.

## Manual follow-ups for the user
- Change the `oriol` password anywhere it is reused.
- Confirm the 4 DO droplet backups disappear (Images → Backups in the DO UI otherwise).

## Commits
- ritchie: `a388c98` (findings), `efeff8a` (bertomeuiglesias.com), `6074519` (boira.band), `b92f252` (lodrago.net)
- site repos: bertomeuiglesias.com `57c92b6` (v1.0.0), boira.band `d3b16a7`, lodrago.net `2b2a675`
- workspace root: `5df05e0` (root `mise.toml` with KUBECONFIG, AGENTS.md)
