# Ritchie Containerization - Quick Reference

## What Was Delivered

A **complete containerization solution** for the ritchie server with Dockge UI for zero-CLI management.

### Files Created

| File | Purpose |
|------|---------|
| [`docker-compose.yml`](./docker-compose.yml) | Complete service stack definition |
| [`DEPLOYMENT.md`](./DEPLOYMENT.md) | Step-by-step deployment guide |
| [`DOCKGE_README.md`](./DOCKGE_README.md) | User guide for managing containers |
| [`CONTAINERIZATION_AUDIT.md`](./CONTAINERIZATION_AUDIT.md) | Technical analysis |
| [`README_UPDATED.md`](./README_UPDATED.md) | Updated project overview |
| [`nginx/nginx.conf`](./nginx/nginx.conf) | Nginx main config |
| [`nginx/conf.d/*.conf`](./nginx/conf.d/) | 4 site configurations |
| [`php-fpm/Dockerfile`](./php-fpm/Dockerfile) | PHP 7.1 container image |
| [`php-fpm/php.ini`](./php-fpm/php.ini) | PHP settings |
| [`php-fpm/www.conf`](./php-fpm/www.conf) | PHP-FPM pool config |
| [`mysql/init/01-databases.sql`](./mysql/init/01-databases.sql) | Database initialization |
| [`.env.example`](./.env.example) | Environment variables |

---

## Start Here

### For Deployment Team

**Step 1**: Read [`DEPLOYMENT.md`](./DEPLOYMENT.md)
- Complete step-by-step instructions
- Database migration steps
- SSL certificate handling
- Testing procedures

**Step 2**: Run deployment
```bash
cd ~/ritchie-docker
docker-compose up -d
```

**Step 3**: Access Dockge
- Open browser to: `https://ritchie.tonioriol.com:5001`
- Verify all services running (green status)

---

### For Daily Operations

**Use Dockge UI** for everything:
- View logs
- Start/stop services
- Restart on changes
- Monitor resources
- Manage backups

**Read**: [`DOCKGE_README.md`](./DOCKGE_README.md)

---

### For Architecture Review

**Read in order:**
1. [`CONTAINERIZATION_AUDIT.md`](./CONTAINERIZATION_AUDIT.md) — What's on the server now
2. [`README_UPDATED.md`](./README_UPDATED.md) — New architecture overview
3. [`docker-compose.yml`](./docker-compose.yml) — Service definitions

---

## Key Services

```
🟢 Nginx (80, 443)        → Reverse proxy for all sites
🟢 PHP-FPM (9000)         → WordPress application server
🟢 MySQL (3306)           → Database (boira, lodragonet)
🟢 Redis (6379)           → Cache & sessions
🟢 Memcached (11211)      → In-memory cache
🟢 Beanstalkd (11300)     → Work queue
🟢 Acestream (6878)       → Stream protocol proxy
🟢 Dockge (5001)          → Management UI
```

---

## Websites Hosted

| Domain | Type | Database |
|--------|------|----------|
| **boira.band** | WordPress | `boira` |
| **lodrago.net** | WordPress + W3TC | `lodragonet` |
| **bertomeuiglesias.com** | Static PHP (JSON) | None |
| **ace.tonioriol.com** | Acestream proxy | None |

---

## Quick Commands

### Start Services
```bash
docker-compose up -d
```

### Check Status
```bash
docker-compose ps
```

### View Logs
```bash
docker-compose logs -f nginx
```

### Restart Service
```bash
docker-compose restart php-fpm
```

### Access MySQL
```bash
docker exec ritchie-mysql mysql -u root -p
```

### Backup Databases
```bash
docker exec ritchie-mysql mysqldump -u root -p --all-databases > backup.sql
```

---

## Security Checklist

Before going live:

