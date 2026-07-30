# AIOStreams language sections and dynamic size tiers

## Status

Approved design. This document specifies a saved-configuration change for the
existing AIOStreams v2.31.1 deployment. It does not authorize a live change by
itself; implementation begins only from a separately reviewed plan.

## Goal

Replace the current movie-only fixed-size selectors with a result-selection
policy that:

- presents Catalan, Spanish and English sections in that order;
- admits 2160p, 1080p, 720p and 480p in every section;
- returns at most one Catalan and one Spanish row per resolution across all
  providers, preferring TorBox and using Real-Debrid as fallback;
- returns up to four English rows per `(service, resolution)` pool;
- gives each English pool a useful spread of sizes relative to that pool;
- backfills missing size tiers so a pool with at least four eligible candidates
  still returns four distinct rows;
- applies the English policy to movies, regular series and anime; and
- does not regress adjacent-episode autoplay behavior.

## Current behavior being replaced

The saved configuration currently:

- permits 2160p, 1080p and 720p while excluding 480p;
- has no configured language inclusion, exclusion or preference;
- globally sorts by service, cached state, resolution, size and quality;
- uses conjunctive service-and-resolution limits of four rows;
- keeps a global limit of 60 rows; and
- has 12 movie-only required expressions representing one uncapped row plus
  three fixed size ceilings for each admitted resolution and service.

The fixed ceilings intentionally omit a tier when no candidate fits. As a
result, a pool can return one row despite having many candidates. Series and
anime bypass those selectors entirely.

## Scope

### In scope

- The existing user's saved AIOStreams configuration.
- Resolution preferences and exclusions needed to re-enable 480p.
- Language classification, display ordering and required stream expressions.
- Dynamic English size selection for movie, series and anime responses.
- Limiter passthrough for the two short leading language sections.
- Secure baseline capture, readback, response comparison, latency checks,
  adjacent-episode comparison, Samsung/Tizen verification and rollback.
- The recoverable configuration template and operator documentation after the
  live result has passed every gate.

### Out of scope

- Forking or patching AIOStreams.
- Building or publishing a custom image.
- Changing the pinned AIOStreams image or Helm release.
- Adding providers, indexers or addon instances.
- Making providers discover additional Catalan releases.
- Changing AIOStreams' generated `bingeGroup` method or attributes.
- Changing Kubernetes, Cloudflare, 1Password credentials or the Stremio addon
  installation.
- Guaranteeing that every title has Catalan or Spanish candidates.

## Design constraints

1. Use only behavior available in the pinned AIOStreams v2.31.1 image.
2. Treat the user API as replacement-only: every write submits the complete
   saved configuration.
3. Preserve every unrelated configuration field byte-for-byte or semantically,
   according to its data type.
4. Do not store credentials, encrypted route components, raw authenticated
   URLs or unredacted API responses in Git.
5. Preserve stream IDs through selection and never repeat an ID to fill a tier.
6. Keep the maximum possible result count below the existing global limit.
7. Do not treat Catalan as a canonical parsed language; v2.31.1 does not support
   it in the stream-language enum.
8. Do not classify subtitle-only markers as an audio-language match.

## Selection pipeline

The relevant pinned pipeline is:

1. precompute preferred regex and stream-expression matches;
2. globally sort streams;
3. apply required stream expressions in configured order, removing IDs already
   retained from each later expression's input;
4. apply the result limiter; and
5. generate the final Stremio stream response and `bingeGroup` values.

The configuration uses each stage for one purpose:

- named ranked regex patterns identify Catalan filename/folder markers;
- preferred stream expressions assign first-match language precedence;
- `streamExpressionMatched` is the leading global sort key and establishes the
  Catalan, Spanish, English display order;
- required stream expressions select exact section membership;
- `passthrough(..., 'limit')` exempts retained Catalan and Spanish rows from the
  conjunctive per-block limiter; and
- the unchanged global limiter remains the final safety cap.

Required-expression array order alone is not considered a display-order
mechanism. The final rows retain their global sort order, so language ordering
must be established before required selection.

## Language classification

Define three disjoint candidate sets over the streams that survive existing
title, resolution and quality filtering.

### Catalan candidate set `C`

A stream belongs to `C` when its filename or folder name contains either:

- the complete word `Catalan`, `Català` or `Catala`, matched
  case-insensitively; or
- the uppercase token `CAT`, bounded as a complete release token.

The full-word and short-token patterns must be separate so case-insensitive
matching for complete names does not turn every lowercase word `cat` into a
language match. Both patterns must use the same release-token boundaries as
the pinned parser: start/end or separators such as whitespace, brackets,
parentheses, underscore, hyphen, period and comma.

