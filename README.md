# ritchie

Minimal notes for the `ritchie` server.

## Connection

- Host: `ritchie.tonioriol.com`
- IP: `188.226.140.165`
- SSH user: `forge`
- SSH port: `22`
- Auth: `publickey` (password auth disabled)

```bash
ssh forge@ritchie.tonioriol.com
```

### Force a specific local key (fallback)

```bash
ssh -i /Users/tr0n/.ssh/id_rsa_2 -o IdentitiesOnly=yes forge@ritchie.tonioriol.com
```

## Users

Home directories under `/home`:

- `forge` (uid 1000, shell `/bin/bash`)
- `syslog` (uid 104, shell `/bin/false`)

## Credentials source of truth

Non-secret connection metadata is stored in 1Password item **“ritchie”** (category: Server, vault: Private).

## Services Running

### Web Server & Reverse Proxy

- **Nginx** - Web server and reverse proxy
- **PHP 7.1-FPM** - PHP FastCGI Process Manager

### Databases

- **MySQL** - MySQL Community Server (default port 3306)
- **PostgreSQL 9.5** - PostgreSQL database server (default port 5432)

### Caching & Queuing

- **Redis** - Advanced key-value store (port 6379)
- **Memcached** - In-memory cache daemon
- **Beanstalkd** - Simple, fast work queue (port 11300)

### Docker & Containerization

- **Docker** - Docker daemon
- **containerd** - Container runtime
- **LXC/LXCFS** - Container support

### Security & Monitoring

- **Fail2Ban** - Intrusion prevention system
- **SSH** - OpenBSD Secure Shell server (port 22)

### System Services

- **Supervisor** - Process control system (manages background jobs)
- **Cron** - Task scheduler
- **Sendmail** - Mail Transfer Agent (MTA)
- **Syslog/rsyslog** - System logging

### Other

- **ACPI daemon** - ACPI event handling
- **LVM2** - Logical Volume Management
- **RAID/mdadm** - Software RAID monitoring
- **iSCSI** - iSCSI initiator daemon

## Hosted Sites

### Nginx Virtual Hosts

1. **ace.tonioriol.com** (HTTPS)
   - Type: Reverse proxy
   - Backend: Docker container `acestream-http-proxy`
   - Port: 6878 (internal), proxied through HTTPS
   - Notes: Streams via Acestream protocol with CORS headers enabled

2. **boira.band** (HTTPS)
   - Type: Laravel/PHP application
   - Processor: PHP 7.1-FPM
   - SSL: Self-signed certificate
   - Managed by: Laravel Forge

3. **bertomeuiglesias.com**
   - Type: Laravel/PHP application
   - Processor: PHP 7.1-FPM
   - Managed by: Laravel Forge

4. **lodrago.net**
   - Type: Laravel/PHP application
   - Processor: PHP 7.1-FPM
   - Managed by: Laravel Forge

5. **tonioriol.com**
   - Type: Redirect (→ GitHub)
   - HTTP redirection configured
   - Laravel/Forge infrastructure available but not actively used

6. **catch-all** site
   - Default fallback for undefined hosts

## Docker Containers

```yaml
Service: acestream-http-proxy
Image: ghcr.io/martinbjeldbak/acestream-http-proxy
Port: 6878
Status: Running (up 8 weeks)
Memory: 128-256MB reserved/limited
Restart Policy: unless-stopped
```

Configuration: `/home/forge/acestream-http-proxy/docker-compose.yml`

## Notes

- The server is running **Ubuntu 16.04** (legacy). Be cautious with upgrades/changes.
- Managed by **Laravel Forge** (legacy setup, manually maintained now)
- All sites use Nginx with PHP 7.1-FPM backend
- SSL certificates: Let's Encrypt (ace.tonioriol.com), self-signed (boira.band)
- Databases are accessible locally; check 1Password credentials
- Supervisor manages background processes/workers
- Fail2Ban provides automatic IP blocking for security threats
