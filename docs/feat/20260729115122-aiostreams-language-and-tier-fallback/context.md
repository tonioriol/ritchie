---
title: "Add AIOStreams language sections and dynamic size tiers"
status: done
repos: [ritchie]
tags: [deployment]
related: [20260726235500-feat-aiostreams-deployment]
created: 2026-07-29
---

# Add AIOStreams language sections and dynamic size tiers

## TASK

**Goal:** Present Catalan, Spanish and English result sections in that order, re-enable 480p, return up to four dynamically size-spaced English rows per service and resolution for movies, regular series and anime, and prefix the three classified sections with stable language flags.

The current 12 ordered movie selectors intentionally omit sparse fixed-size tiers, which can reduce a populated resolution/provider block to one result. The approved replacement derives English representatives from each pool's maximum, half, quarter and eighth sizes, then fills missing slots from the best remaining rows. Catalan and Spanish each contribute at most one TorBox-first row for 2160p, 1080p, 720p and 480p across providers. English is explicit rather than language-neutral and retains separate TorBox and Real-Debrid blocks.

**Done when:** The complete saved configuration is atomically applied and read back; Catalan → Spanish → English ordering, provider fallback, 480p, disjoint language membership and `min(4, candidate count)` English pools are verified across movies, regular series and anime; all 11 latency gates pass; both tested adjacent pairs are non-empty and share at least one exact generated `bingeGroup`; and the formatter prefixes classified Catalan, Spanish and English rows with 🇦🇩, 🇪🇸 and 🇬🇧 respectively. The previously planned physical Stremio 1.12.1/Tizen 6 transition, 1Password recovery-template update and broader operator-guide refresh were not run after the user explicitly requested the live change be finished without further process; they are recorded as skipped rather than claimed as passing.

## SPEC

[spec.md](./spec.md) — approved config-only design for disjoint language sections, dynamic English size tiers, atomic rollout, shared-group plus mandatory Tizen autoplay gates, and complete rollback.

## FILES

- docs/feat/20260726235500-feat-aiostreams-deployment/context.md
- docs/feat/20260726235500-feat-aiostreams-deployment/spec.md
- docs/feat/20260726235500-feat-aiostreams-deployment/plan.md
- docs/STREMIO-AIOSTREAMS.md
- docs/feat/20260729115122-aiostreams-language-and-tier-fallback/context.md
- docs/feat/20260729115122-aiostreams-language-and-tier-fallback/spec.md
- docs/feat/20260729115122-aiostreams-language-and-tier-fallback/plan.md
- charts/aiostreams/values.yaml
- charts/aiostreams/templates/deployment.yaml
- charts/aiostreams/templates/externalsecret.yaml
- apps/aiostreams.yaml

## PLAN

**Plan:** [plan.md](./plan.md) — completed baseline, candidate, trust, amended automated rollout and language-flag work; preserves the intentionally skipped physical-client and recovery-template steps as unchecked historical gates.
**Cursor:** Complete — live selection and three-language formatter retained; durable reconstruction committed locally.
**Status:** done; no live mutation, 1Password edit, deployment or push remains authorized or pending

## LOG

### 2026-07-29 11:51 — Refinement request captured

- Why: The user observed that the representative-size selectors can return fewer than four rows in a resolution/provider block even when many candidates exist, because candidates above the lower size ceilings are not selected. The user also requested Catalan and Spanish results before the current general result set.
- What changed: Investigatory only. Created a dedicated task record; no AIOStreams, Stremio, Kubernetes, Cloudflare, 1Password or Git-managed runtime configuration changed.
- How (investigation): Queried the existing AIOStreams deployment record and specification. The prior rollout documents 12 ordered movie-only required expressions: one unconstrained selection plus three decreasing size ceilings per resolution/provider. Earlier selectors remove their picks from later candidates, but a capped selector contributes nothing when no remaining row fits its ceiling; sparse tiers therefore remain absent by design. The existing global order is service, cached state, resolution, size and quality; no global language preference was documented.
- How (action): Verified the new record belongs to the `ritchie` repository using `pwd` and `git rev-parse --show-toplevel`, both resolving to the repository root, then created this ledger under its existing task-record tree.
- Decisions: Preserve the current deployment task as historical truth and design this behavior change separately. Do not mutate the replacement-only live AIOStreams config until language matching, block semantics, backfill ordering, rollback and behavior gates are approved.
- Evidence: Existing deployment record reports current output of approximately 12–21 rows, four representative movie-size targets per resolution/provider when populated, TorBox before Real-Debrid, unchanged series/anime output, and 12 live required expressions. The reported failure mode is consistent with the deliberately documented sparse-tier omission behavior.
- Verification: Existing matching-record search returned no dedicated task for this refinement. Repository-location checks passed. No external or live mutation was performed.
- Commit: none.

### 2026-07-29 12:04 — Native selector capabilities and language constraints established

- Why: The fallback and language design must use behavior available in the pinned AIOStreams v2.31.1 image, preserve the existing general block, and avoid silently promising Catalan selection that the parser cannot identify.
- What changed: Investigatory only. Established the feasible native building blocks and two requirements that need user clarification; no live or tracked runtime behavior changed.
- How (investigation): Read the verified saved config at `/tmp/aiostreams-size-tiers-20260727T092508Z/readback-config.json` and inspected the locally extracted pinned distribution under `/tmp/aio-dist`. `parser/streamExpression.js` provides `language`, `keyword`, `negate`, `merge`, `slice`, `count`, `perGroup`, `pin` and `passthrough`. `streams/filterer.js` applies enabled required expressions in array order and removes IDs already kept from each later expression's input. Therefore a later unconstrained selector can draw distinct fallback rows after representative tiers miss, but the existing post-selector conjunctive limiter still needs deliberate treatment so it does not discard the earlier representative choices. Required-expression array order selects membership but does not itself establish final display order; output remains in the globally sorted order unless supported pin/sort behavior is used.
- How (action): None. Read-only source and saved-artifact inspection only.
- Decisions: Keep native expressions as the leading option; a fork or duplicate scraper presets remain unjustified. Do not assume that four language rows correspond to four resolutions: the verified config excludes 1440p and all resolutions below 720p, leaving exactly `2160p`, `1080p` and `720p`. Do not treat generic locale support as stream parsing: `utils/language-list.js` contains Catalan locale metadata, but the canonical stream `LANGUAGES` array and filename-language regexes omit Catalan. Spanish is canonical and matched by `spanish|spa|esp`; Catalan requires an explicit, source-backed filename/folder matching strategy or an AIOStreams change.
- Evidence: Verified config has `preferredResolutions=[2160p,1080p,720p]`, no language include/require/prefer/exclude arrays, global sort `service,cached,resolution,size,quality`, conjunctive limits `global=60,resolution=4,service=4`, and 12 required expressions. Saved movie output includes parsed Spanish rows such as `Dune Parte Dos ... Castellano ...` but no observed Catalan row. The pinned parser exposes no Catalan stream-language token or regex.
- Verification: Exact source reads confirmed required-selector exclusion by previously kept stream ID, case-insensitive exact matching in `language()`, and case-insensitive keyword matching over filename/folder/indexer/release-group in `keyword()`. No API, 1Password, cluster, Stremio or Git mutation occurred.
- Commit: none.

### 2026-07-29 12:32 — Four language resolutions clarified

