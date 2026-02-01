# ritchie

Infrastructure documentation for two servers: the **neumann** k3s cluster (Hetzner) and the legacy **ritchie** server (DigitalOcean).

---

## Kubernetes Cluster: neumann

Single-node k3s cluster on Hetzner Cloud, managed via `hetzner-k3s`.

| Property | Value |
|----------|-------|
| Node IP | `5.75.129.215` |
| Region | Nuremberg (`nbg1`) |
| Instance | CX23 (2 vCPUs, 4 GB RAM) |
| K8s version | v1.31.4+k3s1 |
| Cost | ~€4/month |

### Connection

```bash
export KUBECONFIG=./clusters/neumann/kubeconfig
kubectl get nodes -o wide
```

### ArgoCD

| Property | Value |
|----------|-------|
| UI | `https://5.75.129.215:31796` |
| Admin password | 1Password |

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Deployed Applications

| App | Namespace | Access |
|-----|-----------|--------|
| Acestream | `media` | `https://ace.neumann.tonioriol.com` (proxy) / `http://5.75.129.215:30878` (NodePort) |
| Acestreamio (Stremio addon) | `media` | `https://acestreamio.neumann.tonioriol.com/manifest.json` |

### Cluster Management

```bash
cd clusters/neumann
export HCLOUD_TOKEN=$(grep HCLOUD_TOKEN .env | cut -d= -f2)
hetzner-k3s create --config cluster.yaml
hetzner-k3s delete --config cluster.yaml --force
```

---

## Legacy Server: ritchie

Ubuntu 16.04 server managed by Laravel Forge (now manually maintained).

| Property | Value |
|----------|-------|
| Host | `ritchie.tonioriol.com` |
| IP | `188.226.140.165` |
| SSH | `ssh forge@ritchie.tonioriol.com` |
| Credentials | 1Password ("ritchie" item) |

### Services

- **Web**: Nginx + PHP 7.1-FPM
- **Databases**: MySQL, PostgreSQL 9.5
- **Caching**: Redis, Memcached, Beanstalkd
- **Docker**: acestream-http-proxy container
- **Security**: Fail2Ban, Supervisor

### Hosted Sites

| Domain | Type |
|--------|------|
| ace.tonioriol.com | Reverse proxy → acestream container |
| boira.band | Laravel app |
| bertomeuiglesias.com | Laravel app |
| lodrago.net | Laravel app |
| tonioriol.com | Redirect → GitHub |

### Docker

```bash
# Acestream proxy
cd /home/forge/acestream-http-proxy
docker-compose up -d
```

---

## Notes

- **neumann**: GitOps-driven via ArgoCD with auto-sync enabled
- **ritchie**: Legacy Ubuntu 16.04; avoid major upgrades
