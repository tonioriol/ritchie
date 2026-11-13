# Representative Movie Size Tiers Implementation Plan

> Tasks run sequentially. Checkboxes are marked complete only after the documented gate succeeds.

**Goal:** Make each populated movie `(debrid service, resolution)` block expose up to four distinct files at deliberate size targets while leaving series and anime behavior unchanged.

**Architecture:** Add 12 ordered native `requiredStreamExpressions` to the existing AIOStreams user config. The expressions run after deduplication and sorting, select one result per service at each size ceiling, and feed the existing conjunctive four-per-block limiter; no scraper instances, application code, Helm resources or Stremio manifests change.

**Tech Stack:** AIOStreams v2.31.1 User API, AIOStreams stream-expression language, `curl`, `jq`, Python 3, 1Password CLI, Markdown.

## Global Constraints

- Scope is movie-only; `queryType != 'movie'` must return all streams so series and anime remain unchanged.
- Movie targets are 2160p largest/≤20/≤10/≤5 GB, 1080p largest/≤10/≤5/≤2 GB, and 720p largest/≤2/≤1/≤500 MB.
- Preserve cached-first behavior, TorBox-before-Real-Debrid ordering, current formatter, title matching, deduplication, enabled presets, preset timeouts and size caps.
- Keep `resultLimits = {"mode":"conjunctive","global":60,"resolution":4,"service":4}` as the final safety limit.
- AIOStreams `PUT /api/v1/user` replaces the complete config; never send a partial config object.
- Store live credentials and backups only in a mode-`0700` temporary directory; never add them to Git.
- The 1Password `aiostreams-config-template` remains credential-free; update its expression array from verified live state rather than copying live service credentials.
- Do not modify or add `docs/feat/20260726235500-feat-aiostreams-deployment/scratch.md`.
- On any schema, read-back, movie-audit, non-movie-regression or material-latency failure, restore the complete pre-change config before continuing.

---

## File Structure

- Modify: `docs/STREMIO-AIOSTREAMS.md` — document the active representative-size policy, how it works, and how to verify/restore it.
- Modify: `docs/feat/20260726235500-feat-aiostreams-deployment/context.md` — record verified rollout evidence and final state.
- Modify: `docs/feat/20260726235500-feat-aiostreams-deployment/plan.md` — track execution checkboxes and observed evidence.
- Temporary only: `$WORK`, assigned by Task 1 to a UTC-stamped directory under `/tmp/` — credentials-free command artifacts plus secret-bearing config/response backups; mode `0700`, never committed.
- External state: AIOStreams user config and 1Password document `neumann/aiostreams-config-template`.

### Task 1: Capture a secure rollback point and reproducible baseline

**Files:**
- Read: `docs/STREMIO-AIOSTREAMS.md:47-75`
- Read: `docs/feat/20260726235500-feat-aiostreams-deployment/spec.md:505-627`
- Create temporarily: `/tmp/aiostreams-size-tiers-<UTC timestamp>/before-config.json`
- Create temporarily: `/tmp/aiostreams-size-tiers-<UTC timestamp>/before-response.json`
- Create temporarily: `/tmp/aiostreams-size-tiers-<UTC timestamp>/baseline/*.json`

**Interfaces:**
- Consumes: 1Password fields `neumann/aiostreams/config_uuid` and `config_password`; `GET /api/v1/user?raw=true`.
- Produces: shell variables `WORK`, `B`, `U`, `P`, `AUTH`, `EP`; complete rollback config at `$WORK/before-config.json`; normalized non-movie baselines and latency samples under `$WORK/baseline/`.

- [x] **Step 1: Confirm the only pre-existing workspace change is the user's scratch file**

Run:

```bash
git status --short
```

Expected: only `?? docs/feat/20260726235500-feat-aiostreams-deployment/scratch.md`; no unrelated tracked file is staged.

- [x] **Step 2: Create a private run directory and obtain API credentials without echoing them**

Run:

```bash
umask 077
WORK="/tmp/aiostreams-size-tiers-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 700 "$WORK" "$WORK/baseline" "$WORK/after"
export OP_ACCOUNT=PRBEZ6ELGNCMDIK6YVMRW5TTXQ
B=https://aiostreams.tonioriol.com
U=$(op read "op://neumann/aiostreams/config_uuid" --account "$OP_ACCOUNT")
P=$(op read "op://neumann/aiostreams/config_password" --account "$OP_ACCOUNT")
AUTH="Authorization: Basic $(printf '%s' "$U:$P" | base64)"
test -n "$U" && test -n "$P" && printf 'credentials loaded; WORK=%s\n' "$WORK"
```

Expected: one line containing only the temporary directory path. If `op` reports that the account is not signed in, stop and authenticate interactively; do not obtain credentials through a temporary Kubernetes Secret.

- [x] **Step 3: Fetch and validate the complete pre-change response**

Run:

```bash
curl --fail --silent --show-error "$B/api/v1/user?raw=true" -H "$AUTH" > "$WORK/before-response.json"
jq -e '.success == true and (.data.userData | type == "object") and (.data.encryptedPassword | type == "string" and length > 0)' \
  "$WORK/before-response.json" >/dev/null
jq '.data.userData' "$WORK/before-response.json" > "$WORK/before-config.json"
EP=$(jq -r '.data.encryptedPassword' "$WORK/before-response.json")
jq -c '{limits:.resultLimits, required:(.requiredStreamExpressions // [] | length), presets:[.presets[]|{id:.instanceId,enabled}], services:[.services[]|select(.enabled)|.id]}' \
  "$WORK/before-config.json"
```

Expected: limits `conjunctive/60/4/4`, zero pre-existing required expressions (or an explicitly reviewed prior value), three active presets plus disabled Torz, and enabled `torbox`/`realdebrid`. Stop if the baseline does not match the documented state.

- [x] **Step 4: Define exact baseline endpoints and fetch each twice**

Run:

```bash
cat > "$WORK/endpoints.tsv" <<'EOF'
matrix	movie	tt0133093
dune2	movie	tt15239678
godfather	movie	tt0068646
breakingbad	series	tt0903747:1:1
attackontitan	series	tt2560140:1:1
EOF

while IFS=$'\t' read -r label type id; do
  url="$B/stremio/$U/$EP/stream/$type/$id.json"
  for run in 1 2; do
    curl --fail --silent --show-error \
      -o "$WORK/baseline/$label-$run.json" \
      -w '%{time_total}\n' "$url" > "$WORK/baseline/$label-$run.seconds"
    jq -e '.streams | type == "array"' "$WORK/baseline/$label-$run.json" >/dev/null
  done
done < "$WORK/endpoints.tsv"
```

Expected: ten valid stream responses and ten latency files; no endpoint error.

- [x] **Step 5: Normalize the two non-movie baselines and establish upstream stability**

Run:

```bash
for label in breakingbad attackontitan; do
  for run in 1 2; do
    jq -S '[.streams[] | {
      name,
      description,
      filename:.behaviorHints.filename,
      size:.behaviorHints.videoSize
    }]' "$WORK/baseline/$label-$run.json" > "$WORK/baseline/$label-$run.normalized.json"
  done
  if cmp -s "$WORK/baseline/$label-1.normalized.json" "$WORK/baseline/$label-2.normalized.json"; then
    echo "$label stable"
  else
    echo "$label varied between baseline calls; use a third-call majority comparison after rollout"
  fi
done
```

Expected: preferably both stable. Variation is recorded rather than mistaken for a config regression.

- [x] **Step 6: Record baseline latency summary without committing response data**

Run:

```bash
python3 - "$WORK" <<'PY'
from pathlib import Path
from statistics import median
import sys

root = Path(sys.argv[1]) / "baseline"
values = [float(path.read_text()) for path in root.glob("*.seconds")]
print(f"baseline samples={len(values)} median={median(values):.3f}s max={max(values):.3f}s")
PY
```

Expected: 10 samples and a median in the existing approximate 1–3 second range. Keep the observed value for Task 2.

### Task 2: Apply the expression array atomically and prove behavior