- Why: The verified configuration only permits 2160p, 1080p and 720p, while the request called for four language-specific rows with one per resolution.
- What changed: Design requirement only. The user chose to re-enable 480p and use 2160p, 1080p, 720p and 480p as the four language-specific resolution slots.
- How (investigation): Compared the request with `preferredResolutions` and `excludedResolutions` in the verified saved config. This established that 480p is currently excluded and must be deliberately admitted for the new language sections.
- How (action): No live action. Recorded the selected interpretation for the design.
- Decisions: Each Catalan and Spanish section targets at most one distinct row at each of 2160p, 1080p, 720p and 480p. Whether 480p should also participate in the existing general per-service blocks remains to be defined rather than inferred.
- Evidence: User selected: “Re-enable 480p and use one result each at 2160p, 1080p, 720p, and 480p.”
- Verification: Requirement captured verbatim; no config, API, 1Password, cluster or Stremio mutation occurred.
- Commit: none.

### 2026-07-29 12:35 — Existing general section redefined as English

- Why: The user clarified that 480p should also be included for the existing results and chose to make that section explicitly English rather than language-neutral.
- What changed: Design requirement only. The target output is now three language sections in this order: Catalan, Spanish, then English. Each section targets 2160p, 1080p, 720p and 480p.
- How (investigation): Explained that the current general section is not English-only; it accepts any detected or unknown language. Compared three possible interpretations for 480p scope.
- How (action): No live action. Recorded the user's selected interpretation.
- Decisions: Replace the language-neutral general section with an English-only section and add a 480p block. For the English movie section, preserve the existing representative-size behavior and improve it so each `(service, resolution)` block backfills to four distinct rows when at least four English candidates exist. Catalan and Spanish remain separate leading sections with one result per resolution when found.
- Evidence: User selected: “Change the normal section to English-only and include 2160p, 1080p, 720p, and 480p blocks.”
- Verification: Requirement captured; no config, API, 1Password, cluster or Stremio mutation occurred.
- Commit: none.

### 2026-07-29 12:59 — Dynamic pool-relative size tiers proved in pinned AIOStreams

- Why: The user questioned why representative tiers should remain movie-only and proposed deriving choices dynamically from each result pool, potentially halving from its largest size. A dynamic policy could serve movies and episodes without hard-coding inappropriate shared byte thresholds.
- What changed: Design understanding only. Confirmed that pinned AIOStreams v2.31.1 can calculate dynamic size tiers natively; no fork is required and no live behavior changed.
- How (investigation): Inspected `parser/streamExpression.js` from `ghcr.io/viren070/aiostreams:v2.31.1`. The expression engine enables addition, subtraction, multiplication, division, square root, rounding, conditionals and comparisons. It adds statistical functions including `min`, `max`, `mean`, `sum`, `percentile`, quartiles, median, variance, standard deviation, range, mode, skewness and kurtosis. `values(streams, 'size')` extracts numeric sizes, while `size`, `slice`, `merge` and `negate` can select distinct tier representatives and append unselected fallback rows.
- How (action): Built an isolated temporary parser test and ran it inside the pinned image with dummy non-secret `BASE_URL` and `SECRET_KEY` values. The host-side test first failed because `/tmp/aio-dist` does not include the image's `expr-eval` dependency; rerunning inside the image resolved that environment-only failure. Tested a selector that chooses the first sorted row, then the first row at or below max/2, max/4 and max/8, merges distinct picks, appends remaining rows in existing sort order, and slices the result to four.
- Decisions: Dynamic multiplicative tiers are now the leading candidate because the same rule adapts to movies, regular episodes and anime episodes. It preserves deliberate size spread when the pool supports it and satisfies the original fallback request when it does not. The eventual expression should compute the reference maximum from the intended service/resolution/language pool and preserve cached-first semantics rather than accidentally allowing an unrelated uncached outlier to set the scale.
- Evidence: Pinned-image output: dense clustered pool `[30,29,28,27,26,25]` selected `[30,29,28,27]` via fallback; spread pool `[30,20,15,10,7,5,2]` selected `[30,15,7,2]`; three-row pool `[30,8,7]` selected all three; one-row pool `[30]` selected it. Thus the selector returns exactly `min(4, candidate count)` distinct rows while preferring approximately halved sizes where available.
- Verification: The expression parsed and executed successfully in the exact deployed v2.31.1 image. This proves primitive feasibility only; exact language/service/resolution grouping, cached reference-pool semantics, display ordering and live response behavior remain design and rollout gates.
- Commit: none.

### 2026-07-29 13:10 — Autoplay investigated; default release-group matching is brittle

- Why: After approving dynamic English tiers for movies, series and anime, the user reported unreliable next-episode autoplay and correctly suspected that filtering might remove the stream Stremio needs to continue a release. Autoplay behavior is now a design blocker for episodic filtering.
- What changed: Investigatory only. Established Stremio's matching contract, AIOStreams' generated binge-group policy, current adjacent-episode overlap and a separate recent Android TV client regression. No live configuration changed.
- How (investigation): Official Stremio Addon SDK stream documentation states that streams with identical `behaviorHints.bingeGroup` are chosen automatically for binge watching; the next episode must contain the same group. Read pinned AIOStreams `transformers/stremio.js` and `transformers/utils.js`: AIOStreams generates a new group after filtering rather than preserving the upstream addon's group. The live saved config has `autoPlay: null`, so v2.31.1 defaults to `matchingFile` with `resolution`, `quality` and `releaseGroup`; the emitted form is `com.aiostreams.viren070|<resolution>|<quality>|<releaseGroup>`. Fetched adjacent episodes for Breaking Bad S01E01/E02 and Attack on Titan S01E01/E02 through the encrypted route into mode-0700 `/tmp/aiostreams-autoplay-audit-20260729T110808Z`, then compared exact group sets without printing route credentials.
- How (action): None. A first adjacent-episode request using `xh` returned 404; the same stored route succeeded with the rollout's verified `curl` construction, proving this was a client/path-handling issue rather than stale credentials. No server mutation followed.
- Decisions: Do not apply dynamic episodic filtering until autoplay is explicitly protected. The current 12 representative-size selectors did not alter series/anime because every expression returns all streams when `queryType != 'movie'`; the original rollout also proved exact before/after non-movie equality. Therefore those movie selectors did not directly cause the reported regression. Earlier global result limits can still remove the next episode's matching group, and the default `releaseGroup` component is independently brittle because parser output varies or is missing between episodes. Evaluate a more stable AIOStreams autoplay identity as part of this design rather than relying on Stremio to infer filenames.
- Evidence: Breaking Bad E01 had 22 streams/19 unique groups, E02 23/19, with 13 unique-group overlaps; 16/22 E01 rows had an exact next-episode group. Attack on Titan E01 had 18 streams/14 groups, E02 16/10, with 8 unique-group overlaps; 11/18 E01 rows matched. Simulating AIOStreams identities from final rows: default `resolution+quality+releaseGroup` covered `16/22` and `11/18`; removing only `releaseGroup` (`resolution+quality`) covered `22/22` and `16/18`; `resolution` alone covered `22/22` and `18/18`. Missing examples were release groups such as `XEBEC`, `HONE`, `JPN-ENG`, `CBM` and `CameEsp` absent from the next episode's retained rows.
- Verification: Official SDK evidence and pinned source agree that matching is exact on generated `bingeGroup`. Current live adjacent responses contained non-empty groups. Independent Stremio bug reports from late 2025/2026 also report Android TV 1.8.x returning to the stream list while 1.6.12 works, so client version must be checked before attributing every failure to AIOStreams. No API write, 1Password mutation, cluster change or Stremio account mutation occurred.
- Commit: none.

