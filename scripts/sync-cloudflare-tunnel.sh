#!/usr/bin/env bash
# sync-cloudflare-tunnel.sh
#
# Reads charts/cloudflared/values.yaml and pushes the ingress rules to the
# Cloudflare Tunnel remote config via API, then ensures all hostnames have
# CNAME DNS records pointing at the tunnel.
#
# Usage:
#   cd ritchie && source .env && ./scripts/sync-cloudflare-tunnel.sh
#
# Required env vars (all present in .env):
#   CF_EMAIL, CF_API_KEY, CF_ACCOUNT_ID, CF_TUNNEL_ID
#
# Optional:
#   CF_ZONE_ID — if unset, resolved automatically from the zone name
#   DRY_RUN=1  — print what would happen without making API calls

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALUES_FILE="${REPO_ROOT}/charts/cloudflared/values.yaml"

: "${CF_EMAIL:?CF_EMAIL is required}"
: "${CF_API_KEY:?CF_API_KEY is required}"
: "${CF_ACCOUNT_ID:?CF_ACCOUNT_ID is required}"
: "${CF_TUNNEL_ID:?CF_TUNNEL_ID is required}"
DRY_RUN="${DRY_RUN:-0}"

CF_API="https://api.cloudflare.com/client/v4"
AUTH_HEADERS=(-H "X-Auth-Email: ${CF_EMAIL}" -H "X-Auth-Key: ${CF_API_KEY}")

echo "→ Reading hosts from ${VALUES_FILE}"

# Parse hosts from values.yaml using python (available via devbox)
INGRESS_JSON=$(python3 - <<'EOF'
import sys, re, json

with open("charts/cloudflared/values.yaml") as f:
    content = f.read()

# Simple line-by-line parser for the hosts: section
ingress = []
in_hosts = False
current = {}
for line in content.splitlines():
    stripped = line.strip()
    if stripped == "hosts:":
        in_hosts = True
        continue
    if in_hosts:
        if stripped.startswith("- hostname:"):
            if current:
                ingress.append(current)
            current = {"hostname": stripped.split(":", 1)[1].strip()}
        elif stripped.startswith("service:") and current:
            current["service"] = stripped.split(":", 1)[1].strip()
        elif stripped and not stripped.startswith("#") and not stripped.startswith("-") and ":" in stripped:
            # A new top-level key — end of hosts section
            if current:
                ingress.append(current)
            break

if current and current not in ingress:
    ingress.append(current)

# Add the catch-all
ingress.append({"service": "http_status:404"})
print(json.dumps(ingress, indent=2))
EOF
)

echo "→ Ingress rules to apply:"
echo "${INGRESS_JSON}" | python3 -c "
import sys, json
rules = json.load(sys.stdin)
for r in rules:
    h = r.get('hostname', '*')
    s = r.get('service', '')
    print(f'   {h} -> {s}')
"

if [[ "${DRY_RUN}" == "1" ]]; then
    echo "[DRY_RUN] Would PUT tunnel config and upsert DNS records — skipping API calls."
    exit 0
fi

# 1. Push tunnel config
echo ""
echo "→ Pushing tunnel ingress config to Cloudflare API..."
PAYLOAD=$(python3 -c "import sys, json; print(json.dumps({'config': {'ingress': $(echo "${INGRESS_JSON}"), 'warp-routing': {'enabled': True}}}))")
RESULT=$(curl -s -X PUT \
    "${CF_API}/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${CF_TUNNEL_ID}/configurations" \
    "${AUTH_HEADERS[@]}" \
    -H "Content-Type: application/json" \
    --data "${PAYLOAD}")

SUCCESS=$(echo "${RESULT}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))")
if [[ "${SUCCESS}" != "True" ]]; then
    echo "✗ Failed to push tunnel config:"
    echo "${RESULT}" | python3 -m json.tool
    exit 1
fi
echo "✓ Tunnel config pushed"

# 2. Resolve zone ID if not set
if [[ -z "${CF_ZONE_ID:-}" ]]; then
    echo ""
    echo "→ Resolving zone ID for tonioriol.com..."
    CF_ZONE_ID=$(curl -s "${CF_API}/zones?name=tonioriol.com" \
        "${AUTH_HEADERS[@]}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin)['result'][0]['id'])")
    echo "   Zone ID: ${CF_ZONE_ID}"
fi

export TUNNEL_CNAME="${CF_TUNNEL_ID}.cfargotunnel.com"
export CF_ZONE_ID

# 3. Upsert DNS CNAME records for all hostnames (skip wildcard catch-all)
echo ""
echo "→ Upserting DNS CNAME records..."
export INGRESS_JSON
python3 <<'PYEOF'
import json, subprocess, os

rules = json.loads(os.environ["INGRESS_JSON"])
zone_id = os.environ.get("CF_ZONE_ID", "")
tunnel_cname = os.environ.get("TUNNEL_CNAME", "")
email = os.environ.get("CF_EMAIL", "")
api_key = os.environ.get("CF_API_KEY", "")
api_base = "https://api.cloudflare.com/client/v4"
headers = ["-H", f"X-Auth-Email: {email}", "-H", f"X-Auth-Key: {api_key}"]

for rule in rules:
    hostname = rule.get("hostname", "")
    if not hostname or hostname == "*":
        continue

    # Check if record exists
    r = subprocess.run(
        ["curl", "-s", f"{api_base}/zones/{zone_id}/dns_records?name={hostname}"] + headers,
        capture_output=True, text=True
    )
    data = json.loads(r.stdout)
    existing = data.get("result", [])

    record_payload = json.dumps({
        "type": "CNAME",
        "name": hostname,
        "content": tunnel_cname,
        "proxied": True,
        "ttl": 1
    })

    if existing:
        record_id = existing[0]["id"]
        result = subprocess.run(
            ["curl", "-s", "-X", "PUT",
             f"{api_base}/zones/{zone_id}/dns_records/{record_id}"] + headers +
            ["-H", "Content-Type: application/json", "--data", record_payload],
            capture_output=True, text=True
        )
        ok = json.loads(result.stdout).get("success", False)
        print(f"   {'✓' if ok else '✗'} updated  {hostname}")
    else:
        result = subprocess.run(
            ["curl", "-s", "-X", "POST",
             f"{api_base}/zones/{zone_id}/dns_records"] + headers +
            ["-H", "Content-Type: application/json", "--data", record_payload],
            capture_output=True, text=True
        )
        ok = json.loads(result.stdout).get("success", False)
        print(f"   {'✓' if ok else '✗'} created  {hostname}")
PYEOF

echo ""
echo "✓ Done. All tunnel ingress rules and DNS records are in sync."
