---
title: "feat-ritchie-migration Ritchie Server Migration to Hetzner k3s"
status: done
created: 2026-01-18
---

# feat-ritchie-migration Ritchie Server Migration to Hetzner k3s

## TASK

Migrate Ritchie server infrastructure from DigitalOcean to Hetzner k3s cluster. Current focus: Simplified Acestream proxy migration only, leaving complex web stack (Nginx, PHP, MySQL) on original DigitalOcean server for now. Future: VPN deployment.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

/Users/tr0n/Code/ritchie

### RELEVANT FILES

* /Users/tr0n/Code/ritchie/README.md
* /Users/tr0n/Code/ritchie/docker-compose.yml
* /Users/tr0n/Code/ritchie/php-fpm/Dockerfile
* /Users/tr0n/Code/ritchie/nginx/conf.d/*.conf
* /Users/tr0n/Code/ritchie/k8s/apps/acestream/acestream-deployment.yaml
* /Users/tr0n/Code/ritchie/k8s/apps/acestream/acestream-service.yaml
* /Users/tr0n/Code/ritchie/k8s/apps/acestream/acestream-namespace.yaml
* /Users/tr0n/Code/ritchie/k8s/apps/acestream/kustomization.yaml
* /Users/tr0n/Code/ritchie/k8s/apps/vpn/wireguard-deployment.yaml
* /Users/tr0n/Code/ritchie/k8s/apps/vpn/wireguard-service.yaml
* /Users/tr0n/Code/ritchie/k8s/apps/vpn/wireguard-pvc.yaml
* /Users/tr0n/Code/ritchie/k8s/apps/vpn/vpn-namespace.yaml
* /Users/tr0n/Code/ritchie/k8s/apps/vpn/kustomization.yaml

## PLAN

### Phase 1: Simplified Acestream Migration to Hetzner k3s
- [x] Set up Hetzner account and API access — **done** (2026-11-08): `HCLOUD_TOKEN` in `.env`; `hcloud firewall list` returns firewall `neumann`
- [x] Install hetzner-k3s tool locally — **done** (2026-11-08): cluster built with hetzner-k3s (20260119211309-feat-k3-cluster-hetzner)
- [x] Create CX22 instance (€6.99/month) using hetzner-k3s tool — **done** (2026-11-08): `neumann-master1` Ready, age 292d
- [x] Deploy Acestream proxy: `kubectl apply -k k8s/apps/acestream/` — **done** (2026-11-08): deployed via ArgoCD app `acestream` (`charts/acestream`), not kustomize; Synced/Healthy
- [x] ~~Update Nginx on original Ritchie server to proxy to new Hetzner IP~~ — **obsolete** (2026-11-08): the DigitalOcean server was destroyed 2026-10-07; ace.tonioriol.com is Acexy behind the Cloudflare tunnel
- [x] Test Acestream functionality thoroughly — **done** (2026-11-08): Acexy serves `ace.tonioriol.com` (401 without token); acestream-catalog probes streams continuously
- [x] ~~Monitor new service performance~~ — **obsolete** (2026-11-08): ongoing operations, not a step; covered by the acestream-catalog/iptv skills

### Phase 2: Future VPN Deployment (When Needed)
- [x] ~~Deploy VPN: `kubectl apply -k k8s/apps/vpn/`~~ — **obsolete** (2026-11-08): never deployed; no VPN manifests in the GitOps repo, and kubectl access during ISP blocks is covered by WARP (20260210230351-warp-zerotrust-kubectl). Reopen as a new feature if a VPN is wanted
- [x] ~~Configure WireGuard peers (phone, laptop, desktop)~~ — **obsolete** (2026-11-08): never deployed; no VPN manifests in the GitOps repo, and kubectl access during ISP blocks is covered by WARP (20260210230351-warp-zerotrust-kubectl). Reopen as a new feature if a VPN is wanted
- [x] ~~Update DNS for vpn.ritchie.tonioriol.com~~ — **obsolete** (2026-11-08): never deployed; no VPN manifests in the GitOps repo, and kubectl access during ISP blocks is covered by WARP (20260210230351-warp-zerotrust-kubectl). Reopen as a new feature if a VPN is wanted
- [x] ~~Test VPN connectivity~~ — **obsolete** (2026-11-08): never deployed; no VPN manifests in the GitOps repo, and kubectl access during ISP blocks is covered by WARP (20260210230351-warp-zerotrust-kubectl). Reopen as a new feature if a VPN is wanted

### Phase 3: Consider Additional Service Migration (Optional)
- [x] Evaluate if other services should migrate — **done** (2026-11-08): done: every service runs on the cluster (29 ArgoCD apps Synced/Healthy on 2026-11-08) and the DigitalOcean droplet was destroyed 2026-10-07
- [x] If yes, create Kubernetes manifests for additional services — **done** (2026-11-08): done: every service runs on the cluster (29 ArgoCD apps Synced/Healthy on 2026-11-08) and the DigitalOcean droplet was destroyed 2026-10-07
- [x] Migrate incrementally — **done** (2026-11-08): done: every service runs on the cluster (29 ArgoCD apps Synced/Healthy on 2026-11-08) and the DigitalOcean droplet was destroyed 2026-10-07

---

### Current Situation

**Original Ritchie Server (DigitalOcean)**
- **Hostname**: ritchie.tonioriol.com (188.226.140.165)
- **Acestream Proxy**: Running as Docker container
- **Access**: ace.tonioriol.com via Nginx reverse proxy
- **Status**: Production service with active users

**What We're NOT Migrating (For Now)**
- ❌ MySQL databases
- ❌ PHP-FPM applications
- ❌ Nginx web server
- ❌ Redis/Memcached caching
- ❌ Other web applications

---

### Target Infrastructure

**Hetzner k3s Cluster (Simplified)**
- **Instance Type**: CX22 (2 vCPU, 4GB RAM, 40GB NVMe) - sufficient for Acestream
- **Region**: Nuremberg (nbg1)
- **OS**: Ubuntu 22.04 LTS
- **Kubernetes**: k3s (lightweight)
- **Cost**: €6.99/month (more cost-effective for single service)
- **Purpose**: Dedicated Acestream proxy server

---

### Migration Strategy: Incremental Service Move

**Rationale:**
1. **Focused scope**: Only migrate what's needed now
2. **Lower risk**: Single service migration is simpler
3. **Cost effective**: Smaller instance size
4. **Future ready**: Kubernetes foundation for VPN and other services
5. **Minimal disruption**: Original services remain untouched

---

### hetzner-k3s Tool

`hetzner-k3s` is an open-source CLI tool designed to simplify and automate the deployment of production-ready Kubernetes clusters on Hetzner Cloud. It's specifically optimized for k3s, a lightweight Kubernetes distribution created by Rancher.

**Key Features:**
1. **Rapid Cluster Deployment**: 2-3 minute deployment, automated configuration
2. **Simple Configuration**: Single YAML file, declarative approach, sensible defaults
3. **Comprehensive Setup**: Networking, storage, monitoring, ingress
4. **Security Focused**: Firewall configuration, SSH access, API security

**Installation:**
```bash
wget https://github.com/vitobotta/hetzner-k3s/releases/download/v2.4.5/hetzner-k3s-linux-amd64
chmod +x hetzner-k3s-linux-amd64
sudo mv hetzner-k3s-linux-amd64 /usr/local/bin/hetzner-k3s
```

**Cluster Configuration (acestream-cluster.yaml):**
```yaml
name: acestream-cluster
region: nbg1
kubernetes_version: v1.27.4+k3s1

nodes:
  - type: CX22
    count: 1
    name: acestream-node
    labels:
      - service=acestream
      - role=proxy

firewall:
  ssh: true
  kubernetes_api: true
  http: true
  https: true
  custom:
    - port: 6878
      protocol: tcp
      description: "Acestream Proxy"

options:
  traefik: false
  metrics_server: true
  local_storage: true
```

**Deployment Process:**
```bash
# 1. Create cluster (takes 2-3 minutes)
hetzner-k3s create --config acestream-cluster.yaml

# 2. Get kubeconfig for kubectl access
hetzner-k3s kubeconfig > ~/.kube/config

# 3. Verify cluster is running
kubectl get nodes

# 4. Deploy Acestream
kubectl apply -k k8s/apps/acestream/
```

**What It Does Automatically:**
1. Creates Hetzner Cloud servers with specified instance types
2. Sets up proper networking between nodes
3. Installs k3s (lightweight Kubernetes) on all nodes
4. Configures firewall rules, SSH access, API security
5. Installs metrics server for resource monitoring

---

### Nginx Proxy Configuration Update

**On Original Ritchie Server (188.226.140.165) after Acestream migration:**

```nginx
server {
    listen 443 ssl;
    server_name ace.tonioriol.com;

    ssl_certificate /etc/nginx/ssl/ace.tonioriol.com/server.crt;
    ssl_certificate_key /etc/nginx/ssl/ace.tonioriol.com/server.key;

    location / {
        # Change proxy to point to new Hetzner IP
        proxy_pass http://<HETZNER_IP>:6878;

        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow_Methods' 'GET, POST, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range';
    }
}
```

---

### Timeline

| Phase | Duration | Notes |
|-------|----------|-------|
| Hetzner Setup | 1 hour | Cluster deployment |
| Acestream Deployment | 1 hour | Kubernetes manifests |
| DNS/Nginx Update | 1 hour | Proxy configuration |
| Testing | 2 hours | Comprehensive validation |
| Monitoring (Optional) | 1 hour | Basic metrics setup |
| **TOTAL** | **6 hours** | Can be done in one day |

---

### Cost Analysis

| Environment | Cost | Notes |
|-------------|------|-------|
| Current DigitalOcean | ~$20-40/month | Legacy server |
| Hetzner CX22 | €6.99/month | Acestream only |
| Bandwidth | Included | 20TB |
| Migration | 6 hours (one-time) | Free tools |

---

### Infrastructure Options Evaluated

| Option | Cost | Pros | Cons | Status |
|--------|------|------|------|--------|
| Current DO + Dockge | ~$5/mo | Already working | Higher cost, no orchestration | Status Quo |
| Hetzner VPS + k3s | €6.99/mo | Better price/perf, modern k8s | Migration effort | **RECOMMENDED** |
| Hetzner Managed K8s | ~€54/mo | Fully managed | Overkill, expensive | Not needed |
| Raspberry Pi k3s | Free | Zero cost | Limited perf, home network | Not reliable |

---

### Rollback Plan

If issues arise:
```bash
# 1. Revert Nginx proxy configuration to local
proxy_pass http://localhost:6878;

# 2. Keep Hetzner cluster for testing/debugging

# 3. Debug and fix issues
kubectl logs -l app=acestream-http-proxy -n acestream

# 4. Re-attempt migration after fixes
```

---

### Comparison: Full vs Simplified Migration

| Aspect | Full Migration | Simplified Migration |
|--------|---------------|---------------------|
| **Scope** | All services | Acestream only |
| **Risk** | High | Low |
| **Time** | 6.5 days | 6 hours |
| **Cost** | €8.99/month | €6.99/month |
| **Disruption** | Significant | Minimal |
| **Complexity** | High | Low |
| **Future Ready** | Very | Yes |
| **Recommended** | Later | **Now** |

## EVENT LOG

* **2026-01-18 10:00 - DigitalOcean Droplet Creation (gavalda - test env)**
  * Created droplet 'gavalda' in ams3, IP: 206.189.11.169
  * Ubuntu 22.04, 1 vCPU, 1GB RAM, 25GB SSD
  * This was a TEST environment for Docker/Dockge evaluation

* **2026-01-18 10:15 - Base System Setup on gavalda**
  * Docker 24.0.7, Docker Compose 1.29.2
  * Configured forge user with Docker permissions
  * Project directory: `/home/forge/ritchie-docker/`

* **2026-01-18 10:45 - Database Services Containerization**
  * MySQL 5.7: port 3306, utf8mb4, persistent volume
  * Redis 7: port 6379, AOF enabled
  * Memcached: port 11211, 64MB limit
  * Beanstalkd: port 11300

* **2026-01-18 11:30 - PHP-FPM Configuration Challenges**
  * Issue: Container restarting every 5 seconds
  * Root cause: Missing /var/log/php-fpm/slow.log directory
  * Solution: Added `RUN mkdir -p /var/log/php-fpm` to Dockerfile
  * Result: PHP-FPM stable on port 9000

* **2026-01-18 12:00 - Dockge Installation**
  * Accessible at: http://206.189.11.169:5001
  * Status: Healthy and operational

* **2026-01-18 12:30 - Nginx SSL Certificate Issues**
  * Problem: Missing SSL certificates causing restart loop
  * Error: `cannot load certificate "/etc/nginx/ssl/ace.tonioriol.com/server.crt"`
  * Status: Nginx failing, sites inaccessible

* **2026-01-18 13:00 - Kubernetes Research**
  * Evaluated Hetzner options: CX11 (€3.49), CX22 (€6.99), CPX21 (€8.99)
  * Discovered hetzner-k3s tool for automated cluster deployment
  * Raspberry Pi consolidation deemed unreliable for production

* **2026-01-18 14:30 - Decision: Simplified Migration**
  * Decision: Migrate only Acestream proxy to Hetzner k3s
  * Leave complex web stack on original Ritchie server (188.226.140.165)
  * gavalda (206.189.11.169) was just a test, not production target
  * Real migration: Original Ritchie → Hetzner k3s

* **2026-01-18 15:00 - Kubernetes Manifests Created**
  * Created Acestream deployment: /Users/tr0n/Code/ritchie/k8s/apps/acestream/
  * Created VPN deployment (future): /Users/tr0n/Code/ritchie/k8s/apps/vpn/
  * Both use Kustomize for easy deployment

* **2026-01-18 16:00 - Documentation Consolidation**
  * Merged SIMPLIFIED_ACESTREAM_MIGRATION.md into context.md
  * Merged HETZNER_K3S_TOOL_EXPLANATION.md into context.md
  * Cleaned up unnecessary docs/general/ files

## CURRENT STATE

### Working Services (on gavalda test - 206.189.11.169)
- ✅ MySQL 5.7 (port 3306)
- ✅ Redis 7 (port 6379)
- ✅ Memcached (port 11211)
- ✅ Beanstalkd (port 11300)
- ✅ PHP-FPM 7.1 (stable, port 9000)
- ✅ Acestream HTTP Proxy (port 6878)
- ✅ Dockge (port 5001, accessible at http://206.189.11.169:5001)

### Issues to Resolve
- ❌ Nginx: Missing SSL certificates (/etc/nginx/ssl/ace.tonioriol.com/server.crt)
- ❌ SSL: Need Let's Encrypt setup for all domains
- ❌ Domain Configuration: Need proper DNS and certificate setup

### Kubernetes Manifests Ready
- ✅ Acestream: `/Users/tr0n/Code/ritchie/k8s/apps/acestream/` - Complete deployment with health checks
- ✅ VPN: `/Users/tr0n/Code/ritchie/k8s/apps/vpn/` - Future WireGuard deployment ready

## Next Steps

### Immediate Priorities (Simplified Acestream Migration)
- [x] Set up Hetzner account and API access — **done** (2026-11-08): see Phase 1
- [x] Create CX22 instance using hetzner-k3s tool — **done** (2026-11-08): see Phase 1
- [x] Deploy Acestream proxy using Kubernetes manifests — **done** (2026-11-08): see Phase 1
- [x] ~~Update Nginx configuration on original server to proxy to new Hetzner IP~~ — **obsolete** (2026-11-08): DigitalOcean server destroyed 2026-10-07
- [x] Test Acestream functionality thoroughly — **done** (2026-11-08): see Phase 1
- [x] ~~Monitor new service performance~~ — **obsolete** (2026-11-08): ongoing operations, not a step

### Short-term Infrastructure Tasks
- [x] ~~Create backup strategy for Acestream configuration~~ — **obsolete** (2026-11-08): engine state is disposable; the configuration lives in git (`charts/acestream`)
- [x] ~~Set up basic monitoring for Acestream service~~ — **obsolete** (2026-11-08): acestream-catalog probes every stream through the engine; ArgoCD reports health
- [x] ~~Test failover and recovery procedures~~ — **obsolete** (2026-11-08): single node, no failover target
- [x] ~~Configure proper logging for Acestream proxy~~ — **obsolete** (2026-11-08): the nginx proxy was removed on 2026-11-08 (fa34f51); Acexy is the proxy

### Medium-term Enhancements
- [x] ~~Deploy VPN when needed using prepared manifests~~ — **obsolete** (2026-11-08): never deployed; no VPN manifests in the GitOps repo, and kubectl access during ISP blocks is covered by WARP (20260210230351-warp-zerotrust-kubectl). Reopen as a new feature if a VPN is wanted
- [x] ~~Evaluate performance and scalability~~ — **obsolete** (2026-11-08): measured 2026-11-08: node at 1617m CPU (40%), 6052Mi memory (78%); headroom is listed as remaining work
- [x] Consider migrating other services incrementally — **done** (2026-11-08): done: every service runs on the cluster (29 ArgoCD apps Synced/Healthy on 2026-11-08) and the DigitalOcean droplet was destroyed 2026-10-07
- [x] Implement CI/CD for Kubernetes updates — **done** (2026-11-08): ArgoCD app-of-apps (`apps/root.yaml`) plus Image Updater semver rollouts
- [ ] Set up comprehensive monitoring and alerting — **still open** (2026-11-08): no metrics/alerting stack exists in `apps/` (only metrics-server); real, multi-hour work, not started — listed as remaining work

### Long-term Modernization
- [x] If needed: Migrate additional services to k3s — **done** (2026-11-08): done: every service runs on the cluster (29 ArgoCD apps Synced/Healthy on 2026-11-08) and the DigitalOcean droplet was destroyed 2026-10-07
- [x] Implement CI/CD pipeline for infrastructure changes — **done** (2026-11-08): ArgoCD auto-sync from `main`
- [ ] Set up comprehensive monitoring and alerting stack — **still open** (2026-11-08): no metrics/alerting stack exists in `apps/` (only metrics-server); real, multi-hour work, not started — listed as remaining work
- [x] Document all procedures and runbooks — **done** (2026-11-08): ritchie `AGENTS.md`, `docs/STREMIO-AIOSTREAMS.md` and the operations skills
- [x] Consider full migration to k3s for all services — **done** (2026-11-08): done: every service runs on the cluster (29 ArgoCD apps Synced/Healthy on 2026-11-08) and the DigitalOcean droplet was destroyed 2026-10-07

## RECOMMENDATION

**Recommended Path**: Simplified Acestream-only migration to Hetzner k3s

**Rationale:**
- Low risk: Single service migration is much safer than full migration
- Quick implementation: Can be done in one day (6 hours)
- Cost effective: Immediate cost savings (€6.99/month vs ~$20-40)
- Modern infrastructure: Kubernetes foundation for future services
- Minimal disruption: Original web services remain untouched
- Future ready: Kubernetes skills and infrastructure for VPN and other services

**Primary Recommendation:**
- **Timeline**: Can be completed in one day (6 hours)
- **Migration Tool**: Use hetzner-k3s for automated cluster setup
- **Target Configuration**: CX22 instance (2 vCPU, 4GB RAM, 40GB NVMe)
- **Expected Benefit**: Immediate cost savings (€6.99/month), modern infrastructure, future scalability
- **Risk Level**: Low (single service migration, minimal disruption)

**Fallback Option**: If issues arise, revert Nginx proxy configuration to local Acestream service and debug Hetzner setup.

**Alternative**: If cost is primary concern, keep Acestream on current server, but this misses the opportunity to modernize infrastructure and gain Kubernetes experience.

**Immediate Action**: Proceed with simplified Acestream migration to Hetzner k3s using the provided manifests and hetzner-k3s tool, then evaluate additional service migrations based on performance and needs.

### 2026-11-08 17:00 — Stale open steps closed out against live state

- Why: 34 steps were still unchecked ten months after the migration finished.
- Evidence: `neumann-master1` Ready (k3s v1.31.4, age 292d); 29 ArgoCD apps Synced/Healthy; `hcloud firewall list` works with `HCLOUD_TOKEN` from `.env`; DigitalOcean droplet destroyed 2026-10-07 (20261007163300-do-ritchie-compromise-and-migration); `https://ace.tonioriol.com/ace/getstream` answers 401 without a token (Acexy).
- Decision: migration **done**. VPN steps obsolete. Monitoring/alerting is the only real remainder and is a new feature, not part of this migration.
