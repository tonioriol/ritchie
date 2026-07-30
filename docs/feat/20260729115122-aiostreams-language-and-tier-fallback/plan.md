# AIOStreams Language Sections and Dynamic Size Tiers Implementation Plan

> **For Roo workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` for one Roo subtask at a time, or `executing-plans` for same-session execution. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atomically replace the current movie-only fixed-size selectors with verified Catalan, Spanish and English sections, 480p admission, and four pool-relative English representatives for movies, regular series and anime.

**Architecture:** Keep the pinned AIOStreams v2.31.1 image and change only the existing user's complete saved configuration. Three bounded ranked regexes and three disjoint ranked stream-expression tags classify language; preferred expressions plus a leading descending `streamExpressionMatched` sort key establish Catalan → Spanish → English order. Thirty-two compact ranked tags calculate each English pool's cached-first maximum and half/quarter/eighth threshold sets before sorting; sixteen required selectors run after global sorting, retain one Catalan/Spanish row per resolution with limiter passthrough, and choose distinct maximum/half/quarter/eighth English rows before backfilling each pool to four.

**Tech Stack:** AIOStreams v2.31.1 User API and stream-expression language, pinned `ghcr.io/viren070/aiostreams:v2.31.1` image, Python 3, Node.js in the pinned image, `curl`, `jq`, Docker, 1Password CLI, Markdown.

## Global Constraints

- Use only behavior available in `ghcr.io/viren070/aiostreams:v2.31.1`; do not fork, patch, build, publish or change the image.
- Treat `PUT /api/v1/user` as replacement-only: every write contains the complete saved configuration.
- Preserve every unrelated configuration field semantically; the only candidate fields are `preferredResolutions`, `excludedResolutions`, `sortCriteria`, `rankedRegexPatterns`, `rankedStreamExpressions`, `preferredStreamExpressions` and `requiredStreamExpressions`.
- Preserve `resultLimits = {"global":60,"service":4,"resolution":4,"mode":"conjunctive"}` and keep the intended maximum at 40 rows.
- Preserve `autoPlay`, the generated `matchingFile` method and the default `resolution + quality + releaseGroup` attributes unchanged.
- Preserve stream IDs, never duplicate an ID to fill a tier, and require each English pool to contain exactly `min(4, eligible candidate count)` retained IDs.
- Catalan is a bounded filename/folder heuristic, not a canonical parsed language; subtitle-only markers, lowercase `cat` and embedded substrings must not match.
- English requires explicit parsed `English`; unknown, unlabelled, `Multi`-only and `Dual Audio`-only rows are not English.
- Store credentials, route components, complete live configs and raw authenticated responses only under a mode-`0700` timestamped `/tmp` directory; never add them to Git or print them.
- Use 1Password account `PRBEZ6ELGNCMDIK6YVMRW5TTXQ` for every `op` command.
- On any parser, expression, write, readback, unrelated-field, language, ordering, fallback, pool-count, overflow, repeated-latency, adjacent-episode or Samsung/Tizen gate failure, restore the exact complete pre-change config and verify the restore before stopping.
- Do not run Kubernetes, Helm, Cloudflare, image-build, container-restart or Stremio-reinstall operations.
- Do not modify `docs/feat/20260726235500-feat-aiostreams-deployment/scratch.md`.
- Do not push any commit without explicit user approval.

---

## File Structure

- Create temporarily: `/tmp/aiostreams-language-tiers-<UTC timestamp>/generate-candidate.py` — deterministic complete-config generator with baseline assertions and pinned expression-limit checks.
- Create temporarily: `/tmp/aiostreams-language-tiers-<UTC timestamp>/validate-candidate.mjs` — exact-image synthetic regex, precedence, dynamic-pool and parser proof.
- Create temporarily: `/tmp/aiostreams-language-tiers-<UTC timestamp>/audit-responses.py` — compact live language/order/pool/result-bound audit.
- Create temporarily: `/tmp/aiostreams-language-tiers-<UTC timestamp>/audit-autoplay.py` — adjacent-episode group overlap and row-coverage comparison.
- Create temporarily: `/tmp/aiostreams-language-tiers-<UTC timestamp>/{before,candidate,readback,rollback}-config.json` — secret-bearing complete configurations; mode `0600`, never committed.
- Create temporarily: `/tmp/aiostreams-language-tiers-<UTC timestamp>/{baseline,after,retry}/` — raw authenticated response and timing evidence; never committed.
- Modify after all runtime gates pass: `docs/STREMIO-AIOSTREAMS.md` — replace the old current-behavior description with verified language precedence, Catalan heuristic, 480p, dynamic English tiers, bounds and autoplay gate.
- Modify after all runtime gates pass: `docs/feat/20260726235500-feat-aiostreams-deployment/spec.md` — add only a supersession note that preserves its historical fixed movie-only evidence.
- Modify during execution: `docs/feat/20260729115122-aiostreams-language-and-tier-fallback/plan.md` — mark steps only after their gates pass and record non-secret observed summaries.
- Modify during execution: `docs/feat/20260729115122-aiostreams-language-and-tier-fallback/context.md` — record secure rollback hash, verified behavior, evidence and final status.
- External state after all gates: existing AIOStreams saved user configuration and credential-free 1Password document `neumann/aiostreams-config-template`.

### Task 1: Capture a secure rollback point and representative live baseline

**Files:**
- Read: `docs/feat/20260729115122-aiostreams-language-and-tier-fallback/spec.md`
- Read: `docs/STREMIO-AIOSTREAMS.md`
- Create temporarily: `/tmp/aiostreams-language-tiers-<UTC timestamp>/before-response.json`
- Create temporarily: `/tmp/aiostreams-language-tiers-<UTC timestamp>/before-config.json`
- Create temporarily: `/tmp/aiostreams-language-tiers-<UTC timestamp>/baseline/*`

**Interfaces:**
- Consumes: 1Password fields `neumann/aiostreams/config_uuid` and `config_password`; authenticated `GET /api/v1/user?raw=true`; existing encrypted Stremio route component returned as `data.encryptedPassword`.
- Produces: shell variables `WORK`, `B`, `U`, `P`, `AUTH`, `EP`; exact rollback config and SHA-256; representative endpoint matrix; five baseline timings per endpoint; compact language discovery and adjacent-episode reports.

- [ ] **Step 1: Confirm repository location and preserve unrelated work**

Run from the `ritchie` repository:

```bash
pwd
git rev-parse --show-toplevel
git status --short
```

Expected: both paths end in `/ritchie`. Record every pre-existing status entry and do not stage, edit or delete it. In particular, leave `docs/feat/20260726235500-feat-aiostreams-deployment/scratch.md` untouched if it exists.

- [ ] **Step 2: Create a private run directory and load credentials without echoing them**

Run in one persistent shell:

```bash
umask 077
WORK="/tmp/aiostreams-language-tiers-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 700 "$WORK" "$WORK/baseline" "$WORK/after" "$WORK/retry"
export OP_ACCOUNT=PRBEZ6ELGNCMDIK6YVMRW5TTXQ
B=https://aiostreams.tonioriol.com
U=$(op read 'op://neumann/aiostreams/config_uuid' --account "$OP_ACCOUNT")
P=$(op read 'op://neumann/aiostreams/config_password' --account "$OP_ACCOUNT")
AUTH="Authorization: Basic $(printf '%s' "$U:$P" | base64)"
test -n "$U" && test -n "$P" && printf 'credentials loaded; WORK=%s\n' "$WORK"
```

Expected: one line containing only the temporary path. If 1Password is not signed in, stop for interactive authentication; do not obtain credentials from Kubernetes.

- [ ] **Step 3: Fetch, hash and assert the complete documented pre-change state**

Run:

```bash
curl --fail --silent --show-error \
  "$B/api/v1/user?raw=true" -H "$AUTH" > "$WORK/before-response.json"
jq -e '
  .success == true and
  (.data.userData | type == "object") and
  (.data.encryptedPassword | type == "string" and length > 0)
' "$WORK/before-response.json" >/dev/null
jq '.data.userData' "$WORK/before-response.json" > "$WORK/before-config.json"
chmod 600 "$WORK/before-response.json" "$WORK/before-config.json"
shasum -a 256 "$WORK/before-config.json" > "$WORK/before-config.sha256"
EP=$(jq -r '.data.encryptedPassword' "$WORK/before-response.json")

jq -e '
  .preferredResolutions == ["2160p","1080p","720p"] and
  .excludedResolutions == ["1440p","576p","480p","360p","240p","144p","Unknown"] and
  .sortCriteria.global == [
    {"key":"service","direction":"desc"},
    {"key":"cached","direction":"desc"},
    {"key":"resolution","direction":"desc"},
    {"key":"size","direction":"desc"},
    {"key":"quality","direction":"desc"}
  ] and
  .resultLimits == {"global":60,"service":4,"resolution":4,"mode":"conjunctive"} and
  ((.requiredStreamExpressions // []) | length == 12) and
  .rankedRegexPatterns == null and
  .rankedStreamExpressions == null and
  .preferredStreamExpressions == null and
  .autoPlay == null and
  .dynamicAddonFetching == null and
  .groups == null and
  .serviceWrap == null and
  ([.services[] | select(.enabled) | .id] == ["torbox","realdebrid"])
' "$WORK/before-config.json" >/dev/null

jq -c '{
  preferredResolutions,
  excludedResolutions,
  limits:.resultLimits,
  requiredExpressions:(.requiredStreamExpressions|length),
  enabledServices:[.services[]|select(.enabled)|.id],
  autoPlay
}' "$WORK/before-config.json"
cat "$WORK/before-config.sha256"
```

Expected: the compact non-secret summary shows the documented 12-selector baseline and the hash line. Stop for review if any assertion differs; do not weaken the assertion or generate a candidate from an unknown baseline.

- [ ] **Step 4: Define the representative request matrix**

Run:

```bash
cat > "$WORK/endpoints.tsv" <<'EOF'
matrix	movie	tt0133093
godfather	movie	tt0068646
dune2	movie	tt15239678
alcarras	movie	tt11930126
el47	movie	tt27751957
casaenflames	movie	tt29793197
creatura	movie	tt21869176
breakingbad-e01	series	tt0903747:1:1
breakingbad-e02	series	tt0903747:1:2
attackontitan-e01	series	tt2560140:1:1
attackontitan-e02	series	tt2560140:1:2
EOF
awk -F '\t' 'NF != 3 {exit 1} END {print NR " endpoints"}' "$WORK/endpoints.tsv"
```

Expected: `11 endpoints`. This matrix includes dense and sparse movies, Spanish/mixed-language movies, four likely Catalan-source movies, a regular-series adjacent pair and an anime adjacent pair.

- [ ] **Step 5: Capture five successful diagnostic responses and timings per endpoint**

Run:

```bash
while IFS=$'\t' read -r label type id; do
  url="$B/stremio/$U/$EP/stream/$type/$id.json"
  for run in 1 2 3 4 5; do
    curl --fail --silent --show-error \
      -H 'User-Agent: AIOStreams/rollout-audit' \
      -o "$WORK/baseline/$label-$run.json" \
      -w '%{time_total}\n' "$url" \
      > "$WORK/baseline/$label-$run.seconds"
    jq -e '
      (.streams | type == "array") and
      ([.streams[] | select(.streamData.id != null)] | length > 0)
    ' "$WORK/baseline/$label-$run.json" >/dev/null
  done
done < "$WORK/endpoints.tsv"

test "$(fd -e seconds . "$WORK/baseline" | wc -l | tr -d ' ')" -eq 55
echo 'captured 55 successful baseline timings with streamData'
```

Expected: `captured 55 successful baseline timings with streamData`. Raw responses stay under `$WORK`; never print their URLs or add them to Git.

- [ ] **Step 6: Build a compact baseline discovery report and require a real Catalan positive**

Create `$WORK/discover-languages.py` with:

```python
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SEP_LEFT = r"(?<![^\s\[(_\-.,])"
SEP_RIGHT = r"(?=[\s\)\]_.\-,]|$)"
NOT_SUBS = r"(?![\s\[(_\-.,]*sub(title)?s?(?=[\s\)\]_.\-,]|$))"
CAT_NAME = re.compile(SEP_LEFT + r"(?:catalan|català|catala)" + NOT_SUBS + SEP_RIGHT, re.I)
CAT_TOKEN = re.compile(SEP_LEFT + r"CAT" + NOT_SUBS + SEP_RIGHT)
SPANISH_ALIAS = re.compile(SEP_LEFT + r"(?:castellano|español|espanol)" + NOT_SUBS + SEP_RIGHT, re.I)


def classify(data: dict) -> str | None:
    filename = data.get("filename") or ""
    folder = data.get("folderName") or ""
    languages = set((data.get("parsedFile") or {}).get("languages") or [])
    catalan = any(pattern.search(value) for pattern in (CAT_NAME, CAT_TOKEN) for value in (filename, folder))
    spanish = not catalan and ("Spanish" in languages or any(SPANISH_ALIAS.search(value) for value in (filename, folder)))
    english = not catalan and not spanish and "English" in languages
    return "C" if catalan else "S" if spanish else "E" if english else None


root = Path(sys.argv[1])
rows = []
for path in sorted(root.glob("*-1.json")):
    payload = json.loads(path.read_text())
    for stream in payload.get("streams", []):
        data = stream.get("streamData") or {}
        if not data.get("id"):
            continue
        category = classify(data)
        service = (data.get("service") or {}).get("id")
        cached = (data.get("service") or {}).get("cached")
        parsed = data.get("parsedFile") or {}
        rows.append({
            "sample": path.name.removesuffix("-1.json"),
            "id": data["id"],
            "category": category,
            "service": service,
            "cached": cached,
            "resolution": parsed.get("resolution"),
            "size": data.get("size"),
            "languages": parsed.get("languages") or [],
            "filename": data.get("filename"),
            "folderName": data.get("folderName"),
            "bingeGroup": (stream.get("behaviorHints") or {}).get("bingeGroup"),
        })

positives = [row for row in rows if row["category"] == "C"]
summary = {
    "rows": len(rows),
    "categories": {name: sum(row["category"] == name for row in rows) for name in ("C", "S", "E")},
    "catalanPositiveSamples": sorted({row["sample"] for row in positives}),
    "catalanPositiveCount": len(positives),
}
(root.parent / "baseline-candidates.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n")
(root.parent / "baseline-discovery.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(summary, indent=2, ensure_ascii=False))
if not positives:
    raise SystemExit("no live Catalan-positive result in the baseline matrix")
```

Run:

```bash
python3 "$WORK/discover-languages.py" "$WORK/baseline" \
  > "$WORK/baseline-discovery.txt"
cat "$WORK/baseline-discovery.txt"
```

Expected: `catalanPositiveCount` is greater than zero and at least one sample is listed. If all four likely Catalan movies return no positive, stop without claiming live Catalan verification; add read-only probes for other known Catalan titles and repeat this step before any write.

- [ ] **Step 7: Capture baseline adjacent-episode overlap**

Create `$WORK/audit-autoplay.py` with:

```python
from __future__ import annotations

import json
import sys
from pathlib import Path


def groups(path: Path) -> list[str]:
    payload = json.loads(path.read_text())
    return [
        group
        for stream in payload.get("streams", [])
        if (stream.get("streamData") or {}).get("id")
        if (group := (stream.get("behaviorHints") or {}).get("bingeGroup"))
    ]


root = Path(sys.argv[1])
result = {}
failed = False
for title in ("breakingbad", "attackontitan"):
    first = groups(root / f"{title}-e01-1.json")
    second = groups(root / f"{title}-e02-1.json")
    shared = set(first) & set(second)
    coverage = sum(group in shared for group in first) / len(first) if first else 0.0
    result[title] = {
        "firstRows": len(first),
        "secondRows": len(second),
        "firstUniqueGroups": len(set(first)),
        "secondUniqueGroups": len(set(second)),
        "sharedGroups": len(shared),
        "firstRowCoverage": coverage,
    }
    failed |= not first or not second or not shared
print(json.dumps(result, indent=2, sort_keys=True))
raise SystemExit(1 if failed else 0)
```

Run:

```bash
python3 "$WORK/audit-autoplay.py" "$WORK/baseline" \
  > "$WORK/baseline-autoplay.json"
cat "$WORK/baseline-autoplay.json"
```

Expected: both titles have non-empty adjacent responses and at least one shared exact `bingeGroup`. This file is the immediate baseline for Task 3; do not substitute older measurements.

- [ ] **Step 8: Record baseline latency medians per representative request**

Run:

```bash
python3 - "$WORK" <<'PY' > "$WORK/baseline-latency.json"
from pathlib import Path
from statistics import median
import json
import sys

root = Path(sys.argv[1]) / "baseline"
summary = {}
for path in sorted(root.glob("*-1.seconds")):
    label = path.name.removesuffix("-1.seconds")
    values = [float((root / f"{label}-{run}.seconds").read_text()) for run in range(1, 6)]
    summary[label] = {"samples": len(values), "median": median(values), "maximum": max(values)}
print(json.dumps(summary, indent=2, sort_keys=True))
PY
cat "$WORK/baseline-latency.json"
```

Expected: 11 entries, each with exactly five successful samples. Task 3 compares every label separately.

### Task 2: Generate and prove the complete candidate in the pinned image

**Files:**
- Create temporarily: `$WORK/generate-candidate.py`
- Create temporarily: `$WORK/validate-candidate.mjs`
- Create temporarily: `$WORK/candidate-config.json`
- Create temporarily: `$WORK/candidate-put.json`

**Interfaces:**
- Consumes: Task 1's asserted complete `$WORK/before-config.json`.
- Produces: deterministic complete candidate; exact seven-field semantic diff; three regex patterns; 35 ranked expressions; three preferred expressions; 16 required expressions; pinned-image synthetic proof; replacement-only PUT payload.

- [ ] **Step 1: Write the deterministic complete-config generator**

Create `$WORK/generate-candidate.py` with:

```python
from __future__ import annotations

import json
import sys
from pathlib import Path

RESOLUTIONS = ("2160p", "1080p", "720p", "480p")
SERVICES = ("torbox", "realdebrid")
CHANGED_FIELDS = {
    "preferredResolutions", "excludedResolutions", "sortCriteria",
    "rankedRegexPatterns", "rankedStreamExpressions",
    "preferredStreamExpressions", "requiredStreamExpressions",
}


def entry(expression: str) -> dict[str, object]:
    return {"expression": expression, "enabled": True}


def ranked(name: str, expression: str) -> dict[str, object]:
    return {"expression": f"/* {name} */ {expression}", "score": 0, "enabled": True}