The marker must be rejected when it directly denotes subtitles, including
forms equivalent to `CAT sub`, `CAT subs`, `CAT subtitle` or `CAT subtitles`.
Only filename and folder name participate. Indexer and parsed release-group
fields do not independently qualify a row.

The two named ranked regex patterns form a reusable Catalan marker. Selection
expressions consume those names through `regexMatched(...)`; the configuration
must not duplicate a looser Catalan keyword definition elsewhere.

This is deliberately a heuristic. It can classify only streams AIOStreams
already receives and whose names expose a Catalan marker. It does not infer
Catalan from an unlabelled release.

### Spanish candidate set `S`

A stream belongs to `S` when:

- the native parsed language array contains `Spanish`; or
- its filename or folder name contains a bounded full-word marker for
  `Castellano`, `Español` or `Espanol` that is not subtitle-only;

and it does not belong to `C`.

Native parsed Spanish remains the primary signal. Supplemental names cover
common release labels not recognized by the pinned `spanish|spa|esp` parser.

### English candidate set `E`

A stream belongs to `E` when its native parsed language array contains
`English` and it belongs to neither `C` nor `S`.

Unknown-language, unlabelled, `Multi`-only and `Dual Audio`-only rows are not
English. A multi-audio row with an explicit English parsed language remains
eligible unless the higher-priority Catalan or Spanish classifier claims it.

### First-match precedence

The precedence is `C`, then `S`, then `E`. The sets are explicitly disjoint in
both preferred and required expressions; they do not rely on the earlier
selector having retained only one row. Therefore:

- Catalan plus Spanish is classified as Catalan;
- Catalan plus English is classified as Catalan;
- Spanish plus English is classified as Spanish; and
- no retained stream ID can appear in more than one language section.

Preferred stream expressions are configured in the same order. With
`streamExpressionMatched` descending as the first sort criterion, all Catalan
rows sort before Spanish rows and all Spanish rows before English rows. The
pinned comparator negates the preferred-expression index before applying the
direction multiplier, so descending is required for index 0 to sort first.

## Resolution policy

The admitted and preferred resolutions, in descending preference order, are:

1. 2160p
2. 1080p
3. 720p
4. 480p

480p is removed from `excludedResolutions` and added after 720p in
`preferredResolutions`. The existing treatment of 1440p, 576p, 360p, 240p,
144p and `Unknown` remains unchanged.

## Catalan and Spanish sections

For each of `C` and `S`, select independently at most one stream for each of
2160p, 1080p, 720p and 480p.

Each language-and-resolution selector:

1. receives only the corresponding disjoint language set and resolution;
2. preserves the global service-first and cached-first ordering;
3. retains the first candidate;
4. therefore chooses TorBox when TorBox has an eligible candidate and falls
   back to Real-Debrid otherwise; and
5. marks the retained row to bypass only the result-limit stage.

There is no second row merely to represent the other provider. Each section has
a maximum of four rows and the two sections have a combined maximum of eight.
Missing language-and-resolution combinations are omitted without substitution
from another resolution or language.

Limiter passthrough is required because the current conjunctive limiter groups
by service and resolution. Without passthrough, a leading Catalan or Spanish
row could consume one of the four positions intended for its English
`(service, resolution)` block.

## English section

English selection operates independently for every combination of:

- service: TorBox or Real-Debrid; and
- resolution: 2160p, 1080p, 720p or 480p.

This creates eight English candidate pools. Each pool returns exactly
`min(4, candidate count)` distinct rows.

### Reference pool

For an English candidate pool `P`:

- if at least one cached candidate exists, the reference pool `R` is the cached
  subset of `P`;
- otherwise, `R` is the uncached subset of `P`.

All proportional tier selections operate within `R`. This prevents a large
uncached result from setting the scale while cached results exist and prevents
an uncached tier match from displacing an available cached candidate.

If `R` has at least one valid positive byte size, define `M` as its largest
size. If no row in `R` has a valid positive size, skip proportional selection
and use fallback only.

### Proportional tiers

Select distinct rows from `R` in this order:

1. the highest-priority row;
2. the highest-priority remaining row with size at most `M / 2`;
3. the highest-priority remaining row with size at most `M / 4`;
4. the highest-priority remaining row with size at most `M / 8`.

Because each service-and-resolution pool is already sorted cached-first, then
size-descending and quality-descending, “highest priority” means the first row
in the existing order. Filtering by a ceiling therefore returns the largest
eligible remaining size without introducing a new sort.

Every selected ID is removed from later tier inputs. A tier that has no
eligible remaining row contributes nothing at this stage.

