# feat-acestreamio-logos-release-docs Acestreamio logos, release, and docs

## TASK

Update Acestreamio channel logos/posters, release a new addon image, and document the release process in this GitOps repo.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

/Users/tr0n/Code/ritchie

### RELEVANT FILES

* /Users/tr0n/Code/acestreamio/list.js
* /Users/tr0n/Code/acestreamio/process_logos.js
* /Users/tr0n/Code/acestreamio/scripts/regen-posters.js
* /Users/tr0n/Code/acestreamio/.github/workflows/release.yml
* /Users/tr0n/Code/ritchie/README.md
* /Users/tr0n/Code/ritchie/AGENTS.md

## PLAN

1) Identify channels with broken/missing logos in `list.js` and replace with working tv-logos URLs.
2) Regenerate posters using `scripts/regen-posters.js` to update `poster` paths deterministically.
3) Commit with a Conventional Commit (`fix:`) in the addon repo to trigger semantic-release and image build.
4) Verify release/tag created (SemVer) and image pushed to GHCR.
5) Document the release process in this GitOps repo (`README.md`, `AGENTS.md`).

## EVENT LOG
* **2026-02-04 09:34 - Replaced broken logos and regenerated posters (best-effort mapping)**
  * Identified channels with `posters/text_*.png` in `/Users/tr0n/Code/acestreamio/list.js` and traced failures to 404 or non-image logo URLs (e.g., GitHub blob URLs, google redirect URLs).
  * Pulled tv-logos catalog from `https://api.github.com/repos/tv-logo/tv-logos/contents/countries/spain?ref=main` and mapped Spanish channels (AMC, Caza y Pesca, Movistar M+ family) to working `raw.githubusercontent.com` logo URLs.
  * Ran poster regeneration: `node /Users/tr0n/Code/acestreamio/scripts/regen-posters.js` to update deterministic poster files and `poster` paths.
  * Applied fuzzy matching across tv-logos tree (`https://api.github.com/repos/tv-logo/tv-logos/git/trees/main?recursive=1`) for remaining text posters; accepted risk of mismatches and re-ran poster regeneration.

* **2026-02-04 09:50 - Corrected obvious mismatches by name and verified low-confidence mappings**
  * Fixed `RTL+ SPORT EVENT *` channels to `rtl-plus-de.png` and `SKY Sports LaLiga` to `sky-sports-main-event-hd-uk.png` in `/Users/tr0n/Code/acestreamio/list.js` based on name alignment.
  * Regenerated posters again to reflect updated logos.
  * Remaining text posters are due to missing/invalid logos (e.g., `https://www.mxgp.com/.../logo%20Motors%20TV.jpg` fetch failures or empty logo fields).

* **2026-02-04 09:50 - Released updated addon image via semantic-release**
  * Committed changes in addon repo with `fix: refresh channel logos` and pushed to `main`.
  * Release workflow (`/Users/tr0n/Code/acestreamio/.github/workflows/release.yml`) ran and published `v1.4.10`, building `ghcr.io/tonioriol/acestreamio:v1.4.10` for ArgoCD Image Updater rollout.

* **2026-02-04 09:53 - Documented release process in GitOps repo (pending push)**
  * Added release-process notes in `/Users/tr0n/Code/ritchie/README.md` and `/Users/tr0n/Code/ritchie/AGENTS.md` describing semantic-release flow and Image Updater deployment.
  * Push of docs commit was denied; changes remain local awaiting approval to push.

## Next Steps

- [ ] Decide whether to push the GitOps repo doc updates (`README.md`, `AGENTS.md`).
- [ ] Provide explicit logo URLs for remaining text-poster channels (e.g., Motors TV, RU channels) if you want them replaced.
