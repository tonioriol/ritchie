# Dockge Management Guide for Ritchie Server

## Overview

**Dockge** is a lightweight, user-friendly Docker Compose UI that allows you to manage all containerized services on ritchie without using the command line.

- **URL**: `https://ritchie.tonioriol.com:5001`
- **Purpose**: Centralized management of Nginx, PHP-FPM, MySQL, Redis, Memcached, Beanstalkd, and Acestream services

## Accessing Dockge

1. Open your browser and navigate to: `https://ritchie.tonioriol.com:5001`
2. Log in with credentials (setup during initial deployment)
3. You'll see the main dashboard

## Main Dashboard

The Dockge interface shows:

- **Stacks**: Individual Docker Compose projects
- **Services**: Running containers within each stack
- **Volumes**: Persistent storage for databases and files
- **Networks**: Inter-container communication

## Managing Services

### Viewing Service Status

1. Click on the "Ritchie" stack in Dockge
2. All services are displayed with their status:
   - 🟢 Green = Running
   - 🔴 Red = Stopped
   - 🟡 Yellow = Restarting

### Starting Services

```
Services → Select Service → Click "Start"
```

Example:
- Click "mysql" → "Start" (starts MySQL container)
- All dependent services will be notified

### Stopping Services

```
Services → Select Service → Click "Stop"
```

**Warning**: Stopping nginx or mysql will affect website availability.

### Restarting Services

```
Services → Select Service → Click "Restart"
```

Used after configuration changes or troubleshooting.

### Viewing Service Logs

```
Services → Select Service → Click "Logs"
```

Real-time logs help diagnose issues:

**Common scenarios:**
- **nginx errors**: Check nginx logs if sites aren't loading
- **PHP-FPM errors**: Check php-fpm logs for WordPress issues
- **MySQL errors**: Check mysql logs for database connection problems

## Managing Containers

### View Resource Usage

In Dockge:
- Memory/CPU usage shown for each running container
- "Stats" tab shows detailed resource monitoring

### Update Container Images

When new container images are released:

1. In Dockge: Stack → Services
2. Select service → "Update"
3. Dockge pulls latest image version
4. Service is restarted with new image

Example: Update acestream-http-proxy to latest version
```
acestream-http-proxy → "Update" → "Confirm"
```

### Access Container Shell

```
Services → Select Service → "Terminal"
```

Execute commands inside running containers:

**Useful commands:**

```bash
# Check MySQL databases
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"

# Check PHP version
php -v

# Check Nginx configuration
nginx -t

# Check Redis connectivity
redis-cli ping
```

## Managing Volumes

### View Persistent Storage

In Dockge: Volumes → Lists all data volumes

**Key volumes on ritchie:**
- `ritchie_mysql_data`: WordPress database files
- `ritchie_redis_data`: Redis cache data
- `nginx_logs`: Nginx access/error logs
- `nginx_cache`: Nginx cache storage
- Website directories: `/var/www/boira.band`, etc.

### Backup Volumes

In Dockge:

1. Select Volume → "Backup"
2. Dockge creates snapshot of data
3. Download or store offline

**Example**: Back up WordPress databases before major updates

### Restore from Backup

1. Select Volume → "Restore"
2. Choose backup file
3. Dockge restores data to current state

## Editing Configuration

### Modify docker-compose.yml

In Dockge:

1. Click "Compose" → Select "ritchie" stack
2. Edit YAML configuration
3. "Save" → Services automatically restart

**Common edits:**
- Change PHP memory limit
- Adjust database credentials
- Add new environment variables
- Modify port mappings

### Environment Variables

In Dockge:

1. Stack Settings → "Environment"
2. Add/modify key-value pairs
3. Services that use variables restart

**Example**: Update MySQL password
```
MYSQL_FORGE_PASSWORD=new_secure_password_here
```

## Monitoring & Alerts

### View Service Health

Dockge shows service status indicators:

- **Health checks**: Services with automatic failure detection
- **Restart policy**: Services that auto-restart on failure
- **Logs**: Real-time output for debugging

### Common Issues & Solutions

#### Website Not Loading
```
1. Check Nginx status: Services → nginx → "Logs"
2. Check PHP-FPM status: Services → php-fpm → "Logs"
3. Check connectivity: Services → php-fpm → "Terminal" → ping mysql
```

#### Database Connection Error
```
1. Verify MySQL is running: Services → mysql → Status
2. Check credentials in wp-config.php
3. View MySQL logs: Services → mysql → "Logs"
```

#### High Memory Usage
```
1. Check which service: View "Stats" tab
2. Restart service: Services → [Service] → "Restart"
3. Check resource limits in docker-compose.yml
```

#### Website Files Not Updating
```
1. Check volume mounts: Volumes tab
2. Verify file permissions: Terminal → ls -la /var/www/
3. Restart php-fpm: Services → php-fpm → "Restart"
```

## Backup & Recovery

### Automated Backups

Set up scheduled backups in Dockge:

