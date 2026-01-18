# Ritchie Server - Containerized Architecture

## Overview

The ritchie server has been redesigned for **full containerization** using Docker Compose, with **Dockge** providing a web-based UI for management.

**Previous State**: Mixed system services (Nginx, PHP-FPM, MySQL, Redis, etc.) running directly on Ubuntu 16.04

**New State**: All services containerized and orchestrated via Docker Compose, managed through Dockge UI

## Connection

- **Host**: `ritchie.tonioriol.com`
- **IP**: `188.226.140.165`
- **SSH user**: `forge`
- **SSH port**: `22`

```bash
ssh forge@ritchie.tonioriol.com
```

## Management Interface

### Dockge Web UI

- **URL**: `https://ritchie.tonioriol.com:5001`
- **Purpose**: Manage all containers, volumes, logs, and configurations
- **Documentation**: See [`DOCKGE_README.md`](./DOCKGE_README.md)

### Services Running

| Service | Purpose | Port | Status |
|---------|---------|------|--------|
| **Nginx** | Web server & reverse proxy | 80, 443 | ✅ Containerized |
| **PHP 7.1-FPM** | PHP application server | 9000 (internal) | ✅ Containerized |
| **MySQL 5.7** | WordPress databases | 3306 | ✅ Containerized |
| **Redis** | Cache & session store | 6379 | ✅ Containerized |
| **Memcached** | In-memory cache | 11211 | ✅ Containerized |
| **Beanstalkd** | Work queue | 11300 | ✅ Containerized |
| **Acestream Proxy** | Stream protocol proxy | 6878 | ✅ Containerized |
| **Dockge** | Container management UI | 5001 | ✅ Containerized |

## Hosted Sites

### 1. boira.band (WordPress Blog)
- **Type**: WordPress
- **URL**: `https://boira.band`
- **Database**: `boira` (MySQL)
- **SSL**: Self-signed
- **Configuration**: [`nginx/conf.d/boira.band.conf`](./nginx/conf.d/boira.band.conf)

### 2. lodrago.net (WordPress Blog with W3TC)
- **Type**: WordPress with caching
- **URL**: `https://lodrago.net`
- **Database**: `lodragonet` (MySQL)
- **SSL**: Let's Encrypt
- **Cache**: W3TC (file-based)
- **Configuration**: [`nginx/conf.d/lodrago.net.conf`](./nginx/conf.d/lodrago.net.conf)

### 3. bertomeuiglesias.com (Static PHP Portfolio)
- **Type**: Multi-language static site (ES/CA/FR)
- **URL**: `https://bertomeuiglesias.com`
- **Database**: JSON file (no database needed)
- **SSL**: Self-signed
- **Configuration**: [`nginx/conf.d/bertomeuiglesias.com.conf`](./nginx/conf.d/bertomeuiglesias.com.conf)

### 4. ace.tonioriol.com (Acestream Proxy)
- **Type**: HTTP proxy for Acestream
- **URL**: `https://ace.tonioriol.com`
- **Backend**: Acestream container
- **Configuration**: [`nginx/conf.d/ace.tonioriol.com.conf`](./nginx/conf.d/ace.tonioriol.com.conf)

## Project Structure

```
.
├── docker-compose.yml              # Complete stack configuration
├── .env.example                    # Environment variables template
├── README_UPDATED.md              # This file (new architecture)
├── CONTAINERIZATION_AUDIT.md      # Detailed analysis
├── DEPLOYMENT.md                  # Step-by-step deployment guide
├── DOCKGE_README.md              # User guide for Dockge UI
├── nginx/
│   ├── nginx.conf                 # Nginx main config
│   ├── conf.d/
│   │   ├── boira.band.conf
│   │   ├── lodrago.net.conf
│   │   ├── bertomeuiglesias.com.conf
│   │   └── ace.tonioriol.com.conf
│   └── ssl/                       # SSL certificates (not in repo)
├── php-fpm/
│   ├── Dockerfile                 # PHP 7.1 with extensions
│   ├── php.ini                    # PHP configuration
│   └── www.conf                   # PHP-FPM pool config
├── mysql/
│   ├── init/
│   │   ├── 01-databases.sql       # Database initialization
│   │   ├── 02-boira.sql          # Boira data (generated during migration)
│   │   └── 03-lodragonet.sql     # Lodrago data (generated during migration)
│   └── data/                      # MySQL persistent volume
└── apps/
    ├── boira.band/                # Website files
    ├── lodrago.net/               # Website files
    └── bertomeuiglesias.com/      # Website files
```

## Quick Start

### 1. Initial Setup (First-time deployment)

```bash
# SSH to ritchie
ssh forge@ritchie.tonioriol.com

# Create working directory
mkdir -p ~/ritchie-docker
cd ~/ritchie-docker

# Clone or copy project files (docker-compose.yml, nginx/, php-fpm/, etc.)
# ...

# Setup environment
cp .env.example .env
# Edit .env with secure passwords
nano .env
```