def build_ranked_expressions() -> tuple[list[dict[str, object]], dict[tuple[str, str], list[str]]]:
    items = [
        ranked("C", "regexMatched(streams, 'catalan-name', 'catalan-cat')"),
        ranked("S", "negate(rseMatched(streams, 'C'), merge(language(streams, 'Spanish'), regexMatched(streams, 'spanish-alias')))"),
        ranked("E", "negate(merge(rseMatched(streams, 'C'), rseMatched(streams, 'S')), language(streams, 'English'))"),
    ]
    pool_tags: dict[tuple[str, str], list[str]] = {}
    pairs = ((service, resolution) for service in SERVICES for resolution in RESOLUTIONS)
    for index, (service, resolution) in enumerate(pairs):
        pool = f"service(resolution(rseMatched(streams, 'E'), '{resolution}'), '{service}')"
        reference = f"(count(cached({pool})) > 0 ? cached({pool}) : uncached({pool}))"
        positive = f"size({reference}, 1)"
        maximum = f"max(values({positive}, 'size'))"
        tags = [f"{index}{suffix}" for suffix in ("m", "h", "q", "e")]
        items.append(ranked(tags[0], f"size({positive}, {maximum}, {maximum})"))
        for name, denominator in zip(tags[1:], (2, 4, 8)):
            items.append(ranked(name, f"size({reference}, 1, {maximum} / {denominator})"))
        pool_tags[(service, resolution)] = tags
    return items, pool_tags