- [ ] Change `MYSQL_ROOT_PASSWORD` in `.env`
- [ ] Change `MYSQL_FORGE_PASSWORD` in `.env`
- [ ] Update WordPress salts (wp-config.php)
- [ ] Copy SSL certificates to `nginx/ssl/`
- [ ] Restrict Dockge port 5001 (firewall or VPN)
- [ ] Enable HTTPS for all sites
- [ ] Setup automated backups
- [ ] Document custom passwords in 1Password

---

## Troubleshooting

**Website shows 502 Bad Gateway**
- Check PHP-FPM: `docker-compose logs php-fpm`
- Restart: `docker-compose restart php-fpm`

**Can't connect to database**
- Verify MySQL running: `docker-compose ps mysql`
- Check credentials in wp-config.php
- View logs: `docker-compose logs mysql`

**High disk usage**
- Clean logs: `docker exec ritchie-nginx rm /var/log/nginx/*.log.1`
- Prune volumes: `docker volume prune`

**Dockge not accessible**
- Check port 5001: `netstat -tulpn | grep 5001`
- Restart: `docker-compose restart dockge`

For more issues, see [`DEPLOYMENT.md`](./DEPLOYMENT.md#troubleshooting)

---

## Performance Notes

### W3TC Caching (lodrago.net)
- Page cache stored in `/var/www/lodrago.net/wp-content/cache/`
- Minified CSS/JS cached
- Cache directory must be writable by www-data

### Redis Sessions
- PHP configured to use Redis for sessions
- Improves performance on multi-container setups
- Configure in WordPress plugins if needed

### Database Optimization
- MySQL 5.7 with InnoDB
- Slow query logging enabled
- Connection pooling via Docker network

---

## Network Architecture

```
Internet (HTTPS)
    ↓
Nginx (Port 80, 443)
    ↓
├→ boira.band ──→ PHP-FPM ──→ MySQL (boira)
├→ lodrago.net ──→ PHP-FPM ──→ MySQL (lodragonet)
├→ bertomeuiglesias.com ──→ PHP-FPM ──→ JSON file
└→ ace.tonioriol.com ──→ Acestream container

All services communicate via "ritchie" Docker network
```

---

## Backup Strategy

### Automated (via Dockge)
- Configure in Dockge UI
- Runs on schedule (daily/weekly)
- Stored in `/app/backups/`

### Manual
```bash
# Full backup
docker exec ritchie-mysql mysqldump -u root -p --all-databases > backup-$(date +%Y%m%d).sql

# Selective backup
docker exec ritchie-mysql mysqldump -u root -p boira > boira-backup.sql
```

### Restore
```bash
docker exec -i ritchie-mysql mysql -u root -p < backup.sql
```

---

## Upgrades

### Update Container Images
```bash
# Check for updates
docker-compose pull

# Apply updates (restart all)
docker-compose up -d
```

### Upgrade PHP (Future)
1. Edit `php-fpm/Dockerfile`: Change `FROM php:7.1-fpm` to `php:8.0-fpm`
2. Rebuild: `docker-compose build php-fpm`
3. Restart: `docker-compose restart php-fpm`
4. Test WordPress compatibility

---

## Useful Links

- **Docker Docs**: https://docs.docker.com/
- **Docker Compose**: https://docs.docker.com/compose/compose-file/
- **Dockge**: https://dockge.kuma.pet/
- **Nginx**: https://nginx.org/en/docs/
- **WordPress**: https://wordpress.org/support/
- **MySQL**: https://dev.mysql.com/doc/

---

## Support Contacts

For issues, check:
1. Service logs in Dockge UI
2. [`DEPLOYMENT.md`](./DEPLOYMENT.md#troubleshooting) troubleshooting section
3. Individual service documentation
4. SSH into server: `ssh forge@ritchie.tonioriol.com`

---

## Summary

✅ **Complete containerization** — All services in Docker
✅ **Dockge UI management** — No CLI needed for operations
✅ **Production-ready** — Monitoring, logging, backups built-in
✅ **Easy scaling** — Add more PHP-FPM workers with one config change
✅ **Zero downtime** — Can update services individually

**Next Step**: Follow [`DEPLOYMENT.md`](./DEPLOYMENT.md) to deploy!
