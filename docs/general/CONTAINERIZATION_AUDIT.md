# Ritchie Server Containerization Audit

## Current Infrastructure Analysis

### Websites & Applications

#### 1. **boira.band** ✅ WordPress
- **Type**: WordPress blog
- **Database**: `boira` (MySQL, user: `forge`)
- **Root**: `/home/forge/boira.band/`
- **PHP**: 7.1-FPM
- **SSL**: Self-signed certificate
- **Status**: Active (last modified Jan 17, 2025)
- **Git**: Managed via git repo

#### 2. **lodrago.net** ✅ WordPress
- **Type**: WordPress blog with W3TC caching
- **Database**: `lodragonet` (MySQL, user: `lodragonet`, password: `lodragonet`)
- **Root**: `/home/forge/lodrago.net/public/`
- **PHP**: 7.1-FPM
- **SSL**: Let's Encrypt
- **Status**: Active (last modified Jan 18, 2025)
- **Special**: W3TC minify and page caching enabled
- **Max upload**: 50MB

#### 3. **bertomeuiglesias.com** ✅ Static PHP Portfolio
- **Type**: Multi-language static site (ES/CA/FR)
- **Database**: `texts.json` (local JSON file)
- **Root**: `/home/forge/bertomeuiglesias.com/`
- **PHP**: 7.1-FPM (minimal usage)
- **SSL**: Self-signed certificate
- **Status**: Archived (git repo, no recent changes)
- **Special**: JSON-based content, no database needed

#### 4. **tonioriol.com**
- **Type**: HTTP redirect to GitHub
- **Status**: Minimal traffic

#### 5. **ace.tonioriol.com** 🐳 Already Containerized
- **Type**: Acestream HTTP proxy
- **Container**: `acestream-http-proxy`
- **Image**: `ghcr.io/martinbjeldbak/acestream-http-proxy`
- **Port**: 6878
- **Memory**: 128-256MB

### System Services to Containerize

| Service | Purpose | Port | Current Status |
|---------|---------|------|-----------------|
| **Nginx** | Web server & reverse proxy | 80, 443 | Running |
| **PHP 7.1-FPM** | PHP FastCGI | unix socket | Running |
| **MySQL** | Database server | 3306 | Running |
| **Redis** | Cache/Session store | 6379 | Running |
| **Memcached** | Caching daemon | 11211 | Running |
| **Beanstalkd** | Work queue | 11300 | Running |

## Containerization Strategy

### Phase 1: Data Export
- [x] Identify WordPress databases (`boira`, `lodragonet`)
- [ ] Export MySQL databases
- [ ] Back up website files
- [ ] Preserve SSL certificates or regenerate with Let's Encrypt

### Phase 2: Docker Compose Stack
Build multi-service stack:
```
┌─────────────────────────────────────────────┐
│ Docker Compose Stack (ritchie)              │
├─────────────────────────────────────────────┤
│ • nginx (reverse proxy) → port 80, 443      │
│ • php-fpm (PHP 7.1)                         │
│ • mysql (WordPress databases)               │
│ • redis (caching)                           │
│ • memcached (in-memory cache)               │
│ • beanstalkd (work queue)                   │
│ • acestream-http-proxy (existing)           │
└─────────────────────────────────────────────┘
```

### Phase 3: Dockge Installation
- Install Dockge on ritchie
- Point Dockge to docker-compose.yml
- Manage all services through UI

### Phase 4: Migration Steps
1. Stop current system services
2. Import MySQL databases into MySQL container
3. Mount website volumes in containers
4. Start Docker Compose stack
5. Test all sites
6. Update DNS/SSL if needed

## Database Details

### WordPress Databases to Migrate
```
boira      → MySQL database
lodragonet → MySQL database
```

### Non-Database Sites
```
bertomeuiglesias.com → JSON file (texts.json) - copy to volume
```

## Special Considerations

- **W3TC Caching**: lodrago.net uses W3TC with file-based cache in `/wp-content/cache/page_enhanced/`. Must persist this volume.
- **SSL Certificates**:
  - boira.band: Self-signed (can regenerate)
  - lodrago.net: Let's Encrypt (need to preserve or auto-renew)
  - ace.tonioriol.com: Via Nginx proxy
- **PHP Version**: Legacy PHP 7.1 (security risk, consider upgrade to 7.4+ in future)
- **Large Media**: lodrago.net allows 50MB uploads, ensure volume capacity
- **File Permissions**: WordPress requires proper ownership (www-data:www-data or equivalent in container)

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Data loss during migration | Full MySQL backup before container migration |
| SSL certificate downtime | Pre-generate or use Let's Encrypt auto-renewal |
| W3TC cache compatibility | Mount cache volume as persistent |
| Database connection issues | Use Docker DNS (service name resolution) |
| Performance regression | Monitor CPU/memory during transition |

## Next Steps

1. **Create `docker-compose.yml`** with all services
2. **Export current MySQL databases**
3. **Setup volume structure** for persistent data
4. **Install Dockge** on ritchie
5. **Test containerized setup** in parallel before cutover
6. **Document final architecture** in README.md
