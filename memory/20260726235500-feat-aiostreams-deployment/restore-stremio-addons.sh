#!/usr/bin/env bash
# Restore Stremio addons from the 1Password backups taken during the AIOStreams migration.
#
#   ./restore-stremio-addons.sh removed   # re-add only the 5 debrid addons that were removed
#   ./restore-stremio-addons.sh full      # replace the whole collection with the 29-addon snapshot
#
# Backups live in 1Password (vault: neumann) as documents:
#   stremio-removed-debrid-addons  — the 5 removed addons, full fidelity
#   stremio-addons-full-backup     — the complete pre-migration collection
#
# Requires: op (signed in), jq, curl.
set -euo pipefail

MODE="${1:-}"
OP_ACCOUNT="${OP_ACCOUNT:-PRBEZ6ELGNCMDIK6YVMRW5TTXQ}"
VAULT=neumann
STREMIO_ITEM=lg7upsh7jholgnnguty4pmoydy # 1P item "Stremio" (tonioriol+stremio@gmail.com)
API=https://api.strem.io

case "$MODE" in
removed | full) ;;
*)
	echo "usage: $0 {removed|full}" >&2
	exit 2
	;;
esac

echo "==> logging in to Stremio"
EMAIL=$(op item get "$STREMIO_ITEM" --account "$OP_ACCOUNT" --fields username)
PASS=$(op item get "$STREMIO_ITEM" --account "$OP_ACCOUNT" --reveal --fields password)
AUTH_KEY=$(jq -n --arg e "$EMAIL" --arg p "$PASS" '{type:"Auth",type_:"Login",email:$e,password:$p}' |
	curl -s -m 30 -X POST "$API/api/login" -H 'Content-Type: application/json' -d @- |
	jq -r '.result.authKey // empty')
[ -n "$AUTH_KEY" ] || {
	echo "login failed" >&2
	exit 1
}

echo "==> fetching current collection"
CURRENT=$(jq -n --arg k "$AUTH_KEY" '{type:"AddonCollectionGet",authKey:$k,update:true}' |
	curl -s -m 30 -X POST "$API/api/addonCollectionGet" -H 'Content-Type: application/json' -d @-)
echo "    currently installed: $(jq '.result.addons|length' <<<"$CURRENT")"

if [ "$MODE" = full ]; then
	echo "==> restoring FULL pre-migration collection"
	PAYLOAD=$(op document get stremio-addons-full-backup --vault "$VAULT" --account "$OP_ACCOUNT" |
		jq --arg k "$AUTH_KEY" '{type:"AddonCollectionSet",authKey:$k,addons:.addons}')
else
	echo "==> re-adding the 5 removed debrid addons"
	REMOVED=$(op document get stremio-removed-debrid-addons --vault "$VAULT" --account "$OP_ACCOUNT")
	PAYLOAD=$(jq -n --arg k "$AUTH_KEY" --argjson cur "$CURRENT" --argjson rem "$REMOVED" '
    ($rem.addons | map(.transportUrl)) as $urls
    | {type:"AddonCollectionSet", authKey:$k,
       addons: (($cur.result.addons | map(select(.transportUrl as $u | $urls | index($u) | not))) + $rem.addons)}')
fi

echo "    submitting $(jq '.addons|length' <<<"$PAYLOAD") addons"
RES=$(curl -s -m 45 -X POST "$API/api/addonCollectionSet" -H 'Content-Type: application/json' -d "$PAYLOAD")
if [ "$(jq -r '.error.message // "none"' <<<"$RES")" != none ]; then
	echo "FAILED: $(jq -r '.error.message' <<<"$RES")" >&2
	echo "Note: 'Max descriptor size reached' means the collection exceeds Stremio's ~100KB cap." >&2
	exit 1
fi

echo "==> verifying"
jq -n --arg k "$AUTH_KEY" '{type:"AddonCollectionGet",authKey:$k,update:true}' |
	curl -s -m 30 -X POST "$API/api/addonCollectionGet" -H 'Content-Type: application/json' -d @- |
	jq -r '"    now installed: \(.result.addons|length)"'
echo "done"
