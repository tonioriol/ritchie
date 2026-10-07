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
- Entry: WordPress 4.7.x (2017) on lodrago.net, likely `wp-file-manager`; earliest traces 2026-05. Rogue WP admins: lodragonet `bot`, `zibucyem` (lodragosq@gmail.com), `user_4076`, `root`; boira `root`. All sites shared the `forge` user, so it spread to bertomeuiglesias.com and tonioriol.com.
- lodrago `dazzle-child/functions.php` backdoor contained credentials `oriol`/`sapdesus75` (likely the real WP password → treat as leaked) and recreated hidden admin `root`.
- No sign of root-level compromise (no new users/keys/root cron), but the box was destroyed anyway.
- forge SSH key (`SHA256:DeYgEqCFLwxSz8+Htv7T3VV2cebgY8rTzpQX3E+ZXLo`) not found on GitHub account keys or any repo deploy key. Bitbucket (repo `tonioriol/web-bertomeu-iglesias`) not checkable without Bitbucket creds.

## Backups (local)
`/Users/tr0n/Backups/ritchie-do-20261007/`: `boira.sql.gz`, `lodragonet.sql.gz` (raw, uncleaned dumps), `boira-uploads.tgz`, `lodrago-uploads.tgz` (contains planted .php), `infected-webroots-EVIDENCE.tgz` (hostile, never deploy), `server-config.tgz` (/etc/nginx, /etc/letsencrypt, openvpn-ca), `tunnel-config-before.json`, `dns-*-before.json`.

## Access notes (for future reference)
SSH (port 22) to both DO and Hetzner was blocked from the home ISP even with WARP; the cluster API worked. Workaround used: socat relay pod + `kubectl port-forward` (drops on large transfers; use rsync `--partial` in a retry loop). Relay pod deleted.

## Manual follow-ups for the user
- Search Console: submit sitemaps / remove lingering spam URLs for the three domains (410s will also drop them over a few weeks).
- Change the `oriol` password anywhere it is reused; check Bitbucket SSH keys for the forge key.
- Restrict the Google Maps API key embedded in lodrago.net to that domain.
- Decide on DO snapshot `acestream-proxy-backup-20251102` and whether to close the DO account.

## Commits
- ritchie: `a388c98` (findings), `efeff8a` (bertomeuiglesias.com), `6074519` (boira.band), `b92f252` (lodrago.net)
- site repos: bertomeuiglesias.com `57c92b6` (v1.0.0), boira.band `d3b16a7`, lodrago.net `2b2a675`
- workspace root: `5df05e0` (root `mise.toml` with KUBECONFIG, AGENTS.md)