### 2026-07-29 13:21 — Observed client identified as Samsung TV

- Why: The autoplay diagnosis must separate server-side binge-group misses from platform-specific Stremio regressions.
- What changed: Investigation scope only. The user confirmed the observed failures occurred on a Samsung TV and has not yet tested Android TV.
- How (investigation): Asked which Stremio platform/version exhibited the failure after finding Android TV 1.8.x bug reports.
- How (action): None.
- Decisions: Do not use the Android TV regression as an explanation for the observed Samsung failure. Continue treating AIOStreams' brittle default `resolution+quality+releaseGroup` identity as a demonstrated server-side risk, while obtaining the Samsung Stremio app/version and exact failure behavior before claiming it is the sole root cause.
- Evidence: User: “I tested it in a Samsung TV. I'm not sure about the Android TV. I have not yet tested it there.”
- Verification: No runtime or external mutation occurred.
- Commit: none.

### 2026-07-29 13:24 — Samsung symptom compared with known Tizen bug

- Why: The user described the Samsung behavior as advancing to the next episode page without starting playback. That symptom must be compared with known client defects before attributing it solely to AIOStreams.
- What changed: Investigation conclusion only; no live behavior changed.
- How (investigation): Read the official Stremio Addon SDK stream response documentation and Stremio bug `#956`. The SDK confirms that Stremio implicitly selects the next stream only when the next episode exposes an identical `behaviorHints.bingeGroup`. Issue `#956` documents a Samsung/Tizen client bug where autoplay works for two episodes and then remains on a black screen; another reporter described returning to the links menu after two episodes. The issue was closed as fixed in January 2025, although its original reporter said the problem persisted after the update.
- How (action): None.
- Decisions: Treat the server and client as independent risk layers. The user's “next episode page but not playing” symptom is compatible with no matching binge group and differs from the issue's primary black-screen symptom, so the demonstrated AIOStreams identity misses remain actionable. Do not promise that a server-side group change will cure every Samsung/Tizen autoplay defect; verify on the user's installed Samsung app version and, ultimately, on-device after rollout.
- Evidence: Official SDK wording: when the next episode has a stream with the same `bingeGroup`, Stremio should select it implicitly. Live adjacent-episode analysis already proves that `6/22` Breaking Bad and `7/18` Attack on Titan current E01 rows lack an exact E02 group under the default AIOStreams identity. Known Samsung issue `#956` used Theater `1.3.0` on Tizen `6.5`, with reports around October 2024–January 2025.
- Verification: Research was read-only; no API, account, cluster, 1Password or Stremio mutation occurred.
- Commit: none.

### 2026-07-29 13:27 — Samsung autoplay currently works; prior failure not reproducible

- Why: A client-version check was requested to distinguish an old Samsung/Tizen defect from an AIOStreams binge-group miss.
- What changed: Investigation conclusion only. The user retested before providing the version and reported that autoplay works now although it failed yesterday.
- How (investigation): No configuration or deployment changed between the reported failure and successful retest. Existing live adjacent-episode analysis remains valid but proves risk, not that the user's latest transition must fail.
- How (action): None.
- Decisions: Do not label autoplay currently broken and do not expand this refinement into an incident fix without a reproducible title/episode/selected-row case. Preserve autoplay as an explicit design constraint: any episodic language/tier change must not reduce adjacent-episode binge-group overlap and should be tested on Samsung TV. A proactive simplification of AIOStreams' default matching identity remains an optional design choice, not an emergency mutation.
- Evidence: User: “I just tested it and now works, yesterday didn't.” Live config is unchanged throughout this investigation. Current server audit shows some rows have no exact next-episode group while many do, which naturally permits title- and selected-row-dependent results.
- Verification: Successful current behavior was observed by the user on the actual Samsung TV. No API write, account update, cluster operation or 1Password mutation occurred.
- Commit: none.

### 2026-07-29 13:28 — Samsung client version confirmed

- Why: The known Samsung bug involved an old Theater client, so the installed version was needed to assess relevance.
- What changed: Investigation metadata only. The tested client is Stremio `1.12.1` on Tizen `6`.
- How (investigation): User checked the Samsung app version after reproducing successful autoplay.
- How (action): None.
- Decisions: The historical Theater `1.3.0`/Tizen `6.5` issue is not a strong explanation for the current `1.12.1` client. Keep the on-device regression gate because Samsung behavior can still vary, but base the design primarily on the official exact-`bingeGroup` contract and measured adjacent-episode overlap.
- Evidence: User reported: “I'm on 1.12.1 on Tizen 6.”
- Verification: Client version and successful current autoplay are user-observed; no system mutation occurred.
- Commit: none.

### 2026-07-29 13:49 — Language rows are provider-neutral and TorBox-first

- Why: The language sections could either add one row per resolution overall or duplicate each language/resolution across TorBox and Real-Debrid, substantially changing output size.
- What changed: Design requirement only. Catalan and Spanish each contribute at most one row for 2160p, 1080p, 720p and 480p across all providers, for at most eight leading language rows total.
- How (investigation): Compared provider-neutral and per-provider interpretations against the user's requested short output and existing TorBox-first policy.
- How (action): None.
- Decisions: For each language/resolution, choose the first candidate under the existing service-first order, so TorBox wins when available and Real-Debrid is fallback. Do not emit a second language row merely to represent the other provider. English remains the detailed section with up to four dynamic-size results per `(service, resolution)` block.
- Evidence: User selected: “One row per resolution total for each language; choose the best TorBox-first result (8 language rows maximum total).”
- Verification: Requirement captured; no live or external mutation occurred.
- Commit: none.

### 2026-07-30 10:59 — Config-only design approved and specification committed

- Why: Source inspection proved the pinned image can implement language ordering, limiter isolation and dynamic pool-relative sizing without a fork, but Catalan is absent from its canonical stream-language parser. The user needed a deliberate choice between a local heuristic, an upstream contribution and a maintained custom image before implementation planning.
- What changed: **Investigatory/design only.** The user approved a saved-configuration-only design and then approved the written specification. The target behavior is now Catalan → Spanish → English across 2160p, 1080p, 720p and 480p; at most one TorBox-first Catalan and Spanish row per resolution across providers; and up to four dynamic English rows per `(service, resolution)` pool for movies, regular series and anime. No AIOStreams, Stremio, Kubernetes, Cloudflare, 1Password or provider state changed.
- How (investigation): Compared three approaches against pinned v2.31.1 source: native classification plus selectors and limiter passthrough; regex scoring for every language; and a source fork adding canonical Catalan. The parser's language regex table and canonical enum showed that a fork would be a small parser feature and would normalize structured `ca`/`cat` metadata, but would not make upstream addons discover more releases. The user selected the heuristic only and explicitly rejected an AIOStreams source change. Further source reads established that preferred expressions assign the first matching expression index before sorting; the sorter negates that index, so `streamExpressionMatched` must be descending for index 0 to display first. Named ranked regex patterns match filename/folder fields and are consumable through `regexMatched(...)`, allowing one bounded Catalan classifier to drive both membership and precedence. The limiter honors `passthrough(..., 'limit')`, while the global limit remains a safety cap.
- How (action): Presented and received approval for three design sections: selection architecture; dynamic English sizing and fallback; and secure rollout, acceptance, autoplay and rollback. Wrote `spec.md`, scanned it for placeholders, conflict markers and secret-like material, ran Git whitespace validation, and corrected the sort direction found during self-review. Staged and committed only `spec.md`; the pre-existing untracked task ledger remained outside that commit.
- Decisions: Use no fork and pursue no upstream source change. Catalan uses tightly bounded, filename/folder-only full-name and uppercase `CAT` markers with subtitle exclusions. Spanish uses native parsing plus bounded full-word aliases; English requires native parsed English. Candidate sets are explicitly disjoint with Catalan, then Spanish, then English precedence. Dynamic English sizing uses cached candidates as the reference set when available, chooses maximum/half/quarter/eighth representatives, then backfills to exactly `min(4, candidate count)` from existing order. Keep the current autoplay identity unchanged and enforce baseline-relative adjacent-episode overlap plus a Samsung/Tizen on-device gate.
- Evidence: The pinned parser proof selected `[30,15,7,2]` from a spread pool and backfilled `[30,29,28,27]` from a clustered pool. The designed maximum is 8 leading language rows plus 32 English rows, totaling 40 under the global limit of 60. The specification contains 478 lines and was committed as the only file in commit `72ea23e` (`docs: define AIOStreams language tiers`).
- Verification: `git diff --check` passed; scans found no placeholders, merge markers or secret-like URL/header assignments. `git show --name-only HEAD` listed only `docs/feat/20260729115122-aiostreams-language-and-tier-fallback/spec.md`. The user explicitly approved the written specification. Live-state mutation remains zero.
- Commit: `72ea23e` — `docs: define AIOStreams language tiers`.

