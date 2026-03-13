#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# migrate-domains-to-cloudflare.sh
#
# Migrates ALL domains from Namecheap → Cloudflare Registrar.
# Phases:
#   1. Discovery  — list NC domains + existing CF zones (read-only)
#   2. Add zones  — add missing domains as CF zones
#   3. Nameservers — update NS at Namecheap to point to CF
#   4. Wait       — poll until CF zones become active
#   5. Unlock     — unlock domains at Namecheap
#   6. Auth codes — request EPP auth codes (sent to email)
#   7. Transfer   — open CF dashboard for manual transfer initiation
#
# Requires: curl, xmllint (libxml2), jq
# Config:   source ritchie/.env before running, or it auto-sources it
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# --- Load env ---
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi

# --- Validate required vars ---
for var in CF_EMAIL CF_API_KEY CF_ACCOUNT_ID NAMECHEAP_API_USER NAMECHEAP_API_KEY; do
  if [[ -z "${!var:-}" ]]; then
    echo "❌ Missing env var: $var (set in ritchie/.env)"
    exit 1
  fi
done

# --- Get public IPv4 for NC API (NC requires IPv4) ---
CLIENT_IP=$(curl -s -4 https://api.ipify.org 2>/dev/null || curl -s https://checkip.amazonaws.com | tr -d '\n')
if [[ -z "$CLIENT_IP" ]]; then
  echo "❌ Could not detect public IPv4. Check internet connection."
  exit 1
fi

NC_API="https://api.namecheap.com/xml.response"
CF_API="https://api.cloudflare.com/client/v4"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC_COL='\033[0m' # No Color
BOLD='\033[1m'

log()  { echo -e "${BLUE}[INFO]${NC_COL} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC_COL} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC_COL} $*"; }
err()  { echo -e "${RED}[ERR]${NC_COL} $*"; }

confirm() {
  local msg="$1"
  echo ""
  echo -e "${BOLD}${YELLOW}⚠️  $msg${NC_COL}"
  read -rp "Continue? [y/N] " answer
  if [[ "${answer,,}" != "y" ]]; then
    echo "Aborted."
    exit 0
  fi
}

###############################################################################
# Namecheap API helpers
###############################################################################

nc_api_call() {
  local command="$1"
  shift
  local url="${NC_API}?ApiUser=${NAMECHEAP_API_USER}&ApiKey=${NAMECHEAP_API_KEY}&UserName=${NAMECHEAP_API_USER}&Command=${command}&ClientIp=${CLIENT_IP}"
  for param in "$@"; do
    url+="&${param}"
  done
  curl -s "$url"
}

# Parse domain list XML into "SLD TLD" pairs
nc_get_domains() {
  local page=1
  local page_size=100
  local all_domains=""

  while true; do
    local xml
    xml=$(nc_api_call "namecheap.domains.getList" "PageSize=${page_size}" "Page=${page}")

    # Check for errors
    local status
    status=$(echo "$xml" | xmllint --xpath 'string(//*[local-name()="ApiResponse"]/@Status)' - 2>/dev/null || echo "ERROR")
    if [[ "$status" != "OK" ]]; then
      local errmsg
      errmsg=$(echo "$xml" | xmllint --xpath 'string(//*[local-name()="Error"])' - 2>/dev/null || echo "Unknown error")
      err "Namecheap API error: $errmsg"
      return 1
    fi

    # Extract domains
    local domains
    domains=$(echo "$xml" | xmllint --xpath '//*[local-name()="Domain"]/@Name' - 2>/dev/null | \
      sed 's/ Name="/\n/g' | sed 's/"//g' | grep -v '^$' || true)

    if [[ -z "$domains" ]]; then
      break
    fi

    all_domains+="${domains}"$'\n'

    # Check if more pages
    local total_items
    total_items=$(echo "$xml" | xmllint --xpath 'string(//*[local-name()="Paging"]/*[local-name()="TotalItems"])' - 2>/dev/null || echo "0")
    local fetched=$((page * page_size))
    if [[ "$fetched" -ge "$total_items" ]]; then
      break
    fi
    page=$((page + 1))
  done

  echo "$all_domains" | grep -v '^$' | sort
}

nc_get_domain_info() {
  local domain="$1"
  local sld="${domain%%.*}"
  local tld="${domain#*.}"
  nc_api_call "namecheap.domains.getInfo" "DomainName=${domain}"
}

nc_set_nameservers() {
  local domain="$1"
  local ns1="$2"
  local ns2="$3"
  local sld="${domain%%.*}"
  local tld="${domain#*.}"
  nc_api_call "namecheap.domains.dns.setCustom" "SLD=${sld}" "TLD=${tld}" "Nameservers=${ns1},${ns2}"
}

nc_unlock_domain() {
  local domain="$1"
  nc_api_call "namecheap.domains.setRegistrarLock" "DomainName=${domain}" "LockAction=unlock"
}

nc_get_auth_code() {
  local domain="$1"
  nc_api_call "namecheap.domains.getAuthCode" "DomainName=${domain}"
}

###############################################################################
# Cloudflare API helpers
###############################################################################

cf_api_call() {
  local method="$1"
  local endpoint="$2"
  shift 2
  curl -s -X "$method" "${CF_API}${endpoint}" \
    -H "X-Auth-Email: ${CF_EMAIL}" \
    -H "X-Auth-Key: ${CF_API_KEY}" \
    -H "Content-Type: application/json" \
    "$@"
}

cf_list_zones() {
  local page=1
  local all_zones=""
  while true; do
    local resp
    resp=$(cf_api_call GET "/zones?per_page=50&page=${page}")
    local zones
    zones=$(echo "$resp" | jq -r '.result[]? | "\(.name) \(.id) \(.status)"')
    if [[ -z "$zones" ]]; then
      break
    fi
    all_zones+="${zones}"$'\n'
    local total_pages
    total_pages=$(echo "$resp" | jq -r '.result_info.total_pages // 1')
    if [[ "$page" -ge "$total_pages" ]]; then
      break
    fi
    page=$((page + 1))
  done
  echo "$all_zones" | grep -v '^$'
}

cf_add_zone() {
  local domain="$1"
  cf_api_call POST "/zones" -d "{\"name\":\"${domain}\",\"account\":{\"id\":\"${CF_ACCOUNT_ID}\"},\"jump_start\":true}"
}

cf_get_zone_nameservers() {
  local zone_id="$1"
  cf_api_call GET "/zones/${zone_id}" | jq -r '.result.name_servers[]'
}

cf_get_zone_status() {
  local zone_id="$1"
  cf_api_call GET "/zones/${zone_id}" | jq -r '.result.status'
}

###############################################################################
# PHASE 1: Discovery (read-only)
###############################################################################

phase1_discovery() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo -e "${BOLD}${CYAN}  PHASE 1: Discovery (read-only)${NC_COL}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo ""

  log "Detecting public IP: ${CLIENT_IP}"
  echo ""

  # Get NC domains
  log "Fetching domains from Namecheap..."
  NC_DOMAINS=$(nc_get_domains)
  NC_DOMAIN_COUNT=$(echo "$NC_DOMAINS" | wc -l | tr -d ' ')
  ok "Found ${NC_DOMAIN_COUNT} domains on Namecheap:"
  echo "$NC_DOMAINS" | while read -r d; do echo "  • $d"; done
  echo ""

  # Get CF zones
  log "Fetching existing Cloudflare zones..."
  CF_ZONES=$(cf_list_zones)
  if [[ -n "$CF_ZONES" ]]; then
    ok "Existing CF zones:"
    echo "$CF_ZONES" | while read -r name id status; do
      echo "  • ${name} (${status}) [${id}]"
    done
  else
    warn "No existing CF zones found."
    CF_ZONES=""
  fi
  echo ""

  # Determine which domains need to be added as CF zones
  DOMAINS_TO_ADD=()
  DOMAINS_ALREADY_ON_CF=()

  while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue
    if echo "$CF_ZONES" | grep -q "^${domain} "; then
      DOMAINS_ALREADY_ON_CF+=("$domain")
    else
      DOMAINS_TO_ADD+=("$domain")
    fi
  done <<< "$NC_DOMAINS"

  echo -e "${BOLD}Summary:${NC_COL}"
  if [[ ${#DOMAINS_ALREADY_ON_CF[@]} -gt 0 ]]; then
    ok "${#DOMAINS_ALREADY_ON_CF[@]} domain(s) already on CF DNS:"
    for d in "${DOMAINS_ALREADY_ON_CF[@]}"; do echo "  ✅ $d"; done
  fi
  if [[ ${#DOMAINS_TO_ADD[@]} -gt 0 ]]; then
    log "${#DOMAINS_TO_ADD[@]} domain(s) need to be added to CF:"
    for d in "${DOMAINS_TO_ADD[@]}"; do echo "  ➕ $d"; done
  fi
  echo ""
}

###############################################################################
# PHASE 2: Add zones to Cloudflare
###############################################################################

phase2_add_zones() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo -e "${BOLD}${CYAN}  PHASE 2: Add domains as Cloudflare zones${NC_COL}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo ""

  if [[ ${#DOMAINS_TO_ADD[@]} -eq 0 ]]; then
    ok "All domains are already CF zones. Skipping."
    return
  fi

  log "Will add ${#DOMAINS_TO_ADD[@]} domain(s) to Cloudflare:"
  for d in "${DOMAINS_TO_ADD[@]}"; do echo "  ➕ $d"; done

  confirm "This will add ${#DOMAINS_TO_ADD[@]} zones to your Cloudflare account (CF auto-scans DNS records)."

  declare -gA ZONE_IDS=()

  for domain in "${DOMAINS_TO_ADD[@]}"; do
    log "Adding zone: ${domain}..."
    local resp
    resp=$(cf_add_zone "$domain")
    local success
    success=$(echo "$resp" | jq -r '.success')
    if [[ "$success" == "true" ]]; then
      local zone_id
      zone_id=$(echo "$resp" | jq -r '.result.id')
      ZONE_IDS["$domain"]="$zone_id"
      ok "Added ${domain} → zone ${zone_id}"
    else
      local errmsg
      errmsg=$(echo "$resp" | jq -r '.errors[0].message // "Unknown error"')
      # Check if already exists
      if echo "$errmsg" | grep -qi "already exists"; then
        warn "${domain} already exists on CF (may be on another account or pending)"
      else
        err "Failed to add ${domain}: ${errmsg}"
      fi
    fi
  done

  # Refresh zone list
  CF_ZONES=$(cf_list_zones)
  echo ""
}

###############################################################################
# PHASE 3: Update nameservers at Namecheap
###############################################################################

phase3_nameservers() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo -e "${BOLD}${CYAN}  PHASE 3: Update nameservers at Namecheap${NC_COL}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo ""

  # Build domain→zone_id map
  declare -A ALL_ZONE_IDS=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local name id status
    read -r name id status <<< "$line"
    ALL_ZONE_IDS["$name"]="$id"
  done <<< "$CF_ZONES"

  # Collect NS changes needed
  declare -A NS_CHANGES=()  # domain → "ns1,ns2"

  while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue
    local zone_id="${ALL_ZONE_IDS[$domain]:-}"
    if [[ -z "$zone_id" ]]; then
      warn "No CF zone found for ${domain} — skipping NS update"
      continue
    fi

    # Check if zone already active (NS already pointing to CF)
    local status
    status=$(cf_get_zone_status "$zone_id")
    if [[ "$status" == "active" ]]; then
      ok "${domain} — already active on CF, NS already correct"
      continue
    fi

    local ns
    ns=$(cf_get_zone_nameservers "$zone_id")
    local ns1 ns2
    ns1=$(echo "$ns" | head -1)
    ns2=$(echo "$ns" | tail -1)

    if [[ -n "$ns1" && -n "$ns2" ]]; then
      NS_CHANGES["$domain"]="${ns1},${ns2}"
      log "${domain} → needs NS: ${ns1}, ${ns2}"
    else
      err "Could not get nameservers for ${domain} zone"
    fi
  done <<< "$NC_DOMAINS"

  if [[ ${#NS_CHANGES[@]} -eq 0 ]]; then
    ok "All domains already have correct nameservers. Skipping."
    return
  fi

  echo ""
  log "NS changes to apply at Namecheap:"
  for domain in "${!NS_CHANGES[@]}"; do
    echo "  ${domain} → ${NS_CHANGES[$domain]}"
  done

  confirm "This will change nameservers for ${#NS_CHANGES[@]} domain(s) at Namecheap. DNS may take up to 24h to propagate."

  for domain in "${!NS_CHANGES[@]}"; do
    IFS=',' read -r ns1 ns2 <<< "${NS_CHANGES[$domain]}"
    log "Setting NS for ${domain} → ${ns1}, ${ns2}..."
    local resp
    resp=$(nc_set_nameservers "$domain" "$ns1" "$ns2")
    local status
    status=$(echo "$resp" | xmllint --xpath 'string(//*[local-name()="ApiResponse"]/@Status)' - 2>/dev/null || echo "ERROR")
    if [[ "$status" == "OK" ]]; then
      ok "${domain} nameservers updated"
    else
      local errmsg
      errmsg=$(echo "$resp" | xmllint --xpath 'string(//*[local-name()="Error"])' - 2>/dev/null || echo "Unknown error")
      err "Failed to update NS for ${domain}: ${errmsg}"
    fi
  done
  echo ""
}

###############################################################################
# PHASE 4: Wait for zones to become active
###############################################################################

phase4_wait_active() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo -e "${BOLD}${CYAN}  PHASE 4: Wait for CF zones to become active${NC_COL}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo ""

  # Build zone map
  declare -A ALL_ZONE_IDS=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local name id status
    read -r name id status <<< "$line"
    ALL_ZONE_IDS["$name"]="$id"
  done <<< "$CF_ZONES"

  local pending=()
  while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue
    local zone_id="${ALL_ZONE_IDS[$domain]:-}"
    [[ -z "$zone_id" ]] && continue
    local status
    status=$(cf_get_zone_status "$zone_id")
    if [[ "$status" != "active" ]]; then
      pending+=("$domain:$zone_id")
    else
      ok "${domain} ✅ active"
    fi
  done <<< "$NC_DOMAINS"

  if [[ ${#pending[@]} -eq 0 ]]; then
    ok "All zones are active!"
    return
  fi

  warn "${#pending[@]} zone(s) still pending. Polling every 60s (Ctrl+C to skip and come back later)..."
  echo ""

  local max_wait=3600  # 1 hour max
  local elapsed=0
  local interval=60

  while [[ ${#pending[@]} -gt 0 && $elapsed -lt $max_wait ]]; do
    sleep "$interval"
    elapsed=$((elapsed + interval))

    local still_pending=()
    for entry in "${pending[@]}"; do
      local domain="${entry%%:*}"
      local zone_id="${entry##*:}"
      local status
      status=$(cf_get_zone_status "$zone_id")
      if [[ "$status" == "active" ]]; then
        ok "${domain} ✅ now active! (after ${elapsed}s)"
      else
        still_pending+=("$entry")
        log "${domain} still ${status}... (${elapsed}s elapsed)"
      fi
    done
    pending=("${still_pending[@]}")
  done

  if [[ ${#pending[@]} -gt 0 ]]; then
    warn "Some zones are still not active after ${max_wait}s."
    warn "You can re-run this script later — it will pick up where it left off."
    warn "Pending zones:"
    for entry in "${pending[@]}"; do
      echo "  ⏳ ${entry%%:*}"
    done

    confirm "Continue anyway? (unlock/auth steps will only work for active zones)"
  fi
  echo ""
}

###############################################################################
# PHASE 5: Unlock domains at Namecheap
###############################################################################

phase5_unlock() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo -e "${BOLD}${CYAN}  PHASE 5: Unlock domains at Namecheap${NC_COL}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo ""

  local domains_to_unlock=()
  while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue
    # Check lock status
    local info
    info=$(nc_get_domain_info "$domain")
    local locked
    locked=$(echo "$info" | xmllint --xpath 'string(//*[local-name()="DomainGetInfoResult"]/@IsLocked)' - 2>/dev/null || echo "unknown")
    if [[ "$locked" == "true" ]]; then
      domains_to_unlock+=("$domain")
      log "${domain} 🔒 locked"
    elif [[ "$locked" == "false" ]]; then
      ok "${domain} 🔓 already unlocked"
    else
      warn "${domain} — could not determine lock status, will try to unlock"
      domains_to_unlock+=("$domain")
    fi
  done <<< "$NC_DOMAINS"

  if [[ ${#domains_to_unlock[@]} -eq 0 ]]; then
    ok "All domains already unlocked."
    return
  fi

  confirm "This will UNLOCK ${#domains_to_unlock[@]} domain(s) at Namecheap for transfer."

  for domain in "${domains_to_unlock[@]}"; do
    log "Unlocking ${domain}..."
    local resp
    resp=$(nc_unlock_domain "$domain")
    local status
    status=$(echo "$resp" | xmllint --xpath 'string(//*[local-name()="ApiResponse"]/@Status)' - 2>/dev/null || echo "ERROR")
    if [[ "$status" == "OK" ]]; then
      ok "${domain} 🔓 unlocked"
    else
      local errmsg
      errmsg=$(echo "$resp" | xmllint --xpath 'string(//*[local-name()="Error"])' - 2>/dev/null || echo "Unknown error")
      err "Failed to unlock ${domain}: ${errmsg}"
    fi
  done
  echo ""
}

###############################################################################
# PHASE 6: Request auth codes
###############################################################################

phase6_auth_codes() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo -e "${BOLD}${CYAN}  PHASE 6: Request EPP auth codes${NC_COL}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo ""

  warn "Auth codes will be sent to your registrant email address."
  confirm "Request EPP auth codes for ALL ${NC_DOMAIN_COUNT} domains? They'll be emailed to you."

  while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue
    log "Requesting auth code for ${domain}..."
    local resp
    resp=$(nc_get_auth_code "$domain")
    local status
    status=$(echo "$resp" | xmllint --xpath 'string(//*[local-name()="ApiResponse"]/@Status)' - 2>/dev/null || echo "ERROR")
    if [[ "$status" == "OK" ]]; then
      ok "${domain} — auth code requested (check email)"
    else
      local errmsg
      errmsg=$(echo "$resp" | xmllint --xpath 'string(//*[local-name()="Error"])' - 2>/dev/null || echo "Unknown error")
      err "Failed for ${domain}: ${errmsg}"
    fi
  done <<< "$NC_DOMAINS"
  echo ""
}

###############################################################################
# PHASE 7: Open CF Dashboard for transfer
###############################################################################

phase7_transfer() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo -e "${BOLD}${CYAN}  PHASE 7: Complete transfer in Cloudflare Dashboard${NC_COL}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC_COL}"
  echo ""

  local transfer_url="https://dash.cloudflare.com/${CF_ACCOUNT_ID}/registrar/transfer"

  echo -e "${BOLD}All automated steps complete!${NC_COL}"
  echo ""
  echo "📧 Check your email for EPP auth codes from Namecheap."
  echo ""
  echo "🌐 Open the Cloudflare Transfer page to complete the transfers:"
  echo -e "   ${BOLD}${transfer_url}${NC_COL}"
  echo ""
  echo "For each domain:"
  echo "  1. Select the domain"
  echo "  2. Enter the EPP auth code from the email"
  echo "  3. Confirm payment (1-year extension at CF cost price)"
  echo "  4. Enter contact info and agree to terms"
  echo ""
  echo "After submitting, approve the transfer in the confirmation email"
  echo "from Namecheap (speeds things up vs waiting 5 days)."
  echo ""

  # Try to open in browser on macOS
  if command -v open &>/dev/null; then
    read -rp "Open Cloudflare Transfer page in browser? [Y/n] " answer
    if [[ "${answer,,}" != "n" ]]; then
      open "$transfer_url"
    fi
  fi

  echo ""
  echo -e "${GREEN}${BOLD}✅ Migration script complete!${NC_COL}"
  echo ""
  echo "Domains processed:"
  while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue
    echo "  • ${domain}"
  done <<< "$NC_DOMAINS"
  echo ""
}

###############################################################################
# MAIN
###############################################################################

echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════╗${NC_COL}"
echo -e "${BOLD}${CYAN}║  Namecheap → Cloudflare Domain Migration Script  ║${NC_COL}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════╝${NC_COL}"
echo ""
echo "This script will migrate ALL your Namecheap domains to Cloudflare."
echo "It runs in phases with confirmation prompts before any changes."
echo ""

phase1_discovery
phase2_add_zones
phase3_nameservers
phase4_wait_active
phase5_unlock
phase6_auth_codes
phase7_transfer