**Files:**
- Read: `docs/feat/20260726235500-feat-aiostreams-deployment/spec.md:551-627`
- Create temporarily: `$WORK/required-expressions.json`
- Create temporarily: `$WORK/candidate-config.json`
- Create temporarily: `$WORK/put.json`
- Create temporarily: `$WORK/readback-config.json`
- Create temporarily: `$WORK/audit-size-tiers.py`

**Interfaces:**
- Consumes: Task 1's `WORK`, `B`, `U`, `AUTH`, `EP`, `before-config.json`, endpoint list and baselines.
- Produces: live config with exactly 12 approved expressions; read-back proof; movie tier audit; non-movie identity comparison; latency comparison. Restores `before-config.json` on failure.

- [x] **Step 1: Extract the approved expression array from the committed spec**

Run:

```bash
python3 - "$WORK/required-expressions.json" <<'PY'
from pathlib import Path
import json, re, sys

spec = Path("docs/feat/20260726235500-feat-aiostreams-deployment/spec.md").read_text()
match = re.search(
    r"Set `requiredStreamExpressions` to the following ordered array:\n\n```jsonc\n(.*?)\n```",
    spec,
    re.S,
)
if not match:
    raise SystemExit("approved expression block not found")
items = json.loads(match.group(1))
if len(items) != 12 or not all(item == {"enabled": True, "expression": item["expression"]} for item in items):
    raise SystemExit("approved expression array has unexpected shape")
Path(sys.argv[1]).write_text(json.dumps(items, indent=2) + "\n")
print("extracted 12 approved expressions")
PY
```

Expected: `extracted 12 approved expressions`.

- [x] **Step 2: Build the complete candidate config and prove it changes only one field**

Run:

```bash
jq --slurpfile expressions "$WORK/required-expressions.json" \
  '.requiredStreamExpressions = $expressions[0]' \
  "$WORK/before-config.json" > "$WORK/candidate-config.json"

jq -S 'del(.requiredStreamExpressions)' "$WORK/before-config.json" > "$WORK/before-without-expressions.json"
jq -S 'del(.requiredStreamExpressions)' "$WORK/candidate-config.json" > "$WORK/candidate-without-expressions.json"
cmp "$WORK/before-without-expressions.json" "$WORK/candidate-without-expressions.json"
jq -e '.requiredStreamExpressions | length == 12' "$WORK/candidate-config.json" >/dev/null
jq -n --slurpfile config "$WORK/candidate-config.json" '{config:$config[0]}' > "$WORK/put.json"
```

Expected: `cmp` exits zero and the payload contains the entire prior config plus the one new array.

- [x] **Step 3: Define rollback before mutating live state**

Run in the same shell:

```bash
rollback() {
  jq -n --slurpfile config "$WORK/before-config.json" '{config:$config[0]}' > "$WORK/rollback-put.json"
  curl --fail --silent --show-error -X PUT "$B/api/v1/user" \
    -H "$AUTH" -H 'Content-Type: application/json' -d @"$WORK/rollback-put.json" \
    > "$WORK/rollback-response.json"
  curl --fail --silent --show-error "$B/api/v1/user?raw=true" -H "$AUTH" \
    | jq '.data.userData' > "$WORK/rollback-readback.json"
  cmp <(jq -S . "$WORK/before-config.json") <(jq -S . "$WORK/rollback-readback.json")
}
```

Expected: the function is defined without output. Invoke it immediately after any failed step below.

- [x] **Step 4: Apply the complete candidate config**

Run:

```bash
curl --fail --silent --show-error -X PUT "$B/api/v1/user" \
  -H "$AUTH" -H 'Content-Type: application/json' -d @"$WORK/put.json" \
  > "$WORK/put-response.json"
jq -e '.success == true and .detail == "User updated successfully"' "$WORK/put-response.json" >/dev/null \
  || { rollback; exit 1; }
```

Expected: successful update response. No Stremio reinstall or pod restart is needed.

- [x] **Step 5: Read back and require byte-for-byte semantic equality with the candidate**

Run:

```bash
curl --fail --silent --show-error "$B/api/v1/user?raw=true" -H "$AUTH" > "$WORK/readback-response.json"
jq '.data.userData' "$WORK/readback-response.json" > "$WORK/readback-config.json"
diff -u <(jq -S . "$WORK/candidate-config.json") <(jq -S . "$WORK/readback-config.json") \
  || { rollback; exit 1; }
jq -e '.requiredStreamExpressions | length == 12' "$WORK/readback-config.json" >/dev/null \
  || { rollback; exit 1; }
```

Expected: no diff and 12 expressions.

- [x] **Step 6: Fetch post-change responses and latency samples**

Run:

```bash
while IFS=$'\t' read -r label type id; do
  url="$B/stremio/$U/$EP/stream/$type/$id.json"
  for run in 1 2; do
    curl --fail --silent --show-error \
      -o "$WORK/after/$label-$run.json" \
      -w '%{time_total}\n' "$url" > "$WORK/after/$label-$run.seconds" \
      || { rollback; exit 1; }
    jq -e '.streams | type == "array"' "$WORK/after/$label-$run.json" >/dev/null \
      || { rollback; exit 1; }
  done
done < "$WORK/endpoints.tsv"
```

Expected: ten valid post-change responses.

- [x] **Step 7: Write the concrete movie-tier audit before evaluating results**

Create `$WORK/audit-size-tiers.py` with:

```python
from collections import OrderedDict
from itertools import combinations
from pathlib import Path
import json
import re
import sys

CAPS = {
    "2160p": [5 * 1024**3, 10 * 1024**3, 20 * 1024**3],
    "1080p": [2 * 1024**3, 5 * 1024**3, 10 * 1024**3],
    "720p": [500 * 1024**2, 1 * 1024**3, 2 * 1024**3],
}
ORDER = {("TB", "2160p"): 0, ("TB", "1080p"): 1, ("TB", "720p"): 2,
         ("RD", "2160p"): 3, ("RD", "1080p"): 4, ("RD", "720p"): 5}
ROW = re.compile(r"^(TB|RD) ([⚡⏳]) (2160p|1080p|720p)\b")
CACHE_ORDER = {"⚡": 0, "⏳": 1}
PAIR_RUN = re.compile(r"(.+)-([12])\.json$")

failed = False
pair_fingerprints = {}
for filename in sys.argv[1:]:
    payload = json.loads(Path(filename).read_text())
    groups = OrderedDict()
    observed_services = []
    relevant = []
    for stream in payload["streams"]:
        name = stream.get("name", "")
        match = ROW.match(name)
        if not match:
            continue
        service, cache_marker, resolution = match.groups()
        key = (service, resolution)
        size = stream.get("behaviorHints", {}).get("videoSize")
        fingerprint = (stream.get("behaviorHints", {}).get("filename"), size, name)
        relevant.append(fingerprint)
        if size is not None:
            groups.setdefault(key, []).append((cache_marker, int(size), fingerprint))
            observed_services.append(service)
    if not groups:
        print(f"FAIL {filename}: no formatted TB/RD size rows found")
        failed = True
    pair_match = PAIR_RUN.search(Path(filename).name)
    if pair_match:
        label, run = pair_match.groups()
        pair_fingerprints.setdefault(label, {})[run] = relevant
    if "RD" in observed_services and "TB" in observed_services[observed_services.index("RD"):]:
        print(f"FAIL {filename}: TorBox row appears after Real-Debrid")
        failed = True
    for key, rows in sorted(groups.items(), key=lambda item: ORDER[item[0]]):
        sizes = [size for _, size, _ in rows]
        unique = len({fingerprint for _, _, fingerprint in rows})
        display_sizes = sorted(sizes)
        print(f"{filename} {key[0]} {key[1]}: {[round(size / 1e9, 2) for size in display_sizes]} GB")
        if len(rows) > 4 or unique != len(rows):
            print(f"FAIL {key}: rows={len(rows)} unique={unique}")
            failed = True
        for previous, current in zip(rows, rows[1:]):
            previous_marker, previous_size, _ = previous
            current_marker, current_size, _ = current
            if CACHE_ORDER[previous_marker] > CACHE_ORDER[current_marker]:
                print(f"FAIL {filename} {key}: cached rows do not precede uncached rows")
                failed = True
            if previous_marker == current_marker and previous_size < current_size:
                print(f"FAIL {filename} {key}: rows are not size-descending within {previous_marker}")
                failed = True
        capped_sizes = sorted(sizes[1:])
        caps = CAPS[key[1]]
        assignable = any(
            all(size <= cap for size, cap in zip(capped_sizes, selected_caps))
            for selected_caps in combinations(caps, len(capped_sizes))
        )
        if not assignable:
            print(f"FAIL {key}: capped rows fit no distinct-tier assignment")
            failed = True
        if len(rows) < 4:
            print(f"INFO {key}: {len(rows)} populated choices; absent tiers are allowed when no candidate exists")

for label, runs in sorted(pair_fingerprints.items()):
    if {"1", "2"} <= runs.keys():
        if runs["1"] != runs["2"]:
            print(f"FAIL {label}: run 1 and 2 relevant stream fingerprints differ")
            failed = True
        else:
            print(f"PAIR {label}: run 1 and 2 relevant stream fingerprints match")
raise SystemExit(1 if failed else 0)
```