def build_candidate(before: dict[str, object]) -> dict[str, object]:
    candidate = json.loads(json.dumps(before))
    ranked_expressions, pool_tags = build_ranked_expressions()
    candidate["preferredResolutions"] = list(RESOLUTIONS)
    candidate["excludedResolutions"] = [
        value for value in before.get("excludedResolutions", []) if value != "480p"
    ]
    old_global = before["sortCriteria"]["global"]
    candidate["sortCriteria"]["global"] = [
        {"key": "streamExpressionMatched", "direction": "desc"},
        *[criterion for criterion in old_global if criterion["key"] != "streamExpressionMatched"],
    ]
    not_subs = r"(?![\s\[(_\-.,]*sub(title)?s?(?=[\s\)\]_.\-,]|$))"
    left = r"(?<![^\s\[(_\-.,])"
    right = r"(?=[\s\)\]_.\-,]|$)"
    candidate["rankedRegexPatterns"] = [
        {"name": "catalan-name", "pattern": f"/{left}(catalan|català|catala){not_subs}{right}/iu", "score": 0},
        {"name": "catalan-cat", "pattern": f"/{left}(CAT){not_subs}{right}/u", "score": 0},
        {"name": "spanish-alias", "pattern": f"/{left}(castellano|español|espanol){not_subs}{right}/iu", "score": 0},
    ]
    candidate["rankedStreamExpressions"] = ranked_expressions
    candidate["preferredStreamExpressions"] = [
        entry("/* Catalan */ rseMatched(streams, 'C')"),
        entry("/* Spanish */ rseMatched(streams, 'S')"),
        entry("/* English */ rseMatched(streams, 'E')"),
    ]
    required: list[dict[str, object]] = []
    for language in ("C", "S"):
        for resolution in RESOLUTIONS:
            required.append(entry(
                f"passthrough(slice(resolution(rseMatched(streams, '{language}'), '{resolution}'), 0, 1), 'limit')"
            ))
    for service in SERVICES:
        for resolution in RESOLUTIONS:
            tags = pool_tags[(service, resolution)]
            pool = f"service(resolution(rseMatched(streams, 'E'), '{resolution}'), '{service}')"
            maximum = f"slice(rseMatched(streams, {tags[0]!r}), 0, 1)"
            half = f"slice(negate({maximum}, rseMatched(streams, {tags[1]!r})), 0, 1)"
            quarter = f"slice(negate(merge({maximum}, {half}), rseMatched(streams, {tags[2]!r})), 0, 1)"
            eighth = f"slice(negate(merge({maximum}, {half}, {quarter}), rseMatched(streams, {tags[3]!r})), 0, 1)"
            selected = f"merge({maximum}, {half}, {quarter}, {eighth})"
            required.append(entry(f"slice(merge({selected}, negate({selected}, {pool})), 0, 4)"))
    candidate["requiredStreamExpressions"] = required
    return candidate


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate-candidate.py BEFORE_JSON OUT_JSON")
    before_path, output_path = map(Path, sys.argv[1:])
    before = json.loads(before_path.read_text())
    if len(before.get("requiredStreamExpressions") or []) != 12:
        raise SystemExit("baseline must contain exactly 12 required expressions")
    if any(before.get(field) is not None for field in (
        "rankedRegexPatterns", "rankedStreamExpressions", "preferredStreamExpressions"
    )):
        raise SystemExit("baseline language/ranking fields differ from the approved starting state")
    if before.get("preferredResolutions") != ["2160p", "1080p", "720p"] or "480p" not in before.get("excludedResolutions", []):
        raise SystemExit("baseline resolution policy differs from the approved starting state")
    if before.get("resultLimits") != {"global": 60, "service": 4, "resolution": 4, "mode": "conjunctive"}:
        raise SystemExit("baseline result limits differ from the approved starting state")
    candidate = build_candidate(before)
    untouched_before = {key: value for key, value in before.items() if key not in CHANGED_FIELDS}
    untouched_after = {key: value for key, value in candidate.items() if key not in CHANGED_FIELDS}
    if untouched_before != untouched_after:
        raise SystemExit("generator changed an unrelated top-level field")
    expressions = [
        item["expression"]
        for field in ("rankedStreamExpressions", "preferredStreamExpressions", "requiredStreamExpressions")
        for item in candidate[field]
    ]
    counts = {
        "rankedRegexPatterns": len(candidate["rankedRegexPatterns"]),
        "rankedStreamExpressions": len(candidate["rankedStreamExpressions"]),
        "preferredStreamExpressions": len(candidate["preferredStreamExpressions"]),
        "requiredStreamExpressions": len(candidate["requiredStreamExpressions"]),
    }
    if counts != {"rankedRegexPatterns": 3, "rankedStreamExpressions": 35, "preferredStreamExpressions": 3, "requiredStreamExpressions": 16}:
        raise SystemExit(f"unexpected array counts: {counts}")
    if len(expressions) > 200 or sum(map(len, expressions)) > 50_000 or max(map(len, expressions)) > 3_000:
        raise SystemExit("candidate exceeds pinned expression limits")
    output_path.write_text(json.dumps(candidate, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({
        **counts,
        "expressionCount": len(expressions),
        "expressionCharacters": sum(map(len, expressions)),
        "maximumExpressionLength": max(map(len, expressions)),
        "maximumResults": 40,
    }, indent=2))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Generate the complete candidate and prove the seven-field diff**

Run:

```bash
python3 -m py_compile "$WORK/generate-candidate.py"
python3 "$WORK/generate-candidate.py" \
  "$WORK/before-config.json" "$WORK/candidate-config.json" \
  | tee "$WORK/candidate-summary.json"

jq -S 'del(
  .preferredResolutions,
  .excludedResolutions,
  .sortCriteria,
  .rankedRegexPatterns,
  .rankedStreamExpressions,
  .preferredStreamExpressions,
  .requiredStreamExpressions
)' "$WORK/before-config.json" > "$WORK/before-unchanged.json"
jq -S 'del(
  .preferredResolutions,
  .excludedResolutions,
  .sortCriteria,
  .rankedRegexPatterns,
  .rankedStreamExpressions,
  .preferredStreamExpressions,
  .requiredStreamExpressions
)' "$WORK/candidate-config.json" > "$WORK/candidate-unchanged.json"
cmp "$WORK/before-unchanged.json" "$WORK/candidate-unchanged.json"

jq -e '
  .preferredResolutions == ["2160p","1080p","720p","480p"] and
  .excludedResolutions == ["1440p","576p","360p","240p","144p","Unknown"] and
  .sortCriteria.global[0] == {"key":"streamExpressionMatched","direction":"desc"} and
  .sortCriteria.global[1:] == [
    {"key":"service","direction":"desc"},
    {"key":"cached","direction":"desc"},
    {"key":"resolution","direction":"desc"},
    {"key":"size","direction":"desc"},
    {"key":"quality","direction":"desc"}
  ] and
  .resultLimits == {"global":60,"service":4,"resolution":4,"mode":"conjunctive"} and
  .autoPlay == null
' "$WORK/candidate-config.json" >/dev/null

jq -n --slurpfile config "$WORK/candidate-config.json" \
  '{config:$config[0]}' > "$WORK/candidate-put.json"
chmod 600 "$WORK/candidate-config.json" "$WORK/candidate-put.json"
```

Expected: generator summary reports 54 expressions, fewer than 50,000 total characters, less than 3,000 characters for the longest expression and maximum 40 results; `cmp` exits zero; only the seven declared fields differ.

- [ ] **Step 3: Write the pinned-image synthetic validator**

Create `$WORK/validate-candidate.mjs` with:

```javascript
import fs from 'node:fs';
import { StreamSelector, extractNamesFromExpression } from '/app/packages/core/dist/parser/streamExpression.js';
import { compileRegex } from '/app/packages/core/dist/utils/index.js';

const candidate = JSON.parse(fs.readFileSync('/tmp/candidate.json', 'utf8'));
const regexes = await Promise.all(candidate.rankedRegexPatterns.map(async entry => ({
  ...entry, regex: await compileRegex(entry.pattern, true),
})));
const selector = new StreamSelector({
  queryType: 'movie', type: 'movie', id: 'tt0000001', metadata: null,
  isAnime: false, isMovie: true, isSeries: false,
});

function stream(id, options = {}) {
  const {
    filename = `${id}.mkv`, folderName, languages = ['English'],
    service = 'torbox', cached = true, resolution = '2160p',
  } = options;
  const item = {
    id, type: 'http', filename, folderName,
    addon: {
      preset: {type: 'test-preset', id: 'test-preset', options: {}},
      manifestUrl: 'https://example.com/manifest.json', enabled: true,
      name: 'Test Addon', timeout: 30000,
    },
    service: {id: service, cached},
    parsedFile: {
      languages, resolution, quality: 'WEB-DL', visualTags: [],
      audioTags: [], audioChannels: [], subtitles: [],
    },
    torrent: {},
  };
  if (!Object.hasOwn(options, 'size') || options.size !== undefined) {
    item.size = Object.hasOwn(options, 'size') ? options.size : 1;
  }
  return item;
}

function applyRegexes(streams) {
  for (const item of streams) {
    const names = regexes.filter(({regex}) => {
      regex.lastIndex = 0;
      const filenameMatch = regex.test(item.filename);
      regex.lastIndex = 0;
      const folderMatch = item.folderName ? regex.test(item.folderName) : false;
      return filenameMatch || folderMatch;
    }).map(({name}) => name);
    if (names.length) item.rankedRegexesMatched = names;
  }
}

async function applyRanked(streams) {
  applyRegexes(streams);
  for (const item of streams) item.rankedStreamExpressionsMatched = [];
  for (const entry of candidate.rankedStreamExpressions) {
    const selected = await selector.select(streams, entry.expression);
    const names = extractNamesFromExpression(entry.expression);
    for (const selectedItem of selected) {
      const original = streams.find(item => item.id === selectedItem.id);
      original.rankedStreamExpressionsMatched.push(...names);
    }
  }
}

const catalanCases = [
  ['Catalan', true], ['CATALÀ', true], ['Catala', true], ['[CAT]', true],
  ['movie.CAT.1080p', true], ['movie.cat.1080p', false], ['bobcat', false],
  ['CAT subs', false], ['CAT [subs]', false], ['Catalan.subtitle', false],
  ['Catala-subtitles', false], ['Español', false],
];
for (const [value, expected] of catalanCases) {
  const item = stream(`regex-${value}`, {filename: value});
  applyRegexes([item]);
  const actual = (item.rankedRegexesMatched ?? []).some(name => name.startsWith('catalan'));
  if (actual !== expected) throw new Error(`Catalan regex ${JSON.stringify(value)} expected=${expected} actual=${actual}`);
}

const spanishCases = [
  ['Castellano', true], ['ESPAÑOL', true], ['Espanol', true],
  ['Espanol subs', false], ['Español(subtitles)', false], ['despanol', false],
];
for (const [value, expected] of spanishCases) {
  const item = stream(`spanish-${value}`, {filename: value});
  applyRegexes([item]);
  const actual = (item.rankedRegexesMatched ?? []).includes('spanish-alias');
  if (actual !== expected) throw new Error(`Spanish regex ${JSON.stringify(value)} expected=${expected} actual=${actual}`);
}

const mixed = [
  stream('catalan-spanish', {filename: 'Film.CAT.1080p', languages: ['Spanish', 'English']}),
  stream('spanish-english', {filename: 'Film.Castellano.1080p', languages: ['English']}),
  stream('english', {languages: ['English']}),
  stream('unknown', {languages: []}),
];
await applyRanked(mixed);
const expectedLanguage = {'catalan-spanish': 'C', 'spanish-english': 'S', english: 'E', unknown: null};
for (const item of mixed) {
  const actual = ['C', 'S', 'E'].filter(name => item.rankedStreamExpressionsMatched.includes(name));
  const expected = expectedLanguage[item.id];
  if ((expected === null && actual.length !== 0) ||
      (expected !== null && (actual.length !== 1 || actual[0] !== expected))) {
    throw new Error(`language precedence failed for ${item.id}: ${actual}`);
  }
}

const languageRows = [
  stream('c-rd-480', {filename: 'Film.Catalan.480p', languages: [], service: 'realdebrid', resolution: '480p'}),
  stream('c-tb-480', {filename: 'Film.CAT.480p', languages: [], service: 'torbox', resolution: '480p'}),
  stream('s-rd-480', {filename: 'Film.Castellano.480p', languages: ['Spanish'], service: 'realdebrid', resolution: '480p'}),
  stream('s-tb-480', {filename: 'Film.Spanish.480p', languages: ['Spanish'], service: 'torbox', resolution: '480p'}),
];
await applyRanked(languageRows);
const sortedLanguageRows = [...languageRows].sort((a, b) =>
  (a.service.id === b.service.id ? 0 : a.service.id === 'torbox' ? -1 : 1));
for (const [language, expectedId] of [['C', 'c-tb-480'], ['S', 's-tb-480']]) {
  const required = candidate.requiredStreamExpressions.find(entry =>
    entry.expression.includes(`rseMatched(streams, '${language}')`) &&
    entry.expression.includes("'480p'"));
  const selected = await selector.select(sortedLanguageRows, required.expression);
  if (selected.length !== 1 || selected[0].id !== expectedId) {
    throw new Error(`${language}/480p TorBox-first selection failed: ${selected.map(item => item.id)}`);
  }
  if (!Array.isArray(selected[0].passthrough) || !selected[0].passthrough.includes('limit')) {
    throw new Error(`${language}/480p row lacks limiter passthrough`);
  }
}

async function poolCase(name, rows, expectedIds) {
  const streams = rows.map(([id, size, cached = true]) => stream(id, {size, cached}));
  streams.reverse(); // prove pre-sort tags do not choose the final row order
  await applyRanked(streams);
  const sorted = [...streams].sort((a, b) =>
    Number(b.service.cached) - Number(a.service.cached) || (b.size ?? 0) - (a.size ?? 0));
  const required = candidate.requiredStreamExpressions.find(entry =>
    entry.expression.includes("service(resolution(rseMatched(streams, 'E'), '2160p'), 'torbox')"));
  const selected = (await selector.select(sorted, required.expression)).map(item => item.id);
  if (JSON.stringify(selected) !== JSON.stringify(expectedIds)) {
    throw new Error(`${name}: expected ${expectedIds}, got ${selected}`);
  }
  if (new Set(selected).size !== selected.length || selected.length !== Math.min(4, rows.length)) {
    throw new Error(`${name}: uniqueness/count invariant failed`);
  }
}

await poolCase('spread', [['s30', 30], ['s20', 20], ['s15', 15], ['s10', 10], ['s7', 7], ['s5', 5], ['s2', 2]], ['s30', 's15', 's7', 's2']);
await poolCase('clustered', [['c30', 30], ['c29', 29], ['c28', 28], ['c27', 27], ['c26', 26]], ['c30', 'c29', 'c28', 'c27']);
await poolCase('sparse', [['p30', 30], ['p8', 8], ['p7', 7]], ['p30', 'p8', 'p7']);
await poolCase('missing-size', [['m1', undefined], ['m2', undefined], ['m3', undefined], ['m4', undefined], ['m5', undefined]], ['m5', 'm4', 'm3', 'm2']);
await poolCase('cached-reference', [['cached30', 30, true], ['cached7', 7, true], ['cached2', 2, true], ['uncached1000', 1000, false], ['uncached500', 500, false]], ['cached30', 'cached7', 'cached2', 'uncached1000']);

for (const field of ['rankedStreamExpressions', 'preferredStreamExpressions', 'requiredStreamExpressions']) {
  for (const entry of candidate[field]) await selector.select([stream(`parse-${field}`)], entry.expression);
}
console.log(JSON.stringify({
  regexCases: catalanCases.length + spanishCases.length,
  languageCases: mixed.length + languageRows.length,
  poolCases: 5,
  expressionArraysParsed: true,
}));
```

- [ ] **Step 4: Run all regexes and expressions inside the exact pinned image**

Run:

```bash
docker run --rm \
  --entrypoint /nodejs/bin/node \
  -e BASE_URL=https://example.invalid \
  -e SECRET_KEY=0000000000000000000000000000000000000000000000000000000000000000 \
  -v "$WORK/validate-candidate.mjs:/tmp/check.mjs:ro" \
  -v "$WORK/candidate-config.json:/tmp/candidate.json:ro" \
  ghcr.io/viren070/aiostreams:v2.31.1 \
  /tmp/check.mjs | tee "$WORK/pinned-validation.json"
```

Expected:

```json
{"regexCases":18,"languageCases":8,"poolCases":5,"expressionArraysParsed":true}
```

This proof must pass before any live write. It covers full-name and uppercase-token positives, lowercase/substring/subtitle negatives, disjoint precedence, 480p, TorBox-first language selection, limiter passthrough, spread, clustered, sparse, missing-size and cached-reference pools, uniqueness and exact `min(4, candidate count)` counts.

- [ ] **Step 5: Inspect the generated mechanism and freeze the payload**

Run:

```bash
jq -c '{
  regexes:[.rankedRegexPatterns[]|{name,pattern,score}],
  ranked:(.rankedStreamExpressions|length),
  preferred:[.preferredStreamExpressions[].expression],
  required:(.requiredStreamExpressions|length),
  resolutions:.preferredResolutions,
  excluded:.excludedResolutions,
  leadingSort:.sortCriteria.global[0],
  limits:.resultLimits,
  autoPlay
}' "$WORK/candidate-config.json" | tee "$WORK/candidate-inspection.json"
shasum -a 256 "$WORK/candidate-config.json" > "$WORK/candidate-config.sha256"
cat "$WORK/candidate-config.sha256"
```

Expected: three exact bounded regexes, 35 ranked expressions, preferred `Catalan/Spanish/English`, 16 required expressions, four resolutions, descending leading category sort, unchanged limits and `autoPlay: null`. Do not edit the generated JSON by hand after hashing it.

### Task 3: Apply once, audit every gate and restore on any failure

**Files:**
- Create temporarily: `$WORK/rollback-put.json`
- Create temporarily: `$WORK/readback-config.json`
- Create temporarily: `$WORK/audit-responses.py`
- Create temporarily: `$WORK/after/*`
- Modify: `docs/feat/20260729115122-aiostreams-language-and-tier-fallback/plan.md` only to record passed gates and non-secret summaries.

**Interfaces:**
- Consumes: Task 1 rollback config, route and baselines; Task 2 frozen candidate and PUT payload.
- Produces: exactly one live candidate write; immediate semantic readback; language/order/pool/bounds audit; five post-change timings per endpoint; adjacent-episode comparison; user-observed Stremio 1.12.1/Tizen 6 transition. Any failure produces a verified complete rollback instead.

- [ ] **Step 1: Load the `safety` skill and define rollback before the live write**

This task mutates externally visible saved configuration. Load the `safety` skill and follow its confirmation flow before continuing.

Then define this function in the persistent shell:

```bash
rollback() {
  jq -n --slurpfile config "$WORK/before-config.json" \
    '{config:$config[0]}' > "$WORK/rollback-put.json"
  curl --fail --silent --show-error \
    -X PUT "$B/api/v1/user" \
    -H "$AUTH" -H 'Content-Type: application/json' \
    -d @"$WORK/rollback-put.json" > "$WORK/rollback-response.json"
  jq -e '.success == true' "$WORK/rollback-response.json" >/dev/null
  curl --fail --silent --show-error \
    "$B/api/v1/user?raw=true" -H "$AUTH" > "$WORK/rollback-readback-response.json"
  jq '.data.userData' "$WORK/rollback-readback-response.json" > "$WORK/rollback-config.json"
  cmp \
    <(jq -S . "$WORK/before-config.json") \
    <(jq -S . "$WORK/rollback-config.json")
  shasum -a 256 "$WORK/rollback-config.json" > "$WORK/rollback-config.sha256"
  cmp \
    <(cut -d ' ' -f1 "$WORK/before-config.sha256") \
    <(cut -d ' ' -f1 "$WORK/rollback-config.sha256")
  echo 'rollback restored and verified'
}
```

Expected: function definition emits no output. Invoke it immediately after every failed step below. A successful PUT without verified readback is not a completed rollback.

- [ ] **Step 2: Submit the complete candidate exactly once**

After the `safety` confirmation, run:

```bash
curl --fail --silent --show-error \
  -X PUT "$B/api/v1/user" \
  -H "$AUTH" -H 'Content-Type: application/json' \
  -d @"$WORK/candidate-put.json" > "$WORK/put-response.json" \
  || { rollback; exit 1; }
jq -e '.success == true and .detail == "User updated successfully"' \
  "$WORK/put-response.json" >/dev/null \
  || { rollback; exit 1; }
echo 'complete candidate accepted once'
```

Expected: one success line. Do not submit an intermediate diagnostic configuration and do not restart any pod.

- [ ] **Step 3: Read back immediately and require complete semantic equality**

Run:

```bash
curl --fail --silent --show-error \
  "$B/api/v1/user?raw=true" -H "$AUTH" > "$WORK/readback-response.json" \
  || { rollback; exit 1; }
jq '.data.userData' "$WORK/readback-response.json" > "$WORK/readback-config.json"
diff -u \
  <(jq -S . "$WORK/candidate-config.json") \
  <(jq -S . "$WORK/readback-config.json") \
  > "$WORK/readback.diff" \
  || { cat "$WORK/readback.diff"; rollback; exit 1; }
shasum -a 256 "$WORK/readback-config.json" > "$WORK/readback-config.sha256"
echo 'candidate readback matches semantically'
```

Expected: no diff and one success line. This comparison also proves that all unrelated fields remain unchanged because Task 2 proved the candidate's seven-field diff.

- [ ] **Step 4: Capture five post-change diagnostic responses and timings per endpoint**

Run:

```bash
if ! while IFS=$'\t' read -r label type id; do
  url="$B/stremio/$U/$EP/stream/$type/$id.json"
  for run in 1 2 3 4 5; do
    curl --fail --silent --show-error \
      -H 'User-Agent: AIOStreams/rollout-audit' \
      -o "$WORK/after/$label-$run.json" \
      -w '%{time_total}\n' "$url" \
      > "$WORK/after/$label-$run.seconds" || exit 1
    jq -e '
      (.streams | type == "array") and
      ([.streams[] | select(.streamData.id != null)] | length > 0)
    ' "$WORK/after/$label-$run.json" >/dev/null || exit 1
  done
done < "$WORK/endpoints.tsv"; then
  rollback
  exit 1
fi
test "$(fd -e seconds . "$WORK/after" | wc -l | tr -d ' ')" -eq 55 \
  || { rollback; exit 1; }
echo 'captured 55 successful post-change timings with streamData'
```

Expected: `captured 55 successful post-change timings with streamData`.

- [ ] **Step 5: Write the concrete live response audit**

Create `$WORK/audit-responses.py` with:

```python
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

RESOLUTIONS = {"2160p", "1080p", "720p", "480p"}
CATEGORY_ORDER = {"Catalan": 0, "Spanish": 1, "English": 2}
SERVICE_ORDER = {"torbox": 0, "realdebrid": 1}


def real_rows(path: Path) -> list[dict]:
    payload = json.loads(path.read_text())
    return [stream for stream in payload.get("streams", []) if (stream.get("streamData") or {}).get("id")]


root = Path(sys.argv[1])
baseline_candidates = json.loads(Path(sys.argv[2]).read_text())
failed = False
summary = {}
observed_catalan = 0
observed_480p = {"Catalan": 0, "Spanish": 0, "English": 0}

for path in sorted(root.glob("*-1.json")):
    rows = real_rows(path)
    ids = [(row.get("streamData") or {}).get("id") for row in rows]
    categories = []
    language_slots = defaultdict(list)
    english_pools = defaultdict(list)
    for row in rows:
        data = row["streamData"]
        preferred = data.get("streamExpressionMatched") or {}
        category = preferred.get("name")
        if category not in CATEGORY_ORDER:
            print(f"FAIL {path.name}: row {data['id']} lacks exactly one preferred language category")
            failed = True
            continue
        categories.append(category)
        parsed = data.get("parsedFile") or {}
        resolution = parsed.get("resolution")
        service = (data.get("service") or {}).get("id")
        tags = set(data.get("rankedStreamExpressionsMatched") or [])
        membership = [name for name in ("C", "S", "E") if name in tags]
        expected_membership = {"Catalan": "C", "Spanish": "S", "English": "E"}[category]
        if membership != [expected_membership]:
            print(f"FAIL {path.name}: row {data['id']} memberships={membership} category={category}")
            failed = True
        languages = set(parsed.get("languages") or [])
        if category == "English" and "English" not in languages:
            print(f"FAIL {path.name}: English row {data['id']} lacks parsed English")
            failed = True
        if resolution not in RESOLUTIONS:
            print(f"FAIL {path.name}: row {data['id']} has disallowed resolution {resolution}")
            failed = True
        if resolution == "480p":
            observed_480p[category] += 1
        if category in ("Catalan", "Spanish"):
            language_slots[(category, resolution)].append(row)
            observed_catalan += category == "Catalan"
        else:
            english_pools[(service, resolution)].append(row)

    if len(ids) != len(set(ids)):
        print(f"FAIL {path.name}: duplicate retained stream IDs")
        failed = True
    if len(rows) > 40 or len(rows) > 60:
        print(f"FAIL {path.name}: result overflow {len(rows)}")
        failed = True
    if categories != sorted(categories, key=CATEGORY_ORDER.__getitem__):
        print(f"FAIL {path.name}: category order is not Catalan -> Spanish -> English")
        failed = True
    for slot, slot_rows in language_slots.items():
        if len(slot_rows) > 1:
            print(f"FAIL {path.name}: language slot {slot} has {len(slot_rows)} rows")
            failed = True
    for pool, pool_rows in english_pools.items():
        if len(pool_rows) > 4 or len({row['streamData']['id'] for row in pool_rows}) != len(pool_rows):
            print(f"FAIL {path.name}: English pool {pool} count/uniqueness failure")
            failed = True
        cached_seen_false = False
        sizes_by_cache = defaultdict(list)
        for row in pool_rows:
            data = row["streamData"]
            cached = (data.get("service") or {}).get("cached") is not False
            if not cached:
                cached_seen_false = True
            elif cached_seen_false:
                print(f"FAIL {path.name}: cached row follows uncached row in {pool}")
                failed = True
            sizes_by_cache[cached].append(data.get("size") or 0)
        for cached, sizes in sizes_by_cache.items():
            if sizes != sorted(sizes, reverse=True):
                print(f"FAIL {path.name}: size order failure in {pool} cached={cached}")
                failed = True

    summary[path.name.removesuffix("-1.json")] = {
        "rows": len(rows),
        "categories": {name: categories.count(name) for name in CATEGORY_ORDER},
        "englishPools": {f"{service}/{resolution}": len(pool_rows) for (service, resolution), pool_rows in sorted(english_pools.items())},
    }

# Provider fallback evidence where the baseline exposed a candidate from the same
# language/resolution. The selector itself is also covered by the pinned proof.
for sample, sample_summary in summary.items():
    post_path = root / f"{sample}-1.json"
    for row in real_rows(post_path):
        data = row["streamData"]
        category = (data.get("streamExpressionMatched") or {}).get("name")
        if category not in ("Catalan", "Spanish"):
            continue
        resolution = (data.get("parsedFile") or {}).get("resolution")
        selected_service = (data.get("service") or {}).get("id")
        baseline_match = [item for item in baseline_candidates if
            item["sample"] == sample and
            item["category"] == category[0] and
            item["resolution"] == resolution]
        baseline_has_torbox = any(item["service"] == "torbox" for item in baseline_match)
        if baseline_has_torbox and selected_service != "torbox":
            print(f"FAIL {sample}: {category}/{resolution} selected {selected_service} despite baseline TorBox candidate")
            failed = True

if observed_catalan == 0:
    print("FAIL: no retained live Catalan-positive row")
    failed = True
print(json.dumps({"samples": summary, "observed480p": observed_480p, "catalanRows": observed_catalan}, indent=2, sort_keys=True))
raise SystemExit(1 if failed else 0)
```

- [ ] **Step 6: Run language, ordering, uniqueness, provider, pool and bounds checks**

Run:

```bash
python3 "$WORK/audit-responses.py" \
  "$WORK/after" "$WORK/baseline-candidates.json" \
  > "$WORK/response-audit.json" \
  || { cat "$WORK/response-audit.json"; rollback; exit 1; }
cat "$WORK/response-audit.json"
```

Expected: no `FAIL`; at least one retained Catalan row; all categories disjoint and ordered; at most one Catalan/Spanish row per resolution; TorBox selected whenever a baseline-visible eligible TorBox candidate exists; each English pool has at most four unique IDs in cached-first/size-descending response order; every response is at most 40. The exact dynamic membership and sparse-pool count invariant are guaranteed by the pinned-image proof and must also be manually inspected in `streamData.rankedStreamExpressionsMatched` for at least one dense movie, one regular-series episode and one anime episode.

- [ ] **Step 7: Inspect live dynamic membership for movie, series and anime**

Run:

```bash
for label in matrix breakingbad-e01 attackontitan-e01; do
  jq '[.streams[] | select(.streamData.id != null) | {
    id:.streamData.id,
    category:.streamData.streamExpressionMatched.name,
    service:.streamData.service.id,
    cached:.streamData.service.cached,
    resolution:.streamData.parsedFile.resolution,
    size:.streamData.size,
    tierTags:[.streamData.rankedStreamExpressionsMatched[] | select(test("^[0-7][mhqe]$"))]
  }]' "$WORK/after/$label-1.json" > "$WORK/$label-membership.json"
  jq -e '
    ([.[] | select(.category == "English")] | length > 0) and
    ([.[] | select(.category == "English") | .id] | length == unique | length)
  ' "$WORK/$label-membership.json" >/dev/null \
    || { rollback; exit 1; }
  cat "$WORK/$label-membership.json"
done
```

Expected: all three content classes contain explicit English rows with unique IDs; populated pools show a maximum tag and available half/quarter/eighth threshold tags, with untagged rows only as fallback. If the live samples do not expose a particular sparse condition, rely on Task 2's exact-image fixture for that condition rather than inventing live evidence.

- [ ] **Step 8: Enforce the per-endpoint latency gate**

Create `$WORK/compare-latency.py` with:

```python
from pathlib import Path
from statistics import median
import json
import sys

root = Path(sys.argv[1])
after_dir = sys.argv[2]
result = {}
failed = False
for path in sorted((root / "baseline").glob("*-1.seconds")):
    label = path.name.removesuffix("-1.seconds")
    before = [float((root / "baseline" / f"{label}-{run}.seconds").read_text()) for run in range(1, 6)]
    after = [float((root / after_dir / f"{label}-{run}.seconds").read_text()) for run in range(1, 6)]
    baseline_median = median(before)
    post_median = median(after)
    threshold = max(baseline_median * 1.10, baseline_median + 0.500)
    accepted = post_median <= threshold
    result[label] = {
        "baselineSamples": len(before), "postSamples": len(after),
        "baselineMedian": baseline_median, "postMedian": post_median,
        "threshold": threshold, "accepted": accepted,
    }
    failed |= not accepted
print(json.dumps(result, indent=2, sort_keys=True))
raise SystemExit(1 if failed else 0)
```

Run:

```bash
python3 "$WORK/compare-latency.py" "$WORK" after \
  > "$WORK/latency-after.json" \
  || { cat "$WORK/latency-after.json"; rollback; exit 1; }
cat "$WORK/latency-after.json"
```

Expected: for every endpoint, five post samples and a median no higher than `max(baseline × 1.10, baseline + 0.500s)`. This plan deliberately uses the stricter permitted behavior of rejecting the first failed paired sample rather than performing a second live config cycle merely to exercise the optional retry allowance.

- [ ] **Step 9: Enforce adjacent-episode overlap against the immediate baseline**

Run:

```bash
python3 "$WORK/audit-autoplay.py" "$WORK/after" \
  > "$WORK/after-autoplay.json" \
  || { cat "$WORK/after-autoplay.json"; rollback; exit 1; }

python3 - "$WORK" <<'PY' > "$WORK/autoplay-comparison.json"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
before = json.loads((root / "baseline-autoplay.json").read_text())
after = json.loads((root / "after-autoplay.json").read_text())
failed = False
comparison = {}
for title in ("breakingbad", "attackontitan"):
    accepted = (
        after[title]["sharedGroups"] >= 1 and
        after[title]["firstRowCoverage"] >= before[title]["firstRowCoverage"]
    )
    comparison[title] = {
        "baselineCoverage": before[title]["firstRowCoverage"],
        "postCoverage": after[title]["firstRowCoverage"],
        "postSharedGroups": after[title]["sharedGroups"],
        "accepted": accepted,
    }
    failed |= not accepted
print(json.dumps(comparison, indent=2, sort_keys=True))
raise SystemExit(1 if failed else 0)
PY
status=$?
cat "$WORK/autoplay-comparison.json"
if [ "$status" -ne 0 ]; then rollback; exit 1; fi
```

Expected: Breaking Bad and Attack on Titan each retain at least one exact adjacent group, and each post-change first-episode row coverage is no lower than its own Task 1 baseline.

- [ ] **Step 10: Require one real Stremio 1.12.1/Tizen 6 next-episode transition**

Using the actual Samsung/Tizen client:

1. Open one of the tested episodic titles.
2. Select a retained stream from the post-change response.
3. Let the episode reach its automatic transition.
4. Confirm that the next episode starts playback; opening only the next episode page or stream list is a failure.

Record only title, episode pair, client `Stremio 1.12.1`, platform `Tizen 6`, selected non-secret display identity and pass/fail in `$WORK/tizen-autoplay.txt`.

Expected: real playback starts automatically. On failure, run `rollback` immediately unless the user explicitly accepts the observation as a separate client issue; without explicit acceptance, the rollout is rejected.

- [ ] **Step 11: Record the verified runtime gate summary**

Run:

```bash
jq -n \
  --slurpfile candidate "$WORK/candidate-summary.json" \
  --slurpfile response "$WORK/response-audit.json" \
  --slurpfile autoplay "$WORK/autoplay-comparison.json" \
  '{candidate:$candidate[0], response:$response[0], autoplay:$autoplay[0]}' \
  > "$WORK/runtime-summary.json"
cat "$WORK/runtime-summary.json"
cat "$WORK/tizen-autoplay.txt"
```

Expected: compact non-secret evidence for all automated gates plus one passing Tizen transition. Do not proceed to persistence if any gate is missing, waived without explicit user acceptance, or represented only by an expectation.

### Task 4: Persist recovery state, update operator documentation and commit intentional files

**Files:**
- Modify: `docs/STREMIO-AIOSTREAMS.md`
- Modify: `docs/feat/20260726235500-feat-aiostreams-deployment/spec.md`
- Modify: `docs/feat/20260729115122-aiostreams-language-and-tier-fallback/context.md`
- Modify: `docs/feat/20260729115122-aiostreams-language-and-tier-fallback/plan.md`
- Do not touch: `docs/feat/20260726235500-feat-aiostreams-deployment/scratch.md`

**Interfaces:**
- Consumes: Task 3's exact verified `$WORK/readback-config.json`, runtime summaries, Tizen result and exact rollback hash.
- Produces: exact credential-free 1Password recovery template; current operator guide; historical supersession note; completed task record; local documentation commit containing only the four intentional Markdown files.

- [ ] **Step 1: Load the `safety` skill and back up the credential-free template**

Replacing a 1Password document mutates remote secret-management state. Load the `safety` skill and follow its confirmation flow before the edit.

Then run:

```bash
op document get aiostreams-config-template \
  --vault neumann --account "$OP_ACCOUNT" \
  --out-file "$WORK/aiostreams-config-template-before.json" --force
jq -e 'type == "object"' "$WORK/aiostreams-config-template-before.json" >/dev/null
chmod 600 "$WORK/aiostreams-config-template-before.json"
```

Expected: valid JSON backup in the private directory.

- [ ] **Step 2: Patch exactly the seven verified policy fields into the credential-free template**

Run:

```bash
jq --slurpfile live "$WORK/readback-config.json" '
  .preferredResolutions = $live[0].preferredResolutions |
  .excludedResolutions = $live[0].excludedResolutions |
  .sortCriteria = $live[0].sortCriteria |
  .rankedRegexPatterns = $live[0].rankedRegexPatterns |
  .rankedStreamExpressions = $live[0].rankedStreamExpressions |
  .preferredStreamExpressions = $live[0].preferredStreamExpressions |
  .requiredStreamExpressions = $live[0].requiredStreamExpressions
' "$WORK/aiostreams-config-template-before.json" \
  > "$WORK/aiostreams-config-template-after.json"

for file in before after; do
  jq -S 'del(
    .preferredResolutions,
    .excludedResolutions,
    .sortCriteria,
    .rankedRegexPatterns,
    .rankedStreamExpressions,
    .preferredStreamExpressions,
    .requiredStreamExpressions
  )' "$WORK/aiostreams-config-template-$file.json" \
    > "$WORK/template-$file-unchanged.json"
done
cmp "$WORK/template-before-unchanged.json" "$WORK/template-after-unchanged.json"
```

Expected: the seven policy fields are the only template differences. Never replace the credential-free template with the complete live config.

- [ ] **Step 3: Scan the candidate template before uploading it**

Run:

```bash
if rg -n -i \
  -e '"apiKey"\s*:\s*"[^" ]+' \
  -e 'Authorization:\s*Basic' \
  -e 'stremio/[^/ ]+/[^/ ]+/manifest\.json' \
  -e 'eyJ[A-Za-z0-9_-]{10,}' \
  -e 'ops_[A-Za-z0-9]{10,}' \
  "$WORK/aiostreams-config-template-after.json"; then
  echo 'credential-shaped data found in candidate template; stop'
  exit 1
fi
echo 'candidate recovery template contains no known credential shape'
```

Expected: no matches and one success line.

- [ ] **Step 4: Replace the 1Password document once and verify exact readback**

After the `safety` confirmation, run:

```bash
op document edit aiostreams-config-template \
  "$WORK/aiostreams-config-template-after.json" \
  --vault neumann --account "$OP_ACCOUNT"
op document get aiostreams-config-template \
  --vault neumann --account "$OP_ACCOUNT" \
  --out-file "$WORK/aiostreams-config-template-readback.json" --force
diff -u \
  <(jq -S . "$WORK/aiostreams-config-template-after.json") \
  <(jq -S . "$WORK/aiostreams-config-template-readback.json")
```

Expected: no diff. If edit or readback fails, restore with:

```bash
op document edit aiostreams-config-template \
  "$WORK/aiostreams-config-template-before.json" \
  --vault neumann --account "$OP_ACCOUNT"
```

- [ ] **Step 5: Update the operator guide with verified current behavior**

Replace the current movie-only representative-size section and stale current-config bullets in `docs/STREMIO-AIOSTREAMS.md` with text containing all of the following exact facts:

```markdown
### Language sections and dynamic size tiers

The saved AIOStreams v2.31.1 configuration displays three disjoint sections in
this order: Catalan, Spanish, English. Every section admits 2160p, 1080p, 720p
and 480p.

- Catalan is a filename/folder heuristic for bounded `Catalan`, `Català`,
  `Catala` or uppercase `CAT`. Lowercase `cat`, embedded substrings and markers
  followed by `sub`, `subs`, `subtitle` or `subtitles` do not qualify.
- Spanish uses native parsed Spanish plus bounded `Castellano`, `Español` and
  `Espanol`, excluding rows already claimed as Catalan.
- English requires native parsed English and excludes rows already claimed as
  Catalan or Spanish.

Catalan and Spanish retain at most one TorBox-first row per resolution across
providers; Real-Debrid is fallback. Those rows bypass only the conjunctive
service/resolution limiter so they do not consume English's four-row blocks.

English has separate TorBox and Real-Debrid pools for every resolution. If a
pool has cached rows, its size reference is the cached subset; otherwise it is
the uncached subset. The selector chooses distinct rows at the pool maximum,
then at or below one half, one quarter and one eighth of that maximum, and fills
missing slots from the best remaining globally sorted rows. Movies, regular
series and anime all use this policy, yielding exactly
`min(4, eligible candidate count)` rows per English pool.

The intended maximum is 4 Catalan + 4 Spanish + 32 English = 40 rows, under the
unchanged global limit of 60. `autoPlay` remains unchanged; rollout verification
requires non-regressing adjacent-episode `bingeGroup` coverage and one real
Stremio 1.12.1/Tizen 6 automatic playback transition.
```

Also update the current-config summary to state: four preferred resolutions; three ranked regexes; 35 ranked stream expressions; three preferred stream expressions; 16 required stream expressions; unchanged conjunctive `60/4/4` limits; unchanged `autoPlay: null`. Add only observed, non-secret Task 3 latency and autoplay summaries.

- [ ] **Step 6: Mark the prior fixed-size design as historical without rewriting it**

Immediately after the title in `docs/feat/20260726235500-feat-aiostreams-deployment/spec.md`, add:

```markdown
> **Historical reference:** The fixed, movie-only representative-size selectors
> documented here were replaced by the verified language-section and dynamic-
> tier policy in
> [`../20260729115122-aiostreams-language-and-tier-fallback/spec.md`](../20260729115122-aiostreams-language-and-tier-fallback/spec.md).
> The measurements and rollout evidence below remain the record of the earlier
> deployment state.
```

Expected: no historical measurements, commands or evidence are rewritten.

- [ ] **Step 7: Complete the task record with observed evidence**

Update `docs/feat/20260729115122-aiostreams-language-and-tier-fallback/context.md`:

- add `plan.md` to `FILES`;
- set the `PLAN` link to `plan.md`, cursor to `complete`, and status to `done`;
- set frontmatter status to `done`;
- append one final dated log entry with:
  - why the fixed selectors were replaced;
  - exact seven saved-config fields changed;
  - regex/ranked/preferred/required counts;
  - exact pre-change SHA-256 from `$WORK/before-config.sha256`;
  - compact live language, 480p, pool, result-bound, latency, adjacent-overlap and Tizen evidence from Task 3;
  - exact 1Password template readback result;
  - explicit confirmation that no image, Kubernetes, Cloudflare, provider, credential or Stremio-install state changed;
  - rollback status: retained and verified but not invoked, or invoked with the reason and verified restore evidence.

Do not paste raw authenticated URLs, route components, API responses, filenames containing credentials or live service keys.

- [ ] **Step 8: Mark this plan's checkboxes from actual execution and run documentation self-review**

Mark a checkbox complete only when its command and expected gate actually passed. Then run:

```bash
python3 - <<'PY'
from pathlib import Path

paths = [
    Path("docs/STREMIO-AIOSTREAMS.md"),
    Path("docs/feat/20260726235500-feat-aiostreams-deployment/spec.md"),
    Path("docs/feat/20260729115122-aiostreams-language-and-tier-fallback/context.md"),
    Path("docs/feat/20260729115122-aiostreams-language-and-tier-fallback/plan.md"),
]
patterns = [
    "T" + "BD", "T" + "ODO", "implement " + "later", "fill in " + "details",
    "<" * 7, "=" * 7, ">" * 7,
]
matches = [(str(path), pattern) for path in paths for pattern in patterns if pattern in path.read_text()]
if matches:
    raise SystemExit(f"placeholder or conflict marker found: {matches}")
PY
git diff --check
```

Expected: no unresolved placeholder/conflict and clean whitespace.

- [ ] **Step 9: Secret-scan the exact pending documentation diff**

Run:

```bash
git diff -- \
  docs/STREMIO-AIOSTREAMS.md \
  docs/feat/20260726235500-feat-aiostreams-deployment/spec.md \
  docs/feat/20260729115122-aiostreams-language-and-tier-fallback/context.md \
  docs/feat/20260729115122-aiostreams-language-and-tier-fallback/plan.md \
| rg -n -i \
  -e '"apiKey"\s*:\s*"[^" ]+' \
  -e 'Authorization:\s*Basic\s+[A-Za-z0-9+/=]+' \
  -e 'stremio/[0-9a-f-]{20,}/[^/ ]+/manifest\.json' \
  -e 'eyJ[A-Za-z0-9_-]{20,}' \
  -e 'ops_[A-Za-z0-9]{10,}' \
  && { echo 'credential-shaped text found; inspect and stop'; exit 1; } \
  || true
```

Expected: no credential-bearing match. The literal example patterns in this plan may match only if they are followed by real values; inspect every match rather than dismissing it automatically.

- [ ] **Step 10: Commit only the four intentional Markdown files**

Run:

```bash
git add \
  docs/STREMIO-AIOSTREAMS.md \
  docs/feat/20260726235500-feat-aiostreams-deployment/spec.md \
  docs/feat/20260729115122-aiostreams-language-and-tier-fallback/context.md \
  docs/feat/20260729115122-aiostreams-language-and-tier-fallback/plan.md
git diff --cached --name-only
git diff --cached --check
git commit -m 'feat(aiostreams): add language sections and dynamic tiers'
git status --short
```

Expected: the staged path list contains exactly those four files; the commit succeeds; every pre-existing unrelated status entry remains unchanged.

- [ ] **Step 11: Defer push until explicit approval**

Do not run `git push`. Report the local commit hash, exact automated gate summaries, user-observed Tizen result, 1Password readback result and whether rollback was invoked. Pushing is externally visible and requires separate explicit approval.