### 2026-07-30 12:21 — Four-task implementation plan generated and pinned mechanism proved

- Why: The approved specification required an executable plan that secured an immediate rollback point, proved the complete candidate before a live write, enforced language/pool/latency/autoplay gates, and persisted recovery state only after success.
- What changed: Planning documents only. Added `plan.md` with four sequential tasks and moved the execution cursor to Task 1. No AIOStreams, Stremio, Kubernetes, Cloudflare, 1Password, provider or image state changed.
- How (investigation): Final plan review found that ranked stream expressions execute before the global sorter, so an earlier compact prototype that used `slice(..., 0, 1)` while assigning tier tags could not guarantee the approved highest-priority row. Reworked the mechanism so 32 pool-unique ranked tags identify the maximum and half/quarter/eighth threshold sets without choosing final membership; eight English required selectors then choose distinct representatives and backfill after the global sort. Three preceding ranked expressions provide disjoint `C`, `S` and `E` language sets.
- How (action): Wrote concrete mode-0700 baseline, 55-request timing matrix, Catalan live-positive discovery, adjacent-episode overlap, deterministic candidate generator, pinned-image synthetic validator, complete-config write/readback, response audit, latency rejection, Samsung/Tizen gate, rollback, 1Password template, operator documentation, historical supersession and local-commit steps. Included exact scripts and expected outputs rather than placeholders.
- Decisions: Use three ranked regexes, 35 ranked stream expressions, three preferred stream expressions and 16 required stream expressions. Require the documented 12-selector baseline before generation. Keep `autoPlay` and `resultLimits` unchanged. Reject the first paired latency failure rather than perform an optional second live config cycle. Preserve no-write status until Task 3 passes the external-mutation confirmation gate.
- Evidence: The complete generated candidate contains 54 stream expressions totaling 32,110 characters; the longest is 1,464 characters, within pinned v2.31.1 limits of 200 expressions, 50,000 total characters and 3,000 characters per expression. Exact-image validation passed 18 regex cases, eight language/precedence/480p/provider/passthrough cases and five dynamic-pool cases, including reversed pre-sort input, cached-reference behavior, missing sizes, sparse pools and exact unique `min(4, candidate count)` output.
- Verification: Every embedded Python block compiled; the embedded generator reproduced the expected counts and limits from the verified saved-config artifact; the embedded JavaScript validator passed inside `ghcr.io/viren070/aiostreams:v2.31.1`; placeholder/conflict and whitespace checks passed after self-review corrections. Live-state mutation remains zero.
- Commit: pending with `plan.md` and this ledger update.

### 2026-07-30 12:42 — Task 1 read-only rollback and runtime baseline captured

- Private work directory: `/tmp/aiostreams-language-tiers-20260730T103840Z` (mode 0700).
- Baseline config SHA-256: `4f6a4862ef2f22fc4013b502c5f279e65ec1aea91fa8c377ff40537e5fb9924a`.
- Endpoint/sample evidence: 11 representative endpoints; 55 successful timed responses with `streamData`; 158 first-response rows classified (Catalan 6, Spanish 14, English 25).
- Catalan-positive evidence: 6 rows in sample `alcarras`.
- Adjacent-pair overlap: `breakingbad` 22/23 rows, 19/19 unique groups, 13 shared groups, E01 coverage 0.727273; `attackontitan` 17/14 rows, 14/11 unique groups, 10 shared groups, E01 coverage 0.705882.
- Latency medians (seconds): `matrix` 2.454915; `godfather` 2.756854; `dune2` 3.125734; `alcarras` 0.622151; `el47` 0.677976; `casaenflames` 0.278836; `creatura` 0.294913; `breakingbad-e01` 1.733256; `breakingbad-e02` 1.604964; `attackontitan-e01` 1.067365; `attackontitan-e02` 0.960206.

### 2026-07-30 12:12 — Task 2 complete candidate proved offline

- Private artifacts: generated under `/tmp/aiostreams-language-tiers-20260730T103840Z` (mode 0700); candidate SHA-256 `cde1f81c0bde3c6c6d9925de07a3b44f0549998363f7cc5e863003950cce6f5e`; frozen replacement payload SHA-256 `87348007dcdf559f2be9bc3acf70820a24c3c83aedb07eac71c4de5c78fc4dea`.
- Seven-field proof: only `preferredResolutions`, `excludedResolutions`, `sortCriteria`, `rankedRegexPatterns`, `rankedStreamExpressions`, `preferredStreamExpressions`, and `requiredStreamExpressions` changed; every other top-level field matched the Task 1 baseline byte-for-byte after canonical projection.
- Candidate limits: 3 regex patterns; 35 ranked, 3 preferred, and 16 required expressions; 54 total expressions; 32,110 characters total; 1,464-character maximum; maximum 40 results.
- Offline fixtures: 18 regex cases; 8 language/precedence/480p/provider/passthrough cases; 5 dynamic-pool cases (spread, clustered, sparse, missing-size, cached-reference); all expression arrays parsed.
- Pinned-image proof: `ghcr.io/viren070/aiostreams:v2.31.1` returned `{"regexCases":18,"languageCases":8,"poolCases":5,"expressionArraysParsed":true}` against read-only synthetic fixtures.
- Verification: generator compilation, baseline invariance comparison, semantic assertions, exact seven-field enumeration, frozen payload construction, and local hash inspection passed. Zero live AIOStreams requests or mutations occurred; 1Password, Kubernetes, Cloudflare, Stremio, providers, images, and credentials were not read or changed.

### 2026-07-30 12:51 — Task 3 write rejected and exact rollback verified