Expected: a deterministic audit using exact `behaviorHints.videoSize` bytes, not rounded formatter text. It preserves response order within each group, treats the first observed group row as the unconstrained choice, checks cached-first/size-descending order, and requires repeated movie sample fingerprints to match.

- [x] **Step 8: Run the movie audit on both post-change samples**

Run:

```bash
python3 "$WORK/audit-size-tiers.py" \
  "$WORK/after/matrix-1.json" "$WORK/after/matrix-2.json" \
  "$WORK/after/dune2-1.json" "$WORK/after/dune2-2.json" \
  "$WORK/after/godfather-1.json" "$WORK/after/godfather-2.json" \
  > "$WORK/movie-audit.txt" \
  || { cat "$WORK/movie-audit.txt"; rollback; exit 1; }
cat "$WORK/movie-audit.txt"
```

Expected: no `FAIL`; each dense block has four unique rows, the first observed row is the unconstrained cached-first/size-descending choice, remaining rows satisfy ascending 5/10/20, 2/5/10 or 0.5/1/2 GB assignment caps, and each movie pair reports matching relevant stream fingerprints. Sparse blocks may report allowed absent tiers.

- [x] **Step 9: Prove series and anime normalized output is unchanged**

Run:

```bash
if ! {
for label in breakingbad attackontitan; do
  for run in 1 2; do
    jq -S '[.streams[] | {
      name,
      description,
      filename:.behaviorHints.filename,
      size:.behaviorHints.videoSize
    }]' "$WORK/after/$label-$run.json" > "$WORK/after/$label-$run.normalized.json"
  done
  if cmp -s "$WORK/baseline/$label-1.normalized.json" "$WORK/after/$label-1.normalized.json" \
     || cmp -s "$WORK/baseline/$label-1.normalized.json" "$WORK/after/$label-2.normalized.json" \
     || cmp -s "$WORK/baseline/$label-2.normalized.json" "$WORK/after/$label-1.normalized.json" \
     || cmp -s "$WORK/baseline/$label-2.normalized.json" "$WORK/after/$label-2.normalized.json"; then
    echo "$label unchanged"
  else
    echo "$label changed outside expected upstream variance"
    rollback
    exit 1
  fi
done
} > "$WORK/nonmovie-audit.txt"; then
  cat "$WORK/nonmovie-audit.txt"
  exit 1
fi
cat "$WORK/nonmovie-audit.txt"
```

Expected: both labels print `unchanged`. If baseline calls already varied, fetch one additional before declaring failure and compare against the union of stable identities.

- [x] **Step 10: Reject material latency regression**

Run:

