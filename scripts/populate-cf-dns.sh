#!/usr/bin/env bash
set -euo pipefail

# Populate DNS records on Cloudflare zones from our backup
# Run from ritchie/ directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi

CF_API="https://api.cloudflare.com/client/v4"

add_record() {
  local zone_id="$1" type="$2" name="$3" content="$4" ttl="${5:-1}" priority="${6:-}" proxied="${7:-false}"
  local data="{\"type\":\"${type}\",\"name\":\"${name}\",\"content\":\"${content}\",\"ttl\":${ttl},\"proxied\":${proxied}}"
  if [[ -n "$priority" ]]; then
    data="{\"type\":\"${type}\",\"name\":\"${name}\",\"content\":\"${content}\",\"ttl\":${ttl},\"priority\":${priority},\"proxied\":${proxied}}"
  fi
  local resp
  resp=$(curl -s -X POST "${CF_API}/zones/${zone_id}/dns_records" \
    -H "X-Auth-Email: ${CF_EMAIL}" \
    -H "X-Auth-Key: ${CF_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$data")
  local success
  success=$(echo "$resp" | jq -r '.success')
  if [[ "$success" == "true" ]]; then
    echo "  ✅ ${type} ${name} → ${content}"
  else
    local errmsg
    errmsg=$(echo "$resp" | jq -r '.errors[0].message // "Unknown"')
    if echo "$errmsg" | grep -qi "already exists"; then
      echo "  ⏭️  ${type} ${name} → ${content} (already exists)"
    else
      echo "  ❌ ${type} ${name} → ${content}: ${errmsg}"
    fi
  fi
}

google_mx() {
  local zone_id="$1"
  add_record "$zone_id" MX "@" "aspmx.l.google.com" 1 1
  add_record "$zone_id" MX "@" "alt1.aspmx.l.google.com" 1 5
  add_record "$zone_id" MX "@" "alt2.aspmx.l.google.com" 1 5
  add_record "$zone_id" MX "@" "alt3.aspmx.l.google.com" 1 10
  add_record "$zone_id" MX "@" "alt4.aspmx.l.google.com" 1 10
}

echo "=== Populating CF DNS records from backup ==="
echo ""

# bertomeuiglesias.com — 09dbc1977277cbcb24cee0157b45adad
echo "--- bertomeuiglesias.com ---"
ZID="09dbc1977277cbcb24cee0157b45adad"
add_record "$ZID" A "bertomeuiglesias.com" "188.226.140.165" 1
add_record "$ZID" CNAME "www.bertomeuiglesias.com" "bertomeuiglesias.com" 1
google_mx "$ZID"
echo ""

# boira.band — ca2dddbd063530da57a108539a460fe4
echo "--- boira.band ---"
ZID="ca2dddbd063530da57a108539a460fe4"
add_record "$ZID" A "boira.band" "188.226.140.165" 1
add_record "$ZID" CNAME "www.boira.band" "boira.band" 1
google_mx "$ZID"
echo ""

# juanjoseoriol.com — a97babfbceae45784a7ee27f6c67377a
echo "--- juanjoseoriol.com ---"
ZID="a97babfbceae45784a7ee27f6c67377a"
google_mx "$ZID"
echo ""

# lodrago.net — 699208ac3c417fa60bd07c13b3090d30
echo "--- lodrago.net ---"
ZID="699208ac3c417fa60bd07c13b3090d30"
add_record "$ZID" A "lodrago.net" "188.226.140.165" 1
add_record "$ZID" CNAME "www.lodrago.net" "lodrago.net" 1
google_mx "$ZID"
add_record "$ZID" TXT "lodrago.net" "google-site-verification=3HH9-ZDQWUW25YLVWGBsHD3BDoxQfsnjPaNjqWPv3VM" 1
echo ""

# neutronica.net — fc5eb1cd92b9f4506718e75f4cb53c75
echo "--- neutronica.net ---"
ZID="fc5eb1cd92b9f4506718e75f4cb53c75"
add_record "$ZID" A "neutronica.net" "216.239.32.21" 1
add_record "$ZID" A "www.neutronica.net" "216.239.32.21" 1
google_mx "$ZID"
echo ""

# ultra.coffee — 491c9aace32fcd9cf75ddf242babb377
echo "--- ultra.coffee ---"
ZID="491c9aace32fcd9cf75ddf242babb377"
add_record "$ZID" TXT "ultra.coffee" "google-site-verification=rpg0L4MV-ee7OnwW-iaAKktxe1O-y3O1PcI-YtfHsfg" 1
add_record "$ZID" MX "@" "smtp.google.com" 1 1
echo ""

# adamnfinecupof.coffee — bbdc9dea9947c7744b1eb036f2b6c1d7
echo "--- adamnfinecupof.coffee ---"
ZID="bbdc9dea9947c7744b1eb036f2b6c1d7"
# Was a URL redirect to www — create a placeholder A record + www CNAME
# The URL redirect will need a CF Redirect Rule (can't be done via DNS)
echo "  ℹ️  Was a NC URL redirect — no DNS records to create"
echo "  ℹ️  Set up a CF Redirect Rule if needed"
echo ""

# orioliglesias.com — 2b5dfe76ca85863b62eb07d8a6942569
echo "--- orioliglesias.com ---"
ZID="2b5dfe76ca85863b62eb07d8a6942569"
# NC email forwarding MX records — user says they don't use this
# URL redirect — was pointing to parking page
echo "  ℹ️  Was NC email forwarding + parking page — user confirmed not in use"
echo ""

# gosverd.com — 4cba4b37378ca9f5c57ea72e31ae83ba
echo "--- gosverd.com ---"
echo "  ℹ️  No DNS records existed — clean slate"
echo ""

echo "=== Done! ==="