### 2. Export Current Databases

```bash
# Export WordPress databases
mysqldump -u forge -p boira > mysql/init/02-boira.sql
mysqldump -u forge -p lodragonet > mysql/init/03-lodragonet.sql

# Copy website files
cp -r /home/forge/boira.band apps/
cp -r /home/forge/lodrago.net apps/
cp -r /home/forge/bertomeuiglesias.com apps/
```

### 3. Deploy Containers

```bash
# Build and start services
docker-compose up -d mysql
sleep 30

docker-compose up -d redis memcached beanstalkd php-fpm nginx acestream-http-proxy dockge

# Verify all services running
docker-compose ps
```

### 4. Access Dockge

Open browser to: `https://ritchie.tonioriol.com:5001`

From Dockge UI you can:
- View all running containers
- Check logs in real-time
- Start/stop/restart services
- Monitor resource usage
- Manage volumes and backups
- Edit configuration

**Detailed deployment instructions**: See [`DEPLOYMENT.md`](./DEPLOYMENT.md)

## Common Tasks

### View Container Logs

**Via CLI:**
```bash
docker-compose logs -f nginx
docker-compose logs -f php-fpm
docker-compose logs -f mysql
```

**Via Dockge UI:**
Navigate to service → Click "Logs" tab

### Restart a Service

**Via CLI:**
```bash
docker-compose restart php-fpm
```

**Via Dockge UI:**
Select service → Click "Restart" button

### Check Database

**Via CLI:**
```bash
docker exec ritchie-mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"
```

**Via Dockge UI:**
php-fpm service → "Terminal" → Run mysql commands

### Backup Databases

**Via Dockge UI:**
Select MySQL volume → Click "Backup" → Dockge handles the rest

**Via CLI:**
```bash
docker exec ritchie-mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} --all-databases > backup-$(date +%Y%m%d).sql
```

### Update Website Files

```bash
# Via SSH, update files directly
scp -r local/boira.band/* forge@ritchie.tonioriol.com:~/ritchie-docker/apps/boira.band/

# Nginx will serve updated files immediately (volume mounts active)
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                  Internet (HTTPS)                   │
│         Port 80 (HTTP → HTTPS redirect)             │
│         Port 443 (HTTPS)                            │
└────────────────────┬────────────────────────────────┘
                     │
         ┌───────────▼─────────────┐
         │  Nginx (Reverse Proxy)  │
         │  Port 80, 443           │
         └───┬───┬───┬─────────┬───┘
             │   │   │         │
    ┌────────┘   │   │         └──────────────┐
    │            │   │                        │
    ▼            ▼   ▼                        ▼
┌─────────┐ ┌────────────┐            ┌──────────────┐
│boira.   │ │lodrago.net │  ┌─────┐  │ace.tonioriol │
│band     │ │(W3TC cache)│  │bert.│  │     .com     │
└────┬────┘ └─────┬──────┘  └──┬──┘  └──────┬───────┘
     │            │             │            │
     └────────────┼─────────────┴────────────┘
                  │
         ┌────────▼─────────┐
         │   PHP-FPM 7.1    │
         │   Port 9000      │
         └────────┬─────────┘
                  │
         ┌────────▼──────────┐
         │   MySQL 5.7       │
         │   Port 3306       │
         │   (boira, etc)    │
         └───────────────────┘

     ┌─────────────────────────────────────────┐
     │  Supporting Services (Internal Network) │
     ├──────────────────────────────────────────┤
     │  • Redis (6379) - Cache/Sessions        │
     │  • Memcached (11211) - Cache            │
     │  • Beanstalkd (11300) - Work Queue      │
     │  • Dockge UI (5001) - Management        │
     └──────────────────────────────────────────┘
```

## Network Architecture

All containers communicate via isolated Docker network `ritchie`:

- **Internal**: Containers reach each other by service name (e.g., `mysql:3306`, `redis:6379`)
- **External**: Only Nginx and Dockge ports exposed to host
- **Security**: Services cannot be accessed from outside except through Nginx

## Data Persistence

### Volumes

- **mysql_data**: MySQL database files (`/var/lib/mysql`)
- **redis_data**: Redis persistence (`/data`)
- **nginx_cache**: Nginx cache for W3TC (`/var/cache/nginx`)
- **nginx_logs**: Nginx access/error logs (`/var/log/nginx`)
- **app directories**: Website files mounted from `./apps/`

Volumes persist when containers restart or are updated.

### Backups

Backup strategy:

1. **Daily automated backups** (configure in Dockge)
2. **Pre-update backups** (via Dockge before service updates)
3. **Manual backups** (one-click in Dockge UI)