```bash
if ! python3 - "$WORK" > "$WORK/latency-summary.txt" <<'PY'
from pathlib import Path
from statistics import median
import sys

root = Path(sys.argv[1])
labels = ("matrix", "dune2", "godfather")
before = [float((root / "baseline" / f"{label}-{run}.seconds").read_text()) for label in labels for run in (1, 2)]
after = [float((root / "after" / f"{label}-{run}.seconds").read_text()) for label in labels for run in (1, 2)]
b, a = median(before), median(after)
limit = max(b * 1.25, b + 0.5)
print(f"before movie samples={len(before)} median={b:.3f}s max={max(before):.3f}s")
print(f"after movie samples={len(after)} median={a:.3f}s max={max(after):.3f}s")
print(f"movie rejection-threshold={limit:.3f}s accepted={a <= limit}")
if a > limit:
    raise SystemExit(1)
PY
then
  cat "$WORK/latency-summary.txt"
  rollback
  exit 1
fi
cat "$WORK/latency-summary.txt"
```

Expected: movie-only after median at or below the larger of 25% or 0.5 seconds over the movie-only baseline median. On failure, run `rollback` and stop.

### Task 3: Persist the recoverable template and document verified behavior

**Files:**
- Modify: `docs/STREMIO-AIOSTREAMS.md:47-75, 246-257`
- Modify: `docs/feat/20260726235500-feat-aiostreams-deployment/context.md:41-47, 168-184`
- Modify: `docs/feat/20260726235500-feat-aiostreams-deployment/plan.md`
- Do not touch: `docs/feat/20260726235500-feat-aiostreams-deployment/scratch.md`

**Interfaces:**
- Consumes: Task 2's verified `$WORK/readback-config.json`, audit output and latency summary.
- Produces: credential-free 1Password recovery template matching the verified expression policy; operator documentation; final task record; local Git commit containing only intentional Markdown files.

- [x] **Step 1: Back up the current credential-free 1Password template**

Run:

```bash
op document get aiostreams-config-template --vault neumann \
  --out-file "$WORK/aiostreams-config-template-before.json" --force
jq -e 'type == "object"' "$WORK/aiostreams-config-template-before.json" >/dev/null
```

Expected: valid JSON backup in the private temporary directory.

- [x] **Step 2: Patch only the verified expression array into the credential-free template**

Run:

```bash
jq --slurpfile live "$WORK/readback-config.json" \
  '.requiredStreamExpressions = $live[0].requiredStreamExpressions' \
  "$WORK/aiostreams-config-template-before.json" \
  > "$WORK/aiostreams-config-template-after.json"

jq -S 'del(.requiredStreamExpressions)' "$WORK/aiostreams-config-template-before.json" \
  > "$WORK/template-before-without-expressions.json"
jq -S 'del(.requiredStreamExpressions)' "$WORK/aiostreams-config-template-after.json" \
  > "$WORK/template-after-without-expressions.json"
cmp "$WORK/template-before-without-expressions.json" "$WORK/template-after-without-expressions.json"
jq -e '.requiredStreamExpressions | length == 12' "$WORK/aiostreams-config-template-after.json" >/dev/null
```

Expected: expression array is the only template change.

- [x] **Step 3: Scan the candidate template for all known credential shapes before uploading**

Run:

```bash
if rg -n -i \
  -e '[A-Za-z0-9]{32,}' \
  -e '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
  -e 'eyJ[A-Za-z0-9_-]{10,}' \
  -e 'ops_[A-Za-z0-9]{10,}' \
  -e 'stremio/[^/ ]+/[^/ ]+/manifest\.json' \
  "$WORK/aiostreams-config-template-after.json"; then
  echo 'candidate template contains credential-shaped data; inspect and stop'
  exit 1
fi
```

Expected: no matches. If the pre-existing credential-free template intentionally contains obvious placeholder strings, narrow the scan only after manually proving each match is not live.

- [x] **Step 4: Replace the 1Password document and verify exact read-back**

Run:

```bash
op document edit aiostreams-config-template \
  "$WORK/aiostreams-config-template-after.json" --vault neumann
op document get aiostreams-config-template --vault neumann \
  --out-file "$WORK/aiostreams-config-template-readback.json" --force
diff -u \
  <(jq -S . "$WORK/aiostreams-config-template-after.json") \
  <(jq -S . "$WORK/aiostreams-config-template-readback.json")
```

Expected: no diff. If upload/read-back fails, restore with `op document edit aiostreams-config-template "$WORK/aiostreams-config-template-before.json" --vault neumann`.