### Fallback

After proportional selection, append still-unselected rows from the full pool
`P` in existing order and slice the merged set to four rows.

This fallback:

- fills sparse proportional tiers with the best remaining candidates;
- uses uncached rows only after the cached rows that precede them in `P`;
- returns all candidates when fewer than four exist; and
- never duplicates a stream ID.

If proportional selection was skipped because no valid positive size exists,
the result is simply the first four rows of `P`.

Examples, using size-only pools for illustration:

- `[30, 20, 15, 10, 7, 5, 2]` selects `[30, 15, 7, 2]`;
- `[30, 29, 28, 27, 26]` selects `30` proportionally and backfills
  `[29, 28, 27]`;
- `[30, 8, 7]` returns all three rows; and
- `[30]` returns that row.

The final response remains globally sorted. Tier-selection order determines
membership, not a forced visual order that would override cached or service
priority.

## Result bounds

The maximum intended output is:

- Catalan: 4 rows;
- Spanish: 4 rows; and
- English: 2 services × 4 resolutions × 4 rows = 32 rows.

The combined maximum is 40, below the unchanged global limit of 60. The global
limit remains enabled and language-row passthrough does not exempt rows from
that global safety check.

## Autoplay behavior

This change does not modify `autoPlay`, the `matchingFile` method or the default
`resolution + quality + releaseGroup` attributes. AIOStreams continues to
generate final `bingeGroup` values after filtering and limiting.

The current identity is known to be imperfect across adjacent episodes, but
autoplay is currently working on Stremio 1.12.1 on Tizen 6. This task therefore
treats autoplay as a regression gate rather than an active incident or a reason
for a speculative identity change.

For at least one regular series and one anime, capture adjacent episode
responses before and after the change. For each pair calculate:

- the set of unique `bingeGroup` values in each episode;
- the intersection of those sets; and
- row coverage: the proportion of first-episode rows whose `bingeGroup` exists
  in the next episode.

The candidate configuration passes the server-side gate only when, for both
content classes:

- at least one exact group remains shared between adjacent episodes; and
- post-change row coverage is not lower than that title's immediately captured
  baseline.

After server-side verification, play a retained stream on Stremio 1.12.1/Tizen
6 and observe one real automatic next-episode transition. Completion requires
the next episode to start playback rather than merely open its page or stream
list.

An on-device failure blocks completion even when server-side overlap is stable.
The implementation must restore the prior configuration unless the user
explicitly accepts the observed behavior as a separate client issue.

## Safe rollout

### Baseline

Before any write:

1. Create a timestamped mode-0700 directory outside Git.
2. Save the complete raw user configuration and a hash of it.
3. Save the authenticated route components needed for reproducible requests
   without printing them to terminal logs.
4. Capture representative responses for:
   - a dense movie;
   - a sparse movie;
   - a regular series episode and its next episode;
   - an anime episode and its next episode;
   - content with Spanish and English candidates;
   - content with mixed-language candidates; and
   - at least one returned positive Catalan candidate plus Catalan near-misses.
5. Record row IDs, parsed languages, filename/folder markers, service, cache
   state, resolution, size, quality and `bingeGroup` without committing raw
   authenticated responses.
6. Run repeated timed requests for the same matrix to establish latency.

If no actual returned Catalan candidate can be found, do not claim live Catalan
matching has been verified. The implementation plan may add an isolated pinned-
image synthetic classifier test, but that does not replace the live positive
case required for completion.

### Offline validation

Before writing live state:

1. Validate every regex and stream expression in the exact pinned v2.31.1
   image.
2. Run synthetic dense, sparse, undersized and missing-size pools through the
   dynamic selector.
3. Prove every synthetic pool returns `min(4, candidate count)` unique IDs.
4. Test Catalan full-name, uppercase short-tag, lowercase `cat`, substring,
   subtitle-only and punctuation-boundary cases.
5. Apply the complete candidate configuration to captured response data where
   the pinned tooling permits it and inspect the proposed membership/order.

### Atomic write and readback

The ranked regexes require the saved UUID to be trusted under the existing
`REGEX_FILTER_ACCESS=trusted` policy. That prerequisite is a separate,
least-privilege GitOps rollout: map the existing 1Password `config_uuid` field
through External Secrets to `TRUSTED_UUIDS` and inject it into the pinned
AIOStreams Deployment. Do not commit the UUID, broaden regex access, or combine
deployment approval with candidate-write approval.

After that separately approved rollout and before any candidate write:

1. Require the ExternalSecret to be ready and the Deployment rollout to be
   available.
2. Read the complete raw saved configuration and require `trusted: true`.
3. Compare it with the original Task 1 baseline after removing only `trusted`;
   no other field may differ.
