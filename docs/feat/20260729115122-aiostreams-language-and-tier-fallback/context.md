---
title: "Add AIOStreams language sections and dynamic size tiers"
status: active
repos: [ritchie]
tags: [deployment]
related: [20260726235500-feat-aiostreams-deployment]
created: 2026-07-29
---

# Add AIOStreams language sections and dynamic size tiers

## TASK

**Goal:** Present Catalan, Spanish and English result sections in that order, re-enable 480p, and return up to four dynamically size-spaced English rows per service and resolution for movies, regular series and anime.

The current 12 ordered movie selectors intentionally omit sparse fixed-size tiers, which can reduce a populated resolution/provider block to one result. The approved replacement derives English representatives from each pool's maximum, half, quarter and eighth sizes, then fills missing slots from the best remaining rows. Catalan and Spanish each contribute at most one TorBox-first row for 2160p, 1080p, 720p and 480p across providers. English is explicit rather than language-neutral and retains separate TorBox and Real-Debrid blocks.

**Done when:** The approved configuration is atomically applied and read back; Catalan → Spanish → English ordering, provider fallback, 480p, disjoint language membership and `min(4, candidate count)` English pools are verified across movies, regular series and anime; latency and adjacent-episode overlap do not regress; a Stremio 1.12.1/Tizen 6 autoplay transition succeeds; recovery documentation matches live state; and the exact pre-change configuration remains a verified rollback point.

## SPEC

[spec.md](./spec.md) — approved config-only design for disjoint language sections, dynamic English size tiers, atomic rollout, measurable regression gates and complete rollback.

## FILES

- docs/feat/20260726235500-feat-aiostreams-deployment/context.md
- docs/feat/20260726235500-feat-aiostreams-deployment/spec.md
- docs/feat/20260726235500-feat-aiostreams-deployment/plan.md
- docs/STREMIO-AIOSTREAMS.md
- docs/feat/20260729115122-aiostreams-language-and-tier-fallback/context.md
- docs/feat/20260729115122-aiostreams-language-and-tier-fallback/spec.md
- docs/feat/20260729115122-aiostreams-language-and-tier-fallback/plan.md

## PLAN

**Plan:** [plan.md](./plan.md) — four sequential gates for secure baseline capture, exact-image candidate proof, atomic rollout with automatic rollback, and post-verification persistence/documentation.
**Cursor:** Task 1 — capture a secure rollback point and representative live baseline.
**Status:** ready

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
