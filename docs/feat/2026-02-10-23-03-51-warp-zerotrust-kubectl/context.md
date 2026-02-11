# 2026-02-10-23-03-51-warp-zerotrust-kubectl Cloudflare Zero Trust WARP enrollment + kubectl via private route (10.0.0.2)

## TASK

Establish resilient admin access to the k3s cluster during ISP match-time Hetzner IP blocks by:

- Enrolling macOS Cloudflare WARP client into the Zero Trust org (`ultr4`).
- Enabling private routing (Teamnet route) to the node private IP `10.0.0.2/32` via the existing Cloudflare Tunnel (`neumann`).
- Configuring Split Tunnel settings so traffic to `10.0.0.2/32` actually traverses WARP.
- Verifying `kubectl` works against `https://10.0.0.2:6443`.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/docs/feat/2026-02-08-23-33-44-feat-cloudflare-neumann-cli-runbook/context.md`
* `/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig`
* `/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig.warp` (local-only; do not commit)
* `/Users/tr0n/Code/ritchie/.gitignore`

## PLAN

1) Zero Trust enrollment
- Ensure device enrollment permissions allow enrolling devices (policy attached).
- Ensure at least one login method is enabled (OTP/PIN was used).
- Enroll macOS WARP client into org `ultr4`.

2) Private routing
- Ensure tunnel routing is enabled on the `neumann` tunnel.
- Ensure Teamnet route exists: `10.0.0.2/32 → neumann`.

3) Split tunnel correctness
- Ensure WARP device profile routes `10.0.0.2/32` through WARP (include list).

4) Validate
- `nc` to `10.0.0.2:6443` works.
- `kubectl` works using kubeconfig pointed at `https://10.0.0.2:6443`.

## EVENT LOG

* **2026-02-10 - WARP CLI enrollment debugging (macOS)**
  * Initial blocker: attempted `warp-cli teams-enroll ultr4` but this installed CLI version does not have a `teams-enroll` subcommand.
  * Verified the correct flow for this CLI is `warp-cli registration new <ORG>` which opens `https://<org>.cloudflareaccess.com/warp` for browser-based authorization.

* **2026-02-10 - Zero Trust dashboard configuration to unblock enrollment**
  * Root cause of `Enrollment request is invalid` at `https://ultr4.cloudflareaccess.com/warp`: device enrollment permissions policy was not set / not attached.
  * Fixed by:
    * Creating and attaching a Device enrollment permissions allow policy (`Everyone` initially).
    * Enabling One-time PIN login method.

* **2026-02-10 - Device authentication handoff issues (CF_REGISTRATION_MISSING)**
  * Browser flow reached a “Success! Open Cloudflare WARP” screen, but the app still showed:
    * `CF_REGISTRATION_MISSING` / “Device not authenticated”.
  * Fixed by ensuring the user identity was added/selected in the Cloudflare WARP macOS app.
  * Post-fix verification: `warp-cli registration show` reported `Account type: Team` and `Organization: ultr4`.

* **2026-02-10 - Private route exists but traffic still timed out**
  * Teamnet route `10.0.0.2/32` was present (tunnel `neumann`).
  * `curl -k https://10.0.0.2:6443/healthz` and `nc` initially timed out.
  * Root cause: Split tunnel was enforced by org `network_policy` in **exclude** mode and excluded `10.0.0.0/8`, so `10.0.0.2` never traversed WARP.
  * Fixed by updating the WARP device profile Split Tunnel include list to add `10.0.0.2/32`.
  * Validation: `nc -vz 10.0.0.2 6443` succeeded; `curl -k https://10.0.0.2:6443/healthz` returned 401 Unauthorized (expected without client cert).

* **2026-02-10 - kubectl via WARP to the node private IP**
  * Created `/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig.warp` by copying the existing kubeconfig and updating the `server:` to `https://10.0.0.2:6443`.
  * Used `kubectl config set-cluster` to avoid brittle text substitutions.
  * Validation: `KUBECONFIG=.../kubeconfig.warp kubectl get nodes -o wide` returned node `neumann_master1` Ready.

## Next Steps

- [ ] Ensure `/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig.warp` cannot be accidentally committed (confirm ignore patterns).
- [ ] Optional hardening: restrict public `:6443` (Hetzner firewall) after confirming WARP works reliably from the home ISP.
- [ ] Update main runbook event log to reflect the successful WARP enrollment + split tunnel fix.

