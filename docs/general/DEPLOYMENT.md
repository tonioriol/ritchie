# Ritchie Server Containerization Deployment Guide

## Prerequisites

- Docker and Docker Compose installed on ritchie server
- SSH access to `forge@ritchie.tonioriol.com`
- Backup of current MySQL databases
- SSL certificates (or ability to generate new ones)

## Step 1: Prepare the Server

SSH into ritchie:
```bash
ssh forge@ritchie.tonioriol.com
```

Create directory structure:
```bash
mkdir -p ~/ritchie-docker/{apps,nginx/conf.d,nginx/ssl,php-fpm,mysql/init,mysql/data,dockge/data,acestream-data}
cd ~/ritchie-docker
```

## Step 2: Export Current Databases

Export WordPress databases from current MySQL installation:
```bash
# Export boira database
mysqldump -u forge -p boira > mysql/init/02-boira.sql

# Export lodragonet database
mysqldump -u forge -p lodragonet > mysql/init/03-lodragonet.sql

# Or via Docker if already containerized:
docker exec ritchie-mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} boira > mysql/init/02-boira.sql
docker exec ritchie-mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} lodragonet > mysql/init/03-lodragonet.sql
```

## Step 3: Copy Website Files

Copy website directories to container mount points:
```bash
# From system to Docker structure
cp -r /home/forge/boira.band apps/
cp -r /home/forge/lodrago.net apps/
cp -r /home/forge/bertomeuiglesias.com apps/
cp -r /home/forge/acestream-http-proxy/acestream-data ./acestream-data

# Fix permissions
chmod -R 755 apps/*
chmod -R 755 acestream-data/
```

## Step 4: Configure SSL Certificates

Copy existing SSL certificates:
```bash
mkdir -p nginx/ssl/{boira.band,lodrago.net,bertomeuiglesias.com,ace.tonioriol.com}

# Copy from Nginx directories
cp /etc/nginx/ssl/boira.band/*/server.crt nginx/ssl/boira.band/
cp /etc/nginx/ssl/boira.band/*/server.key nginx/ssl/boira.band/

cp /etc/nginx/ssl/lodrago.net/*/server.crt nginx/ssl/lodrago.net/
cp /etc/nginx/ssl/lodrago.net/*/server.key nginx/ssl/lodrago.net/

cp /etc/nginx/ssl/bertomeuiglesias.com/*/server.crt nginx/ssl/bertomeuiglesias.com/
cp /etc/nginx/ssl/bertomeuiglesias.com/*/server.key nginx/ssl/bertomeuiglesias.com/

# For ace.tonioriol.com (use Let's Encrypt or self-signed)
# If using Let's Encrypt, adjust docker-compose.yml to use Certbot container
```

**Alternative: Use Let's Encrypt with Certbot**

Update `docker-compose.yml` to add Certbot service and auto-renewal.

## Step 5: Setup Environment File

Copy and customize `.env`:
```bash
cp .env.example .env
# Edit .env with strong passwords
vi .env
```

**Important secrets to change:**
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_FORGE_PASSWORD`

## Step 6: Update WordPress Configuration

Update database connection strings in WordPress apps:

**For boira.band (`apps/boira.band/wp-config.php`):**
```php
define('DB_HOST', 'mysql:3306');  // Was 'localhost'
define('DB_USER', 'forge');
define('DB_PASSWORD', getenv('MYSQL_FORGE_PASSWORD') ?: 'forge_changeme_12345');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

// Redis caching (optional but recommended)
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
define('WP_CACHE', true);
define('WP_CACHE_KEY_SALT', 'boira.band_');
```

**For lodrago.net (`apps/lodrago.net/wp-config.php`):**
```php
define('DB_HOST', 'mysql:3306');
define('DB_USER', 'lodragonet');
define('DB_PASSWORD', 'lodragonet');  // Keep as per original
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

// W3TC will use file-based cache on persistent volume
```

## Step 7: Validate Docker Configuration

Validate the docker-compose.yml:
```bash
docker-compose config
```

Build PHP-FPM image:
```bash
docker-compose build php-fpm
```

## Step 8: Start Docker Compose Stack

Start services in order:
```bash
docker-compose up -d mysql
sleep 30  # Wait for MySQL to initialize

docker-compose up -d redis memcached beanstalkd
docker-compose up -d php-fpm