Backups stored in `/app/backups/` with timestamps.

## Security Considerations

### Passwords

Update default passwords in `.env`:
```bash
MYSQL_ROOT_PASSWORD=strong_random_password_here
MYSQL_FORGE_PASSWORD=another_strong_password
```

### SSL Certificates

- **boira.band**: Self-signed (regenerate yearly)
- **lodrago.net**: Let's Encrypt (auto-renew via Dockge)
- **bertomeuiglesias.com**: Self-signed
- **ace.tonioriol.com**: Configure via Dockge

### Network Access

Currently exposing:
- Port 80 (HTTP)
- Port 443 (HTTPS)
- Port 5001 (Dockge) — should be restricted or use VPN

### Firewall Rules

```bash
# Recommended firewall configuration
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw allow 5001/tcp # Dockge (restrict to VPN/local)
sudo ufw default deny incoming
```

## Monitoring & Logging

### View Logs

**All services:**
```bash
docker-compose logs -f
```

**Specific service:**
```bash
docker-compose logs -f nginx
```

**Last N lines:**
```bash
docker-compose logs --tail=100 mysql
```

### Resource Monitoring

**In Dockge UI:** Dashboard shows real-time CPU, Memory, Network usage

**Via CLI:**
```bash
docker stats
```

### Health Checks

Services have built-in health checks:
- MySQL: Responds to ping
- Nginx: HTTP request to localhost
- Redis: Redis CLI ping

Dockge UI shows health status for each service.

## Troubleshooting

### Service won't start
1. Check logs: `docker-compose logs service_name`
2. Verify volume permissions: `ls -la apps/`
3. Check port conflicts: `netstat -tulpn | grep -E ':(80|443|3306)'`

### Website shows 502 Bad Gateway
1. Check PHP-FPM: `docker-compose logs php-fpm`
2. Verify MySQL connection: `docker-compose logs mysql`
3. Restart PHP-FPM: `docker-compose restart php-fpm`

### Database connection refused
1. Verify MySQL running: `docker-compose ps mysql`
2. Check credentials in wp-config.php
3. View MySQL logs: `docker-compose logs mysql`

### High disk usage
1. Check volume sizes: `docker volume ls -f dangling=false`
2. Clean old logs: `docker exec ritchie-nginx rm -f /var/log/nginx/*.log.1`
3. Prune dangling volumes: `docker volume prune`

For more troubleshooting, see [`DEPLOYMENT.md`](./DEPLOYMENT.md#troubleshooting)

## Maintenance

### Regular Tasks

- **Weekly**: Check disk space and log sizes
- **Monthly**: Review resource usage trends
- **Quarterly**: Update all container images
- **Yearly**: Rotate SSL certificates (if self-signed)

### Updates

To update container images:

```bash
# Update all images
docker-compose pull
docker-compose up -d

# Update specific service
docker-compose pull nginx
docker-compose up -d nginx
```

### Scaling

To handle increased traffic:

1. Increase PHP-FPM workers in `docker-compose.yml`
2. Increase MySQL innodb buffer pool in `docker-compose.yml`
3. Monitor with Dockge dashboard
4. Add load balancer if needed (future enhancement)

## Documentation Files

- **[`CONTAINERIZATION_AUDIT.md`](./CONTAINERIZATION_AUDIT.md)** — Detailed analysis of current services and migration strategy
- **[`DEPLOYMENT.md`](./DEPLOYMENT.md)** — Complete step-by-step deployment instructions
- **[`DOCKGE_README.md`](./DOCKGE_README.md)** — User guide for managing everything through Dockge UI
- **[`docker-compose.yml`](./docker-compose.yml)** — Complete stack definition

## Support & Resources

- **Docker**: https://docs.docker.com/
- **Docker Compose**: https://docs.docker.com/compose/
- **Dockge**: https://dockge.kuma.pet/
- **Nginx**: https://nginx.org/en/docs/
- **PHP-FPM**: https://www.php.net/manual/en/install.fpm.php
- **WordPress**: https://wordpress.org/support/

## Next Steps

1. ✅ Review [`CONTAINERIZATION_AUDIT.md`](./CONTAINERIZATION_AUDIT.md)
2. ✅ Follow [`DEPLOYMENT.md`](./DEPLOYMENT.md) for deployment
3. ✅ Access Dockge UI at `https://ritchie.tonioriol.com:5001`
4. ✅ Read [`DOCKGE_README.md`](./DOCKGE_README.md) for management
5. 📋 Configure automated backups in Dockge
6. 📋 Set up monitoring/alerts
7. 📋 Plan PHP 7.1 → 8.x upgrade for future
8. 📋 Document any custom configurations

---

**Last Updated**: January 18, 2026
**Architecture Version**: 2.0 (Containerized)
**Status**: Ready for deployment
