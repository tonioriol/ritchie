# feat-dns-digitalocean DigitalOcean DNS for neumann (doctl) + options for app hostnames

## TASK

Document DigitalOcean DNS management options for the neumann cluster, including one-off records, wildcard records, and a (future) ExternalDNS-based fully automated approach.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/.envrc`
* `/Users/tr0n/Code/ritchie/.gitignore`
* `/Users/tr0n/Code/ritchie/apps/external-dns.yaml`
* `/Users/tr0n/Code/ritchie/docs/feat/2026-01-31-11-13-32-feat-external-dns/context.md`

## PLAN

### One-off DNS for a specific app (simple)

Example: make `acestreamio.neumann.tonioriol.com` resolve to the neumann node.

```bash
doctl compute domain records list tonioriol.com --format ID,Type,Name,Data,TTL

doctl compute domain records create tonioriol.com \
  --record-type A \
  --record-name acestreamio.neumann \
  --record-data 5.75.129.215 \
  --record-ttl 30
```

### Wildcard under neumann.tonioriol.com (recommended)

Goal: allow any `*.neumann.tonioriol.com` to resolve to the node, without creating individual DNS records per app.

```bash
doctl compute domain records create tonioriol.com \
  --record-type A \
  --record-name '*.neumann' \
  --record-data 5.75.129.215 \
  --record-ttl 30
```

Then set each app’s Ingress host to e.g. `acestreamio.neumann.tonioriol.com`, `grafana.neumann.tonioriol.com`, etc.

### Fully automated DNS from Kubernetes (external-dns)

This repo supports this approach via `external-dns` and the context in [`docs/feat/2026-01-31-11-13-32-feat-external-dns/context.md`](docs/feat/2026-01-31-11-13-32-feat-external-dns/context.md:1). It requires:

- Installing `external-dns` in-cluster
- Storing a DigitalOcean API token in a Kubernetes Secret
- Deciding how `external-dns` should determine the target IP (this cluster uses hostNetwork Traefik, not a LoadBalancer)

Given the single-node architecture, the wildcard approach above is typically the lowest-friction and least-privileged solution.

## EVENT LOG

## Next Steps

- [ ] Decide DNS model: one-off records vs wildcard vs external-dns
- [ ] If choosing external-dns: provision DO token + in-cluster Secret and validate record creation

