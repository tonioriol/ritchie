# DigitalOcean DNS for neumann (doctl) + options for app hostnames

## One-off DNS for a specific app (simple)

Example: make `acestreamio.neumann.tonioriol.com` resolve to the neumann node.

```bash
doctl compute domain records list tonioriol.com --format ID,Type,Name,Data,TTL

doctl compute domain records create tonioriol.com \
  --record-type A \
  --record-name acestreamio.neumann \
  --record-data 5.75.129.215 \
  --record-ttl 30
```

## Wildcard under neumann.tonioriol.com (recommended)

Goal: allow any `*.neumann.tonioriol.com` to resolve to the node, without creating individual DNS records per app.

```bash
doctl compute domain records create tonioriol.com \
  --record-type A \
  --record-name '*.neumann' \
  --record-data 5.75.129.215 \
  --record-ttl 30
```

Then set each app’s Ingress host to e.g. `acestreamio.neumann.tonioriol.com`, `grafana.neumann.tonioriol.com`, etc.

## Fully automated DNS from Kubernetes (external-dns)

This repo now supports this approach via [`apps/external-dns.yaml`](apps/external-dns.yaml:1) + [`docs/feat/external-dns/plan.md`](docs/feat/external-dns/plan.md:1). It requires:

- Installing `external-dns` in-cluster
- Storing a DigitalOcean API token in a Kubernetes Secret
- Deciding how `external-dns` should determine the target IP (this cluster uses hostNetwork Traefik, not a LoadBalancer)

Given the single-node architecture, the wildcard approach above is typically the lowest-friction and least-privileged solution.