4. Save this complete post-trust, pre-write configuration and its hash as the
   active rollback source.

Then, under a second explicit approval:

1. Submit the complete candidate configuration once with the replacement-only
   user API.
2. Read the complete saved configuration back immediately and require
   `trusted: true` separately.
3. Compare the readback semantically with the intended payload after removing
   only `trusted`, because pinned v2.31.1 derives that field from
   `TRUSTED_UUIDS` on updates and raw reads.
4. Compare all unrelated fields with the active rollback source and require no
   unintended differences.
5. Stop and restore the active rollback source on any write, readback,
   validation or comparison failure.

No additional Kubernetes rollout, container restart, image build, Cloudflare
mutation or Stremio reinstall is part of the candidate-write operation.

## Acceptance criteria

### Language and ordering

- Every retained row belongs to exactly one of `C`, `S` or `E`.
- If present, all Catalan rows precede all Spanish rows, and all Spanish rows
  precede all English rows.
- Catalan and Spanish each contain at most one row for each of 2160p, 1080p,
  720p and 480p and at most four rows total.
- For each populated language-and-resolution slot, TorBox is selected when an
  eligible TorBox candidate exists; otherwise Real-Debrid may fill the slot.
- Catalan full names and uppercase bounded `CAT` positive fixtures match.
- Lowercase `cat`, embedded substrings and subtitle-only markers do not match.
- Spanish native parsing and supplemental full-word labels match without
  claiming higher-priority Catalan rows.
- English contains only explicitly parsed English rows not claimed by Catalan
  or Spanish.

### English pools

- Every `(service, resolution)` pool contains exactly
  `min(4, eligible candidate count)` distinct IDs.
- Proportional representatives follow `M`, `M/2`, `M/4` and `M/8` when eligible
  rows exist in the reference pool.
- Missing tiers are filled from the best remaining rows in existing order.
- A cached reference pool is never scaled by or proportionally displaced by an
  uncached outlier.
- Missing or invalid sizes fall back deterministically to existing order.
- The same policy is observed for movies, regular series and anime.

### Limits and regression checks

- 480p appears when eligible in every language section.
- Catalan and Spanish rows do not reduce any populated English block below its
  `min(4, candidate count)` requirement.
- Total retained output never exceeds 60 and is expected never to exceed 40.
- The configuration adds no upstream addon request.
- For each representative request, collect at least five successful baseline
  and five successful post-change timings. The post-change median must not
  exceed the baseline median by more than the greater of 10% or 500 ms. A
  failure may be retried once with a fresh paired sample; a repeated failure
  rejects the rollout.
- Adjacent-episode `bingeGroup` row coverage does not regress for the tested
  regular series or anime pair.
- One real next-episode transition succeeds on Stremio 1.12.1/Tizen 6.
- Readback has server-authoritative `trusted: true`, matches the intended
  complete configuration after removing only `trusted`, and has no unrelated
  field change.

## Rollback

Rollback is the exact complete post-trust, pre-write configuration captured
immediately before the candidate write. It must match the original Task 1
baseline after removing only server-authoritative `trusted`, and it must carry
`trusted: true`. Do not construct a partial rollback object.

Trigger rollback on any of the following:

- parser or expression error;
- write or readback mismatch;
- unintended unrelated configuration difference;
- incorrect section order or duplicate category membership;
- Catalan false positive or failure of the live positive case;
- incorrect provider fallback;
- an English pool returning fewer than `min(4, candidate count)` rows;
- incorrect proportional or fallback membership;
- result overflow;
- repeated latency-gate failure;
- adjacent-episode overlap regression; or
- failed Samsung/Tizen autoplay transition.

Restore the complete active rollback source with the replacement-only user API,
read it back, require exact full semantic and hash equality with that post-trust
snapshot, and repeat representative response and autoplay checks. Every
rollback stage must fail closed; a rollback is not complete merely because the
restore request returned success.

## Persistence and documentation

Only after every acceptance criterion passes:

1. Replace the recoverable AIOStreams configuration template with the exact
   verified readback, preserving secret-handling rules.
2. Update `docs/STREMIO-AIOSTREAMS.md` with the language precedence, Catalan
   heuristic, 480p admission, dynamic English tiers, result bounds and autoplay
   gate.
3. Update the prior deployment reference to distinguish its historical fixed,
   movie-only selectors from the new deployed behavior without rewriting its
   original evidence.
4. Update this task's `context.md` with the verified configuration behavior,
   evidence, rollback point and final status.

The existing `scratch.md` in the prior task directory is user-owned and must
remain untouched.
