# TODOs

## Completed

- [x] Add CI in addon repo to build/push `ghcr.io/tonioriol/acestreamio` with immutable tags.
- [x] Install Argo CD Image Updater and configure it to auto-update the `acestreamio` Application without git commits.

## Open

- [ ] Rename `acestream` chart to `acestream-engine` for clarity (charts and docs).
- [ ] Investigate external-dns restart loop (44 restarts in 4d as of 2026-02-24).
- [ ] Monitor memory usage — 78% on single node `neumann-master1`.
- [ ] Clean up legacy static `list.js` from acestreamio if still present.
- [ ] fix proxy, it doesnt work now at all for movistar (bad ace hashes?)
- [ ] add slskd pod? https://www.reddit.com/r/Soulseek/comments/1r8flza/slskd_app_for_ios/