1. Stack Settings → "Backup Schedule"
2. Configure frequency (daily, weekly, etc.)
3. Backups stored in `/app/backups/`

**What's backed up:**
- MySQL databases
- Website files
- Configuration files
- SSL certificates

### Manual Backup

Before major changes:

```
1. In Dockge: Stack → "Backup Now"
2. Wait for completion
3. Download backup file (or keep on server)
```

### Recovery Steps

If data is lost:

```
1. In Dockge: Stack → "Restore"
2. Select backup date
3. Confirm restoration
4. Services automatically update with recovered data
```

## Security Best Practices

### Change Default Credentials

After initial setup, change all passwords:

1. Stack Settings → "Environment"
2. Update:
   - `MYSQL_ROOT_PASSWORD`
   - `MYSQL_FORGE_PASSWORD`
   - Any API keys or secrets
3. Restart affected services

### Manage SSL Certificates

In Dockge:

1. Stack Settings → "SSL"
2. Upload certificates for each domain
3. Configure auto-renewal (if using Let's Encrypt)

**Domains managed:**
- boira.band
- lodrago.net
- bertomeuiglesias.com
- ace.tonioriol.com

### Network Security

Dockge services communicate on isolated "ritchie" network:

- Services can't be accessed directly from outside
- All external traffic goes through Nginx reverse proxy
- Firewall rules: Only ports 80, 443, 5001 exposed

## Performance Tuning

### Resource Limits

In Dockge: Edit docker-compose.yml

Set memory/CPU limits per service:

```yaml
deploy:
  resources:
    limits:
      memory: 256M
      cpus: '1.0'
    reservations:
      memory: 128M
```

### Scaling Services

For high-traffic scenarios, increase PHP-FPM workers:

```yaml
php-fpm:
  environment:
    PM_MAX_CHILDREN: 50  # Default: 20
    PM_START_SERVERS: 10  # Default: 5
```

### Cache Optimization

Enable Redis for WordPress:

1. Install Redis Object Cache plugin in WordPress admin
2. Configure to use `redis:6379`
3. Verify caching works: Services → redis → "Terminal" → `redis-cli INFO`

## Updates & Upgrades

### Update Individual Services

```
Services → Select Service → "Update" → Confirm
```

### Update All Services

```
Stack → "Update Stack" → Auto-pulls latest images
```

**Services with regular updates:**
- nginx (security patches)
- mysql (security patches)
- php-fpm (PHP updates)
- dockge (UI improvements)

### Upgrade PHP Version

⚠️ **Note**: Currently running PHP 7.1 (legacy). Consider upgrading to PHP 8.0+

To upgrade:

1. Edit `php-fpm/Dockerfile` to use `php:8.0-fpm-alpine`
2. Rebuild image: `docker-compose build php-fpm`
3. Restart: `Services → php-fpm → Restart`
4. Test WordPress compatibility

## Debugging with Dockge

### Enable Debug Logging

In Dockge:

1. Stack Settings → "Environment"
2. Add `DEBUG=true`
3. Restart relevant service
4. Check logs for verbose output

### Common Debug Commands

In Service Terminal:

```bash
# Test database connection
mysql -h mysql -u forge -p${MYSQL_FORGE_PASSWORD} boira -e "SELECT 1;"

# Check WordPress configuration
cat /var/www/boira.band/wp-config.php | grep DB_

# Verify Nginx configuration
nginx -t

# List running processes
ps aux

# Check disk usage
df -h
```

## Advanced Features

### Custom Scripts

Add cron jobs or maintenance scripts:

1. Create script file in `/app/scripts/`
2. In Dockge: Stack Settings → "Scripts"
3. Configure execution schedule

**Example**: Daily WordPress backup
```bash
#!/bin/bash
mysqldump -h mysql -u root -p${MYSQL_ROOT_PASSWORD} boira > /backups/boira-$(date +%Y%m%d).sql
```

### Webhooks & Integrations

Dockge supports webhooks for:
- GitHub deployment triggers
- Slack notifications
- Custom API endpoints

## Support & Documentation

- **Official Dockge Docs**: https://dockge.kuma.pet/
- **Docker Compose Reference**: https://docs.docker.com/compose/
- **Ritchie Stack Repository**: This directory

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Services won't start | Check logs, verify volume permissions, check ports not in use |
| Website shows error 502 | Restart php-fpm, check MySQL connectivity |
| Database corruption | Restore from recent backup, check disk space |
| High CPU usage | Check WordPress plugins, enable caching, review logs |
| Disk space low | Check backup storage, clean old logs, prune Docker volumes |
| SSL certificate expired | Upload new certificate, restart Nginx |
| Can't access Dockge UI | Check port 5001 open, restart dockge container |

## Contact & Support

For issues with:
- **Websites**: Check individual site logs in Dockge
- **Containers**: Review Docker Compose configuration
- **Server**: SSH to `forge@ritchie.tonioriol.com` for direct access
- **Backups**: Verify in `/app/backups/` directory