- Write/readback: The single approved candidate PUT used frozen payload SHA-256 `87348007dcdf559f2be9bc3acf70820a24c3c83aedb07eac71c4de5c78fc4dea` for candidate SHA-256 `cde1f81c0bde3c6c6d9925de07a3b44f0549998363f7cc5e863003950cce6f5e`; the server returned HTTP 400 with an empty body, so candidate readback was unavailable and the PUT was not repeated.
- Rollback/state: The complete rollback function was defined and syntax-checked before the write. Its PUT succeeded, immediate readback matched the pre-change configuration semantically, and restored SHA-256 `4f6a4862ef2f22fc4013b502c5f279e65ec1aea91fa8c377ff40537e5fb9924a` exactly. The live candidate is not retained.
- Automated gates: Post-change capture stopped at the failed write gate (`0/55` responses and `0/55` timings). Language/order/uniqueness/provider/pool/bounds and movie/series/anime membership audits were therefore not run; no post-change language, provider, pool, 480p or bounds claim is made.
- Latency comparison: Post medians were not measured. Baseline median → threshold seconds: `matrix 2.454915→2.954915`, `godfather 2.756854→3.256854`, `dune2 3.125734→3.625734`, `alcarras 0.622151→1.122151`, `el47 0.677976→1.177976`, `casaenflames 0.278836→0.778836`, `creatura 0.294913→0.794913`, `breakingbad-e01 1.733256→2.233256`, `breakingbad-e02 1.604964→2.104964`, `attackontitan-e01 1.067365→1.567365`, `attackontitan-e02 0.960206→1.460206`; all 11 comparisons were skipped after rollback.
- Adjacent overlap/Tizen: Post overlap was not measured. Baseline first-row coverage/shared groups remained `breakingbad 0.727273/13` and `attackontitan 0.705882/10`; both comparisons were skipped after rollback. The Stremio `1.12.1`/Tizen `6` transition was not reached and is not pending against the restored pre-change runtime.

### 2026-07-30 14:39 — Local least-privilege trust wiring

- Root cause/local fix: the rejected ranked-regex candidate is not reissued; the existing saved-user UUID is mapped from the external secret to `TRUSTED_UUIDS`, trusting only that configuration without broad regex access or committed secret material.

### 2026-07-30 15:52 — Post-trust transaction contract approved

- Review/correction: exact pinned v2.31.1 source proves `TRUSTED_UUIDS` maps to `userLimits.trusted.uuids`, while updates and raw reads overwrite `trusted` from that runtime setting. The chart render, least-privilege scope, UUID privacy and unchanged regex-access policy pass local validation, but the original candidate equality and rollback hash would falsely fail against their frozen `trusted: false` inputs after deployment.
- Approved transaction: after a separately approved deployment, require ExternalSecret and Deployment readiness plus raw `trusted: true`; freeze a fresh complete rollback source that differs from the original only in `trusted`; retain exact full semantic/hash rollback against that fresh snapshot; compare candidate readback after removing only `trusted` while separately requiring it to be true; and make every rollback stage fail closed. Push/deployment and the second candidate PUT remain separately gated and have not occurred.

### 2026-07-30 16:32 — Transaction failure paths hardened after final review

- Review fixes: Task 3 now materializes and checks every secret-bearing projection/digest instead of using unchecked process substitutions, never prints complete-config diffs, returns from response-capture failures to the rollback wrapper, fixes the English-ID uniqueness assertion, requires an unwaived successful Tizen transition, and fail-closes runtime-summary generation.
- Rollback verification: a restore is successful only after exact complete semantic/hash equality, one validated representative response for all 11 endpoints, and passing adjacent-episode group checks. The Reloader comment and global read-only Kubernetes exception now match the approved trust rollout. All changes remain local; no push, deployment, cluster request, 1Password edit or live PUT occurred.

### 2026-07-30 16:49 — Final evidence gates made explicit

- Final review fixes: every post-write evidence display now fails through the rollback wrapper; Tizen evidence is structured and must explicitly record a passing Stremio `1.12.1`/Tizen `6` transition; and the runtime summary includes all 11 latency entries and revalidates five baseline samples, five post samples and `accepted: true` for each endpoint.
- Completion semantics: an on-device failure always triggers verified rollback and blocks completion/candidate retention. It may be classified as a separate client issue only after rollback; classification cannot waive this rollout's acceptance criteria. No external action occurred.

### 2026-07-31 15:12 — Trusted candidate accepted, anime ratio gate failed, exact rollback verified, acceptance amended

- Why: The user approved exactly one further complete candidate PUT, all automated audits and immediate verified rollback on failure. The saved user was already trusted through signed GitOps revision `5139f1772dffdb7de8283b4cc03a58ee78c9f46c`, and the frozen candidate, payload and trusted rollback hashes were respectively `cde1f81c0bde3c6c6d9925de07a3b44f0549998363f7cc5e863003950cce6f5e`, `87348007dcdf559f2be9bc3acf70820a24c3c83aedb07eac71c4de5c78fc4dea` and `cf553a877a4a8a35b8db7e5788ff045b5f3e664b0bef64c9320bf407585fc2f6`.
- What changed: The one approved PUT was accepted and read back with `trusted: true` and exact equality outside server-owned `trusted`. All 11 endpoints returned five valid responses; language/order/provider/pool/bounds, movie/series/anime membership and all 11 median-latency gates passed. The old autoplay comparator then rejected Attack on Titan because coverage changed from `13/17` (`0.7647058824`) to `2/3` (`0.6666666667`) even though one exact generated group remained shared. The transaction immediately restored the complete trusted baseline. No candidate remains active.
- How (investigation): All five candidate samples were stable: Attack on Titan episode 1 had three rows, episode 2 had two rows, two first-episode rows matched the next episode and one unique group was shared. The retained Spanish 1080p row changed from Real-Debrid `CameEsp` in episode 1 to TorBox `LuisHDZ` in episode 2 because the approved Spanish selector is TorBox-first; both TorBox and Real-Debrid English 720p rows retained `Me7alh`. Breaking Bad improved from baseline coverage `16/22` to `16/18` with ten shared groups. Every selected row retained a generated `bingeGroup`; this was a release-group continuity ratio issue, not missing metadata.
- How (action): The live mutation was exactly one complete `PUT /api/v1/user`. On comparator failure, the pre-defined rollback submitted the complete trusted baseline, required a successful response and `trusted: true`, compared canonical complete configs and exact SHA-256, validated one response for all 11 endpoints, and reran adjacent-group checks. Rollback reported `exact config, hash, 11 responses, and adjacent groups verified`. The temporary in-cluster 1Password Connect port-forward used only to replace broken desktop CLI authentication was stopped; it did not edit 1Password. No 1Password document edit, push, image build, restart or other deployment occurred.
- Decisions: A proposed bilingual Spanish/English overlap was approved provisionally, then rejected during plan self-review because `streamExpressionMatched` would display the additional bilingual English-pool row as Spanish, creating two Spanish 1080p rows and violating the strict one-row slot. The final approved correction keeps the original disjoint `C → S → E` sets, strict one-row Catalan/Spanish slots and TorBox-first provider behavior. Server autoplay acceptance now requires non-empty adjacent responses and at least one exact shared generated `bingeGroup` for both regular series and anime; row coverage remains mandatory reported evidence but is not independently rejecting. The real Stremio `1.12.1`/Tizen `6` playback transition remains mandatory and authoritative; failure still triggers exact rollback.
- Evidence: Candidate automated output reached `response audit: language/order/provider/pool/bounds PASS`, movie/series/anime membership PASS and `latency: 11/11 endpoint medians PASS`. Post-candidate adjacent evidence was Breaking Bad `18/16` rows, `12/10` unique groups, ten shared groups and `0.8888888889` coverage; Attack on Titan `3/2` rows, `2/2` unique groups, one shared group and `0.6666666667` coverage. Rollback evidence was Breaking Bad `22/23` rows, 14 shared groups and `0.7272727273` coverage; Attack on Titan `18/15` rows, nine shared groups and `0.7777777778` coverage.
- Verification: The amended `spec.md` restores disjoint selectors and changes only the server acceptance rule. `plan.md` adds Task 2A with RED/GREEN tests for lower-coverage-with-overlap acceptance, no-overlap rejection and empty-response rejection; it re-proves byte-identical candidate/payload hashes, rechecks the trusted rollback hash, and hard-stops for new approval. `git diff --check` passed. Only `spec.md`, `plan.md` and this `context.md` are intentionally modified; no implementation or further live PUT is authorized.
- Commit: none; the user requested written specification and plan review before implementation, and no push is authorized.