- [x] **Step 5: Update the operator guide with verified current state**

Add to `docs/STREMIO-AIOSTREAMS.md`:

```markdown
### Representative movie sizes

Movie blocks use 12 ordered `requiredStreamExpressions` to select up to four
distinct files per debrid provider and resolution:

| Resolution | Choices |
|---|---|
| 2160p | largest cached-first result, then ≤20 GB, ≤10 GB, ≤5 GB |
| 1080p | largest cached-first result, then ≤10 GB, ≤5 GB, ≤2 GB |
| 720p | largest cached-first result, then ≤2 GB, ≤1 GB, ≤500 MB |

Expressions are evaluated after sorting. Earlier selections are removed before
the next expression, so overlapping ceilings yield distinct rows. Missing
tiers are omitted rather than duplicated. `queryType != 'movie'` returns all
streams, leaving series and anime unchanged. The existing 4-per-resolution,
per-service conjunctive limit remains the final safety cap.
```

Also add `requiredStreamExpressions: 12 movie-only representative-size selectors` to the current-config summary and record the observed Task 2 audit/latency numbers.

- [x] **Step 6: Finish the task record with evidence, not expectations**

Update `docs/feat/20260726235500-feat-aiostreams-deployment/context.md` with a final LOG entry titled `2026-07-27 — Representative movie-size tiers applied`. Its fields must contain:

```markdown
- Why: four largest rows per block were near-identical and did not provide useful bandwidth choices.
- What changed: added 12 movie-only ordered required stream expressions; refreshed the credential-free 1Password config template.
- How: complete-config backup, one-field candidate diff, whole-config PUT, exact read-back comparison, three-movie tier audit, series/anime identity comparison and before/after latency sampling.
```

Copy the complete contents of `$WORK/movie-audit.txt` and `$WORK/latency-summary.txt` into the Evidence field, and the complete contents of `$WORK/nonmovie-audit.txt` plus the exact read-back count (`12`) and 1Password no-diff result into the Verification field. Set frontmatter `status: done`, PLAN cursor/status to `complete`/`done`, and update Final state from “size-descending per block” to “up to four representative sizes per movie resolution/provider.”

- [x] **Step 7: Mark this plan complete and self-review all documentation**

Completed verification: placeholder scan found no unresolved placeholders after removing this step's self-referential pattern text from the completed plan record; whitespace check was clean. Check all plan boxes only after their commands have succeeded. Final review later strengthened the movie audit and narrowed the latency gate to movie samples only.

- [x] **Step 8: Secret-scan the exact pending documentation diff**

Run:

```bash
git diff -- \
  docs/STREMIO-AIOSTREAMS.md \
  docs/feat/20260726235500-feat-aiostreams-deployment/context.md \
  docs/feat/20260726235500-feat-aiostreams-deployment/plan.md \
| rg -n -i \
  -e '[A-Za-z0-9]{32,}' \
  -e 'purevpn0s[0-9]' \
  -e '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
  -e 'eyJ[A-Za-z0-9_-]{10,}' \
  -e 'ops_[A-Za-z0-9]{10,}' \
  && { echo 'credential-shaped text found; inspect before committing'; exit 1; } \
  || true
```

Expected: no credential match. Review any match manually; never dismiss it solely because it occurs in Markdown.

- [x] **Step 9: Commit only the three intentional documentation files**

Run:

```bash
git add \
  docs/STREMIO-AIOSTREAMS.md \
  docs/feat/20260726235500-feat-aiostreams-deployment/context.md \
  docs/feat/20260726235500-feat-aiostreams-deployment/plan.md
git diff --cached --name-only
git commit -m "feat(aiostreams): add representative movie sizes"
git status --short
```

Expected: cached paths list exactly those three files. After commit, the only remaining status entry is the user's untracked `docs/feat/20260726235500-feat-aiostreams-deployment/scratch.md`.

- [x] **Step 10: Defer push until explicit approval**

Do not run `git push` as part of this plan. Report the local commit hash and verification evidence, then obtain explicit approval before pushing because push is externally visible.
