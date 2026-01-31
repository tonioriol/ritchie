# external-dns (DigitalOcean) on neumann

Goal: automatically create/update DNS records in DigitalOcean based on Kubernetes Ingress hosts.

This repo installs `external-dns` via ArgoCD as [`apps/external-dns.yaml`](apps/external-dns.yaml:1).

## 1) Create the DigitalOcean token secret (not committed)

Create a DO API token in DigitalOcean with DNS write permissions, then:

```bash
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig

kubectl -n external-dns create secret generic external-dns-digitalocean \
  --from-literal=DO_TOKEN='...' \
  --dry-run=client -o yaml \
  | kubectl apply -f -
```

## 2) DNS naming model

We intentionally scope ExternalDNS to only manage subdomains under:

```
*.neumann.tonioriol.com
```

That safety scope is configured in [`apps/external-dns.yaml`](apps/external-dns.yaml:1) via `domainFilters`.

## 3) How targets are determined

This cluster uses hostNetwork Traefik (binds `:80/:443` on the node), so we pin DNS targets to the node IP using `--default-targets=5.75.129.215`.

## 4) Verify

```bash
kubectl -n external-dns get pods
kubectl -n external-dns logs deploy/external-dns --tail=200

doctl compute domain records list tonioriol.com --format ID,Type,Name,Data,TTL
```

### Note on local `kubectl apply --dry-run=client`

If you run `kubectl apply --dry-run=client -f apps/external-dns.yaml` locally, it may error with:

> no matches for kind "Application" in version "argoproj.io/v1alpha1"

That’s because `Application` is a CRD (kubectl can’t map it without the CRD discovery). To validate against the real cluster (where ArgoCD CRDs exist), use a server-side dry-run:

```bash
export KUBECONFIG=/Users/tr0n/Code/ritchie/clusters/neumann/kubeconfig
kubectl apply --dry-run=server -f /Users/tr0n/Code/ritchie/apps/external-dns.yaml
```