### 2026-07-31 15:21 — Amended autoplay gate proved offline and unchanged candidate re-frozen

- Why: The user approved only Task 2A's offline proof and required a stop for separate approval before any further live PUT.
- What changed: Created private temporary comparator tests and a minimal comparator in the existing mode-0700 work directory, replayed the retained baseline/candidate autoplay evidence, regenerated the unchanged candidate and payload, reran the exact pinned-image selector proof, and reverified the trusted rollback source. No saved configuration or external system changed.
- How (TDD): The three tests first errored because `compare-autoplay.py` did not exist. After implementing the approved condition, all three passed: lower coverage with an exact shared group is accepted and reported; zero shared groups and an empty adjacent response each fail closed.
- Evidence: Retained Breaking Bad evidence passed with `18/16` rows, ten shared groups and coverage improving from `16/22` to `16/18`. Retained Attack on Titan evidence passed with non-empty `3/2` rows and one shared group while preserving the non-blocking coverage report from `13/17` to `2/3`. Candidate config SHA-256 remains `cde1f81c0bde3c6c6d9925de07a3b44f0549998363f7cc5e863003950cce6f5e`; candidate payload SHA-256 remains `87348007dcdf559f2be9bc3acf70820a24c3c83aedb07eac71c4de5c78fc4dea`; trusted rollback SHA-256 remains `cf553a877a4a8a35b8db7e5788ff045b5f3e664b0bef64c9320bf407585fc2f6` with `trusted: true`.
- Verification: Fields outside server-owned `trusted` and the seven intended policy fields remain identical to the trusted rollback source. The local pinned image resolved to digest `sha256:26d93653c3a5d0835db9189d6aca21d05614e68107c4d4a3ec7196b60c88c3bc` and passed 18 regex cases, eight disjoint-language cases, five pool cases and complete expression parsing. The first validator invocation failed before container startup because the restricted shell PATH omitted `/usr/local/bin`; using the resolved OrbStack CLI path reran the unchanged command successfully. No AIOStreams API call, cluster request, 1Password edit, deployment, commit or push occurred.
- Decision: Task 2A is complete. All earlier PUT approvals are consumed; Task 3 remains blocked pending a new explicit approval for exactly one complete candidate PUT, amended automated gates and immediate verified rollback on any failure.
- Commit: none.

### 2026-07-31 15:31 — Final transaction reduced to the approved automated gates

- Why: The user objected that a saved-configuration update had expanded into excessive process and asked for one final apply, verification and rollback only on actual failure.
- What changed: **Implemented transaction correction.** The existing private `run-approved-transaction.sh` wrapper was narrowed to the already approved behavior: one complete candidate PUT, immediate exact readback outside server-owned `trusted`, representative response and latency audits, and the tested adjacent-episode shared-group comparator. No candidate or selector field changed.
- How (investigation): Syntax review found the wrapper still contained the superseded inline coverage-ratio rejection even though `compare-autoplay.py` had already proved the amended rule. A separate heredoc edit first failed with `SyntaxError: EOF while scanning triple-quoted string literal` because the outer delimiter collided with an inner `PY`; a unique outer delimiter fixed the edit. `/bin/zsh -n run-approved-transaction.sh` then passed.
- How (action): Replaced the stale ratio check with `python3 audit-autoplay.py after`, `python3 compare-autoplay.py baseline-autoplay.json after-autoplay.json`, and `jq -e 'all(.[]; .accepted == true)' autoplay-comparison.json`. The wrapper still defined rollback before the PUT and invoked it only if a post-write gate failed.
- Decisions: Do not restart containers, reinstall the addon, modify the candidate, perform an intermediate write, or repeat a failed candidate write. The physical Tizen transition and recovery-template/operator-documentation sequence from the earlier enterprise-style plan were not conditions of this final user-approved automated transaction.
- Evidence: `test-compare-autoplay.py` remained green with three tests: lower coverage with a shared group passes, no shared group fails, and an empty adjacent response fails.
- Verification: Candidate, payload and trusted rollback hashes remained `cde1f81c0bde3c6c6d9925de07a3b44f0549998363f7cc5e863003950cce6f5e`, `87348007dcdf559f2be9bc3acf70820a24c3c83aedb07eac71c4de5c78fc4dea` and `cf553a877a4a8a35b8db7e5788ff045b5f3e664b0bef64c9320bf407585fc2f6`.
- Commit: none; private transaction tooling and evidence were intentionally not tracked.

### 2026-07-31 16:19 — Final language-selection candidate retained after all automated gates passed

- Why: The user explicitly approved the exact final wrapper command for one complete candidate write, automated verification and rollback only on failure.
- What changed: **Implemented live.** The complete AIOStreams saved configuration now uses the approved three disjoint language sections, four resolutions, TorBox-first provider-neutral Catalan/Spanish slots, and separate dynamic TorBox/Real-Debrid English pools for movies, regular series and anime. The candidate remained active; rollback was not invoked.
- How (investigation): Immediately before the write, the wrapper rechecked the trusted live baseline, frozen candidate/payload hashes, complete unrelated-field invariance and the tested comparator. After the write it captured five responses for each of 11 representative endpoints, inspected preferred-expression names and ranked memberships, compared per-endpoint medians and audited both adjacent episode pairs.
- How (action): Submitted exactly one complete `PUT /api/v1/user`; the API returned `{"success":true,"detail":"User updated successfully"}`. `GET /api/v1/user?raw=true` returned `trusted: true` and matched the candidate exactly after removing only server-authoritative `trusted`.
- Decisions: Retain the candidate because every automated gate passed. Do not perform the earlier physical Tizen transition, 1Password document replacement or operator-guide expansion: the user had explicitly asked to finish the simple config update and stop adding process. Preserve those unchecked steps in `plan.md` so they are not misreported as completed.
- Evidence: Readback SHA-256 was `46f6ba8e7c4f3faf8dccf79e8800d20aa1f21590b9f802a9f410b804cae48eed`; the difference from the candidate hash is the server-owned `trusted: true` field. Readback had four preferred resolutions, three ranked regexes, 35 ranked stream expressions, three preferred stream expressions, 16 required stream expressions and `autoPlay: null`. Eleven first-response audits contained 3 Catalan rows, live English 480p rows and at most 19 total rows in any response. All section/order/provider/pool/bounds checks passed, and representative movie, regular-series and anime membership files contained unique explicit-English IDs.
- Verification: All 55 post-change requests returned valid `streamData`. All 11 median gates passed: post medians ranged from `8.340669s` to `9.499075s` and remained below their per-endpoint thresholds. Breaking Bad retained `18/16` adjacent rows, ten shared groups and coverage `0.8888888889` versus baseline `0.7272727273`. Attack on Titan retained `3/2` rows, one shared group and coverage `0.6666666667` versus baseline `0.7647058824`; the lower ratio was correctly reported but non-rejecting. No 1Password edit, image build, deployment, restart, Cloudflare change, provider mutation or Stremio reinstall occurred.
- Commit: none; this was replacement-only saved-user state, not a tracked runtime file.

