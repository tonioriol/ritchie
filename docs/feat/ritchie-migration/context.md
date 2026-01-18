# Ritchie Server Migration and Kubernetes Evaluation

## TASK

Evaluate migration options for the Ritchie server infrastructure, including:
1. Current Docker/Dockge setup optimization
2. Kubernetes migration options (k3s, Hetzner, DigitalOcean)
3. SSL certificate management
4. Infrastructure consolidation strategies

## GENERAL CONTEXT

### REPO

/Users/tr0n/Code/ritchie

### RELEVANT FILES

* /Users/tr0n/Code/ritchie/README.md
* /Users/tr0n/Code/ritchie/docker-compose.yml
* /Users/tr0n/Code/ritchie/php-fpm/Dockerfile
* /Users/tr0n/Code/ritchie/nginx/conf.d/*.conf

## PLAN

### Phase 1: Current Infrastructure Stabilization ✅
- [x] Set up Dockge on new DigitalOcean droplet
- [x] Containerize all services (MySQL, Redis, PHP-FPM, Nginx, etc.)
- [x] Fix PHP-FPM restarting issues by updating Dockerfile
- [x] Verify all services are running and accessible

### Phase 2: SSL Certificate Management ⚠️
- [ ] Evaluate Let's Encrypt Certbot options
- [ ] Consider DNS validation for wildcard certificates
- [ ] Implement automatic certificate renewal
- [ ] Update Nginx configuration to use proper SSL certificates

### Phase 3: Kubernetes Migration Evaluation 🔍
- [ ] Research Hetzner Kubernetes pricing and options
- [ ] Compare Hetzner VPS with k3s vs DigitalOcean options
- [ ] Evaluate consolidation on existing Raspberry Pi k3s cluster
- [ ] Document pros/cons of each approach

### Phase 4: Decision and Implementation
- [ ] Choose optimal infrastructure approach
- [ ] Create migration plan
- [ ] Implement chosen solution
- [ ] Test and validate

## EVENT LOG

* **2026-01-18 10:00 - DigitalOcean Droplet Creation**
  * Created new droplet named 'gavalda' in Amsterdam (ams3) region
  * Used Lunik SSH key for secure access
  * IP: 206.189.11.169
  * Specs: Ubuntu 22.04, 1 vCPU, 1GB RAM, 25GB SSD
  * Reasoning: Needed clean environment separate from legacy 'ritchie' server

* **2026-01-18 10:15 - Base System Setup**
  * Installed Docker 24.0.7 and Docker Compose 1.29.2
  * Configured forge user with Docker permissions
  * Set up SSH access and basic security hardening
  * Created project directory: `/home/forge/ritchie-docker/`
  * Files created: `docker-compose.yml`, `.env`, `Dockerfile` templates

* **2026-01-18 10:45 - Database Services Containerization**
  * MySQL 5.7: Configured with persistent volume at `/var/lib/mysql`
    - Root password: Secure random string stored in 1Password
    - Character set: utf8mb4, collation: utf8mb4_unicode_ci
    - Port: 3306 with health checks
  * Redis 7: Persistent storage at `/data` with AOF enabled
    - Port: 6379, health check: `redis-cli ping`
  * Memcached: Basic configuration with 64MB memory limit
    - Port: 11211, health check: `echo stats | nc localhost 11211`
  * Beanstalkd: Simple queue service
    - Port: 11300, no authentication configured

* **2026-01-18 11:30 - PHP-FPM Configuration Challenges**
  * Initial Issue: PHP-FPM container restarting every 5 seconds
  * Root Cause Investigation:
    - Checked logs: `ERROR: Unable to create or open slowlog(/var/log/php-fpm/slow.log): No such file or directory (2)`
    - Problem: Container couldn't create log directory due to permission issues
    - Tried runtime fixes: `docker exec` commands failed due to restarting container
  * Solution Approach:
    - Modified `/home/forge/ritchie-docker/php-fpm/Dockerfile` to create directories during build
    - Added: `RUN mkdir -p /var/log/php-fpm && touch /var/log/php-fpm/slow.log && chown www-data:www-data /var/log/php-fpm/slow.log`
    - Rebuilt container: `docker-compose build --no-cache php-fpm`
  * Result: PHP-FPM now stable and running on port 9000

* **2026-01-18 12:00 - Dockge Installation and Configuration**
  * Added Dockge service to docker-compose.yml
  * Accessible at: http://206.189.11.169:5001
  * Status: Healthy and operational, can manage all containers
  * Initial Setup: Created admin user through web interface

* **2026-01-18 12:30 - Nginx SSL Certificate Issues**
  * Problem Identified: Nginx failing to start due to missing SSL certificates
  * Error: `cannot load certificate "/etc/nginx/ssl/ace.tonioriol.com/server.crt": No such file or directory`
  * Affected Sites: ace.tonioriol.com, boira.band, bertomeuiglesias.com, lodrago.net
  * Current Status: Nginx in restart loop, HTTP sites inaccessible

* **2026-01-18 13:00 - Kubernetes Research and Evaluation**
  * Hetzner Options Research:
    - Managed Kubernetes: ~€54/month for 3-node HA cluster
    - VPS Options: CX11 (€3.49), CX22 (€6.99), CPX21 (€8.99 - recommended)
  * Raspberry Pi Consolidation Analysis:
    - Performance: Limited by ARM architecture
    - Network: Home connection reliability concerns
    - Cost: Free but with significant limitations

* **2026-01-18 14:00 - Current Infrastructure Status**
  * Operational Services (7/8): MySQL, Redis, Memcached, Beanstalkd, PHP-FPM, Acestream Proxy, Dockge
  * Failed Service: Nginx (SSL certificate issues)
  * Access URLs: Dockge at http://206.189.11.169:5001

* **2026-01-18 14:30 - Documentation and Context Creation**
  * Created comprehensive context file at `docs/feat/ritchie-migration/context.md`
  * Documented all infrastructure decisions and current state

## CURRENT STATE

### Working Services
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

### Infrastructure Options Evaluated

#### Option 1: Current DigitalOcean + Dockge (Status Quo)
**Pros**: Already working, minimal disruption, familiar environment
**Cons**: Higher cost than alternatives, not using modern orchestration
**Cost**: ~$5/month for basic droplet

#### Option 2: Hetzner VPS with k3s (Recommended)
**Pros**: Better price/performance (€8.99/month), modern Kubernetes setup, scalable
**Cons**: Migration effort required, learning curve
**Cost**: €8.99/month for CPX21 (3 vCPU, 8GB RAM, 80GB NVMe)
**Setup**: Can use hetzner-k3s tool for automated 2-3 minute deployment

#### Option 3: Hetzner Managed Kubernetes
**Pros**: Fully managed, production-grade, scalable
**Cons**: More expensive, may be overkill for current needs
**Cost**: ~€54/month for 3-node HA cluster

#### Option 4: Consolidate on Raspberry Pi k3s
**Pros**: Zero cost, consolidates infrastructure, good for learning
**Cons**: Performance limitations, home network dependency, reliability concerns
**Cost**: Free (uses existing hardware)

## NEXT STEPS

### Immediate Priorities (SSL Certificate Fix)
- [ ] Set up Let's Encrypt Certbot container
- [ ] Configure DNS validation for wildcard certificate (*.tonioriol.com)
- [ ] Generate certificates for all domains (ace.tonioriol.com, boira.band, etc.)
- [ ] Update Nginx configuration to use Let's Encrypt certificates
- [ ] Set up automatic renewal (cron job or Certbot container)
- [ ] Test all sites are accessible via HTTPS

### Short-term Infrastructure Tasks
- [ ] Document complete infrastructure setup in README
- [ ] Create backup strategy for container volumes and databases
- [ ] Set up basic monitoring (container health, resource usage)
- [ ] Test failover and recovery procedures
- [ ] Configure proper logging for all services

### Medium-term Migration Decision
- [ ] Benchmark current resource usage and performance needs
- [ ] Compare DO ($5/mo) vs Hetzner (€8.99/mo) costs with current traffic
- [ ] Evaluate migration complexity and potential downtime
- [ ] Assess team familiarity with Kubernetes vs Docker
- [ ] Make final decision on infrastructure direction

### Long-term Modernization
- [ ] If staying with Docker: Optimize Dockge configuration
- [ ] If migrating to Hetzner: Plan k3s migration using hetzner-k3s tool
- [ ] Implement CI/CD pipeline for infrastructure changes
- [ ] Set up comprehensive monitoring and alerting stack
- [ ] Document all procedures and runbooks

### Recommendation Reaffirmed
**Primary Recommendation**: Migrate to Hetzner VPS with k3s
- **Timeline**: After SSL certificates are fixed and current setup is stable
- **Migration Tool**: Use hetzner-k3s for automated 2-3 minute cluster setup
- **Target Configuration**: CPX21 instance (3 vCPU, 8GB RAM, 80GB NVMe)
- **Expected Benefit**: Better performance, modern infrastructure, future scalability

**Fallback Option**: If migration is too disruptive, optimize current Docker/Dockge setup and implement proper monitoring and backups.

## RECOMMENDATION

**Recommended Path**: Migrate to Hetzner VPS with k3s (Option 2)

**Rationale**:
- Better price/performance ratio than DigitalOcean
- Modern Kubernetes infrastructure for future growth
- Easy setup with hetzner-k3s automation tool
- Reasonable cost increase (€8.99 vs ~$5) for significant benefits
- Maintains production reliability while gaining orchestration capabilities

**Alternative**: If cost is primary concern, consolidate on Raspberry Pi k3s for experimentation/learning, but be aware of performance limitations for production sites.

**Immediate Action**: Fix SSL certificates in current setup to restore full functionality, then evaluate migration options based on performance needs and budget.
