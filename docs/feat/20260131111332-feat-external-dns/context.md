# ⚠️ SUPERSEDED — see [20260219-cloudflare-tunnel-gitops](../20260219-cloudflare-tunnel-gitops/context.md)

# feat-external-dns external-dns (DigitalOcean) on neumann

## TASK

Automate DigitalOcean DNS record management for neumann by running `external-dns` in-cluster and having it create/update DNS records based on Kubernetes Ingress hosts.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/apps/external-dns.yaml`
* `/Users/tr0n/Code/ritchie/.envrc`
* `/Users/tr0n/Code/ritchie/.gitignore`

## PLAN

Goal: automatically create/update DNS records in DigitalOcean based on Kubernetes Ingress hosts.

This repo installs `external-dns` via ArgoCD as `apps/external-dns.yaml`.

### 1) Create the DigitalOcean token secret (not committed)

Create a DO API token in DigitalOcean with DNS write permissions, then:

```bash
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig

kubectl -n external-dns create secret generic external-dns-digitalocean \
  --from-literal=DO_TOKEN='...' \
  --dry-run=client -o yaml \
  | kubectl apply -f -
```

#### Where to keep the token

There are 3 different “places” that often get confused:

1) **Local developer shell** (for running `doctl` / `kubectl` from your laptop)
   - Put `DO_TOKEN=...` in your local `.env` (gitignored by `.gitignore`)
   - `.envrc` already loads it via `dotenv_if_exists`

2) **Kubernetes runtime** (so ExternalDNS can talk to DigitalOcean)
   - This is the **required** one: the `external-dns-digitalocean` Secret in the `external-dns` namespace.
   - GitHub is not involved in runtime auth here.

3) **GitHub Actions secrets** (only if you set up CI workflows)
   - Not required for ArgoCD “auto deploy”: ArgoCD pulls manifests from git and reconciles in-cluster.
   - Only needed if you build/push images in GitHub Actions, or if you want CI to run `doctl`.

### 2) DNS naming model

We intentionally scope ExternalDNS to only manage subdomains under:

```
*.neumann.tonioriol.com
```

That safety scope is configured in `apps/external-dns.yaml` via `domainFilters`.

### 3) How targets are determined

This cluster uses hostNetwork Traefik (binds `:80/:443` on the node), so we pin DNS targets to the node IP using `--default-targets=5.75.129.215`.

### 4) Verify

```bash
kubectl -n external-dns get pods
kubectl -n external-dns logs deploy/external-dns --tail=200

doctl compute domain records list tonioriol.com --format ID,Type,Name,Data,TTL
```

#### Note on local `kubectl apply --dry-run=client`

If you run `kubectl apply --dry-run=client -f apps/external-dns.yaml` locally, it may error with:

> no matches for kind "Application" in version "argoproj.io/v1alpha1"

That’s because `Application` is a CRD (kubectl can’t map it without the CRD discovery). To validate against the real cluster (where ArgoCD CRDs exist), use a server-side dry-run:

```bash
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig
kubectl apply --dry-run=server -f /Users/tr0n/Code/ritchie/apps/external-dns.yaml
```

## EVENT LOG

## Next Steps

SUPERSEDED — We migrated from DigitalOcean to Cloudflare. DNS is now managed by external-dns with Cloudflare provider, and tunnel routing uses credentials-file mode. See [20260219-cloudflare-tunnel-gitops](../20260219-cloudflare-tunnel-gitops/context.md).