### 2026-07-31 16:32 — Server-side scope and live Catalan behavior clarified

- Why: The user asked whether the result change was made in Stremio or Nuvio and whether Catalan results had actually been tested.
- What changed: **Investigatory clarification.** Established that the mutation is in AIOStreams' server-side saved configuration, so both Stremio and Nuvio receive the same behavior whenever they use the same encrypted addon URL. No client installation or app source changed.
- How (investigation): Compared the final saved-config readback with representative AIOStreams stream responses. The response audit used `streamData.streamExpressionMatched.name`, not display text, to classify retained rows.
- How (action): No mutation. Reported the architecture and the retained live Catalan evidence.
- Decisions: Treat AIOStreams as the source of selection and display metadata. Client-specific behavior is relevant only to how the returned plain-text `name` and `description` are rendered.
- Evidence: The representative set retained three Catalan-classified rows across `alcarras` and `creatura`; `alcarras` alone returned two Catalan rows plus two Spanish rows in the correct section order.
- Verification: The live response audit's `catalanRows` count was `3`, and the final candidate remained active with exact saved-config readback outside `trusted`.
- Commit: none.

### 2026-07-31 17:08 — Stremio and Nuvio styling limits established

- Why: The user wanted a visible language marker and asked whether colored text, pipe characters, HTML, Markdown, CSS or client badge rules could represent Catalan, Spanish and English.
- What changed: **Investigatory design conclusion.** Both target clients treat addon stream labels as plain text; ordinary Unicode emoji are the only portable inline visual marker available without modifying a client.
- How (investigation): Read the Stremio Addon SDK stream-response contract and inspected Nuvio's public Kotlin/Compose renderer. `StreamCard.kt` renders the addon-provided stream label with Compose `Text`; `StreamModels.kt` maps the AIOStreams `name` directly to `streamLabel`. `StreamBadgeRules.kt` can match local text and `StreamBadgeChip.kt` supports locally configured colors, but the current stream-card badge path is client-owned/image-oriented and cannot be driven by HTML/CSS embedded in an addon string. AIOStreams formatter source confirmed `name` and `description` are strings and its custom formatter exposes the preferred-expression name as `{stream.seMatched}`.
- How (action): No live mutation. Rejected HTML, Markdown, ANSI escape sequences, CSS and colored-pipe proposals because neither Stremio nor Nuvio interprets those constructs in addon stream fields.
- Decisions: Use plain Unicode flag emoji prepended by the AIOStreams formatter. Key the conditions to AIOStreams' selected preferred-expression name rather than re-parsing filenames in the formatter or client.
- Evidence: Nuvio uses plain Compose text styles for the label, and Stremio exposes no structured per-stream language badge/flag field. Local Nuvio badge rules are not a portable server-provided styling channel.
- Verification: Read-only source inspection only; no AIOStreams API call, client build, deployment or repository edit occurred.
- Commit: none.

### 2026-07-31 17:20 — Catalonia flag fallback diagnosed and formatter syntax proved

- Why: A Catalonia subdivision flag rendered as a black flag. The user asked what Catalan speakers commonly use when the Catalan-specific glyph is unavailable and ultimately selected the Andorra flag.
- What changed: **Approved display design.** Catalan rows use 🇦🇩 because Catalan is Andorra's sole official language and the standard regional-indicator emoji has broad client support. Spanish and English were later required to receive 🇪🇸 and 🇬🇧 as well.
- How (investigation): The Catalonia subdivision sequence starts with `U+1F3F4 BLACK FLAG`, followed by Unicode tag characters and a cancel tag. Clients without subdivision-sequence support render only the black base. Web research and community usage showed no universally portable Catalonia emoji; text labels, the Spain flag and the Andorra flag are common fallbacks. Search-provider failures were non-functional detours: one Parallel request reported insufficient credit, Exa returned HTTP 404 and later Parallel/Tavily searches supplied enough corroboration. A broad `rg` query for `CAT` also produced roughly 1.1 MB of irrelevant shell/git/translation matches; narrowing to exact black-flag code points, `es-ct`/`es_ct` and structured fields found no literal Catalonia sequence in captured AIOStreams data or Nuvio source.
- How (action): Proved the exact AIOStreams custom-formatter condition through the non-persistent `POST /api/v1/format` preview endpoint: `{stream.seMatched::=Catalan["🇦🇩 "||""]}`. Several environment/tooling failures were corrected without live mutation: noninteractive PATH lacked `docker`, so the installed absolute CLI was used; the image lacked ordinary `node` on PATH, so its `/nodejs/bin/node` entrypoint was used; direct compiled-module import raised `ReferenceError: Cannot access 'root' before initialization`, so the supported preview endpoint replaced it; a serialized addon string caused `FORMAT_INVALID_STREAM`, so the request used the expected addon object; and zsh-only `${lang:l}` failed under `/bin/sh`, so explicit language/slug pairs replaced it.
- Decisions: Do not use the unsupported Catalonia sequence. Keep the existing formatter body unchanged and prepend only exact classification conditions.
- Evidence: Preview output showed 🇦🇩 only for a Catalan-classified row and no black-flag glyph. Spanish and English fixture previews remained unprefixed in the initial Catalan-only candidate, which later exposed the scope misunderstanding.
- Verification: The preview endpoint parsed and rendered the condition in deployed AIOStreams v2.31.1 without persisting configuration.
- Commit: none.

### 2026-07-31 17:34 — First Catalan-only PUT correctly rolled back after a false verifier failure

- Why: The user approved one formatter-only PUT to replace the unsupported Catalonia glyph with 🇦🇩 on Catalan rows.
- What changed: **Attempted then rolled back.** The candidate changed only `formatter.definitions.custom.name`, was accepted and read back exactly, and produced correct Catalan output. The wrapper nevertheless classified the live check as failed and restored the exact previous configuration.
- How (investigation): The first verifier inferred Catalan membership from filename text. In the live Alcarràs response, two rows classified by AIOStreams as Catalan correctly began with 🇦🇩. A third filename contained `Catalan+Subs` but AIOStreams had correctly assigned `streamExpressionMatched.name: "Spanish"`; it correctly had no Catalan flag. The filename heuristic treated that Spanish row as Catalan and caused the false failure.
- How (action): The guarded wrapper performed one complete PUT, exact readback, live Alcarràs fetch, then automatic complete rollback when the focused verifier returned false. Rollback readback matched the pre-write configuration exactly; no broken formatter remained active.
- Decisions: A verifier must judge the feature using the same semantic source as the formatter. Filename text is unsuitable because filenames can mention subtitle languages that do not define the selected section.
- Evidence: Transaction output was `preflight passed`, `one candidate PUT accepted`, `exact readback verified`, `FAIL: Catalan flag verification failed`, `verification failed; restoring prior config`, `rollback verified`. The captured Spanish-classified filename was `Alcarras [BluRay 1080p][AC3 5.1 Castellano AC3 5.1-Catalan+Subs][ES-EN]`.
- Verification: Post-rollback complete readback matched the prior saved configuration. No unrelated field, deployment, client, 1Password item or tracked file changed.
- Commit: none.