docker-compose up -d nginx acestream-http-proxy
docker-compose up -d dockge
```

Check services:
```bash
docker-compose ps
docker-compose logs -f
```

## Step 9: Verify Database Setup

```bash
# Check database initialization
docker exec ritchie-mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"

# Verify WordPress tables
docker exec ritchie-mysql mysql -u forge -p${MYSQL_FORGE_PASSWORD} boira -e "SHOW TABLES;"
docker exec ritchie-mysql mysql -u lodragonet -plodragonet lodragonet -e "SHOW TABLES;"
```

## Step 10: Test Website Access

**Before DNS update**, test using `/etc/hosts`:

```bash
# On your local machine (macOS)
echo "188.226.140.165 boira.band lodrago.net bertomeuiglesias.com ace.tonioriol.com" | sudo tee -a /etc/hosts
```

Then access:
- https://boira.band
- https://lodrago.net
- https://bertomeuiglesias.com
- https://ace.tonioriol.com

## Step 11: Install & Configure Dockge

Access Dockge UI:
- URL: `https://ritchie.tonioriol.com:5001`
- Default credentials: Check Dockge documentation

Add the ritchie stack:
1. Click "Compose"
2. Navigate to `/app/stacks/ritchie`
3. Load `docker-compose.yml`
4. Start managing all containers from UI

## Step 12: Migrate System Services

**Stop current system services (optional, only after full testing):**

```bash
# Only do this after verifying containers work!
sudo systemctl stop nginx
sudo systemctl stop php7.1-fpm
# Don't stop MySQL/Redis/etc yet - coordinate cutover

# Eventually, disable at boot
sudo systemctl disable nginx
sudo systemctl disable php7.1-fpm
```

## Step 13: Update DNS (if needed)

If using new server IP or DNS changes required:
```bash
# Update DNS records for:
# - boira.band A record → 188.226.140.165
# - lodrago.net A record → 188.226.140.165
# - bertomeuiglesias.com A record → 188.226.140.165
# - ace.tonioriol.com A record → 188.226.140.165
```

## Backup Strategy

Create automated backup volumes:
```bash
# Add to docker-compose.yml cron or use backup container
docker run --rm -v ritchie_mysql_data:/data -v /backups:/backups alpine tar czf /backups/mysql-$(date +%Y%m%d).tar.gz -C /data .
```

## Troubleshooting

### Database Connection Issues
```bash
# Test MySQL connectivity from PHP container
docker exec ritchie-php-fpm php -r "mysqli_connect('mysql', 'forge', 'forge_changeme_12345', 'boira');"
```

### WordPress Not Loading
```bash
# Check WordPress table structure
docker exec ritchie-mysql mysql -u forge -p${MYSQL_FORGE_PASSWORD} boira -e "SELECT * FROM wp_options LIMIT 5;"
```

### W3TC Cache Not Working
```bash
# Check cache directory permissions
docker exec ritchie-nginx ls -la /var/www/lodrago.net/wp-content/cache/
```

### SSL Certificate Warnings
```bash
# Regenerate self-signed certificates if needed
docker exec ritchie-nginx openssl req -x509 -newkey rsa:2048 -keyout /etc/nginx/ssl/boira.band/server.key -out /etc/nginx/ssl/boira.band/server.crt -days 365 -nodes
```

## Monitoring

### View Logs
```bash
# Nginx
docker-compose logs -f nginx

# PHP-FPM
docker-compose logs -f php-fpm

# MySQL
docker-compose logs -f mysql

# All
docker-compose logs -f
```

### Container Stats
```bash
docker stats
```

### Resource Usage
```bash
docker ps --format "table {{.Names}}\t{{.MemUsage}}\t{{.CPUPerc}}"
```

## Rollback Plan

If issues occur:
```bash
# Stop all containers
docker-compose down

# Restore system services
sudo systemctl start nginx php7.1-fpm

# Keep Docker volumes intact for testing
docker volume ls | grep ritchie
```

## Next Steps

1. ✅ Deploy Docker Compose stack
2. ✅ Test all websites thoroughly
3. ✅ Setup automated backups
4. ✅ Configure monitoring/alerts
5. ✅ Document custom configurations
6. ✅ Plan security updates (PHP 7.1 → 8.x migration)