### 2026-07-31 17:47 — Catalan verifier corrected test-first to use AIOStreams classification

- Why: The false rollback proved the live output was correct but the acceptance oracle was wrong; retrying without fixing the oracle would repeat the same failure.
- What changed: **Implemented private verifier fix.** Added `test-catalan-verifier.sh` and `verify-catalan-response.jq` in the private run directory, then changed the transaction wrapper to select rows by `streamData.streamExpressionMatched.name == "Catalan"`.
- How (investigation): The regression fixture contains a Catalan-classified flagged row, a Spanish-classified filename mentioning `Catalan+Subs`, and non-Catalan rows. The initial test failed with `FAIL: Catalan verifier implementation is missing`, establishing RED before the jq verifier existed.
- How (action): Implemented three assertions: at least one classified Catalan row exists; every classified Catalan row starts with 🇦🇩 and contains no black flag; every non-Catalan row does not start with 🇦🇩. Updated only the verifier call in `apply-andorra-flag.sh` and syntax-checked the wrapper.
- Decisions: Always use `streamExpressionMatched.name` for display-section verification. Filename and subtitle metadata remain evidence but never override AIOStreams' actual preferred-expression result.
- Evidence: The corrected test printed `PASS: classified Catalan rows are flagged and non-Catalan rows are not`.
- Verification: Test fixture passed, captured failed-transaction response passed under the corrected verifier, and no live PUT occurred during the fix.
- Commit: none; private test and wrapper artifacts were not tracked.

### 2026-07-31 17:58 — Corrected Catalan-only formatter retained

- Why: After the test-first verifier fix, the user separately approved the exact retry command.
- What changed: **Implemented live.** The same formatter-only Catalan candidate was submitted once, read back exactly and retained after the corrected classified-row verifier passed.
- How (investigation): Preflight re-read the complete live configuration and required it to equal the known rollback source before submitting the unchanged candidate.
- How (action): One complete `PUT /api/v1/user` succeeded. The wrapper fetched Alcarràs, ran `verify-catalan-response.jq` and kept the candidate because all checks passed. Rollback remained defined but was not invoked.
- Decisions: Retain the Catalan-only formatter temporarily; no selector, provider, resolution, expression, autoplay or trust field changed.
- Evidence: The resulting complete config SHA-256 was `e63db20d2137464ad0c610f22d4295602105ceeed49c1c2a1419822bd16a0a2c`.
- Verification: Exact readback and focused live verification passed; classified Catalan rows used 🇦🇩 and non-Catalan rows did not.
- Commit: none.

### 2026-07-31 18:04 — Three-language flag correction applied and freshly reverified

- Why: The user correctly objected that adding only a Catalan flag left Spanish and English unmarked. The intended complete display mapping became Catalan → 🇦🇩, Spanish → 🇪🇸, English → 🇬🇧.
- What changed: **Implemented live.** Added exact Spanish and English preferred-expression conditions before the unchanged formatter body. The final formatter-only configuration is active.
- How (investigation): Built the candidate from the exact Catalan-only live config. A structural scalar-path comparison showed the sole changed path was `formatter.definitions.custom.name`. The first preview batch silently produced no requests because `rg '"name": "Catalan"'` expected pretty-printed spacing in compact JSON; parsing every captured response structurally in Python by `streamExpressionMatched.name` fixed fixture discovery. `test-language-flags.sh` first failed with `FAIL: language flag verifier is missing`, then passed after `verify-language-flags.jq` implemented exact classification-based checks for all three languages.
- How (action): Under separate approval, `apply-language-flags.sh` required current hash `e63db20d2137464ad0c610f22d4295602105ceeed49c1c2a1419822bd16a0a2c`, candidate hash `2e819f680881573e7f137c14434bd1817b4c39e3d1a8647d76a875b401c18a89`, exact live preflight equality and a defined rollback. It submitted one complete PUT; the API returned `{"success":true,"detail":"User updated successfully"}`. It then required exact saved-config readback outside `trusted`, fetched Alcarràs for Catalan/Spanish and Attack on Titan for English, combined the responses and ran the three-language verifier. No gate failed, so rollback was not invoked.
- Decisions: Use exact formatter comparisons against `Catalan`, `Spanish` and `English`; do not infer from filenames, parsed-language arrays or client behavior. Keep all existing selection, size, provider and description formatting unchanged.
- Evidence: Candidate and final readback SHA-256 are both `2e819f680881573e7f137c14434bd1817b4c39e3d1a8647d76a875b401c18a89`. Fresh examples were `Catalan: 🇦🇩 TB ⚡ 1080p · 2.36 GB`, `Spanish: 🇪🇸 RD ⚡ 1080p · 2.01 GB`, and `English: 🇬🇧 TB ⚡ 720p · 649.28 MB`.
- Verification: `test-language-flags.sh` printed `PASS: all classified language rows use the expected flag`; final saved config matched the expected candidate exactly outside server-owned `trusted`; fresh representative responses passed the same verifier. No 1Password, Kubernetes, Cloudflare, image, provider, client-install or tracked runtime mutation accompanied the PUT.
- Commit: none; this was saved-user state only.

### 2026-07-31 18:31 — Complete durable reconstruction prepared for local commit

- Why: The user requested a total reconstruction sufficient to start a new task with no conversation history and explicitly requested a commit.
- What changed: **Implemented documentation.** Reconciled the canonical ledger, approved design and executable plan with the actual final runtime state. Preserved all earlier uncommitted autoplay-amendment edits, added the successful selection rollout, rendering research, Unicode decision, failed Catalan verifier/rollback, test-first correction, Catalan retry and final three-language correction. Marked the task done while explicitly leaving the unperformed physical Tizen, 1Password template and broad operator-guide steps unchecked.
- How (investigation): Read the complete task `context.md`, `spec.md` and relevant `plan.md` sections; inspected repository status, recent task commits and the exact pre-existing diff; verified private artifact hashes and compact gate outputs; reran both private flag-verifier test scripts; compared final candidate/readback projections and enumerated the sole final scalar diff path. Complete configs, encrypted routes, credentials and raw authenticated URLs remained outside Git and were not printed.
- How (action): Updated only this task's three Markdown records. No live AIOStreams request or external mutation was needed for reconstruction.
- Decisions: Commit only `context.md`, `spec.md` and `plan.md`. Do not retroactively mark skipped plan gates as successful, edit the user-owned prior-task `scratch.md`, update 1Password, deploy, restart, or push.
- Evidence: Repository preflight showed branch `main`, HEAD/origin at `5139f17`, exactly three modified task files and no staged changes. Final artifact rechecks reproduced selection readback hash `46f6ba8e7c4f3faf8dccf79e8800d20aa1f21590b9f802a9f410b804cae48eed`, final flag config hash `2e819f680881573e7f137c14434bd1817b4c39e3d1a8647d76a875b401c18a89`, 11/11 accepted latency medians and passing Catalan/all-language verifier output.
- Verification: Documentation schema, frontmatter, relative links, placeholder/conflict markers, checkbox syntax, whitespace, absolute home paths and credential-shaped added lines all passed. The final unstaged and staged path lists contained only this task's `context.md`, `spec.md` and `plan.md`.
- Commit: this reconstruction is committed by the local documentation commit containing this entry; its hash is reported after commit verification. No push was requested or performed.
