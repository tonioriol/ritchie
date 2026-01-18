# DigitalOcean Server Migration Guide

## Server Size Recommendation

For **smooth Acestream streaming + VPN + ritchie stack**, I recommend:

```bash
Size: s-2vcpu-4gb
Specs: 4GB RAM, 2 vCPUs, 80GB SSD
Price: $24/month
```

**Why this size:**
- ✅ **Acestream streaming**: 2 vCPUs handle video transcoding smoothly
- ✅ **VPN overhead**: Extra RAM for encryption/decryption
- ✅ **Headroom**: Can run all services simultaneously without swap
- ✅ **Cost-effective**: Only $24/mo for excellent performance

**Alternatives:**
- `s-2vcpu-2gb` ($18/mo) - Budget option, may struggle with multiple streams
- `s-4vcpu-8gb` ($48/mo) - Overkill for current needs

## Migration Plan

### Step 1: Create New DigitalOcean Server

```bash
# Create droplet
doctl compute droplet create ritchie-new \
  --size s-2vcpu-4gb \
  --image ubuntu-22-04-x64 \
  --region nyc3 \
  --ssh-keys $(doctl compute ssh-key list --format ID --no-header) \
  --enable-backups \
  --enable-monitoring \
  --tag-name ritchie
```

### Step 2: Install Docker & Dependencies

```bash
# SSH to new server
ssh root@<new-server-ip>

# Install Docker & Docker Compose
apt update && apt install -y docker.io docker-compose-plugin

# Add forge user to docker group
usermod -aG docker forge

# Install doctl (for future management)
wget https://github.com/digitalocean/doctl/releases/download/v1.99.0/doctl-1.99.0-linux-amd64.tar.gz
sudo tar xf doctl-1.99.0-linux-amd64.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/doctl
```

### Step 3: Deploy Docker Stack

```bash
# Copy ritchie-docker directory
scp -r /Users/tr0n/Code/ritchie/* forge@<new-server-ip>:/home/forge/ritchie-docker/

# SSH to server
ssh forge@<new-server-ip>
cd ~/ritchie-docker

# Setup environment
cp .env.example .env
nano .env  # Update passwords

# Start services
docker compose up -d
```

### Step 4: Migrate Data

```bash
# From old server, export databases
ssh forge@188.226.140.165 "mysqldump -u forge -p boira" > boira.sql
ssh forge@188.226.140.165 "mysqldump -u forge -p lodragonet" > lodragonet.sql

# Import to new server
docker exec ritchie-mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} boira < boira.sql
docker exec ritchie-mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} lodragonet < lodragonet.sql

# Copy website files
scp -r forge@188.226.140.165:/home/forge/{boira.band,lodrago.net,bertomeuiglesias.com} apps/
```

### Step 5: Test Everything

```bash
# Test services
curl -k https://boira.band
curl -k https://lodrago.net
curl -k https://bertomeuiglesias.com
curl -k https://ace.tonioriol.com

# Check logs
docker compose logs -f nginx
```

### Step 6: Update DNS (Final Step)

```bash
# Update DNS records to point to new server
# Example using doctl for DigitalOcean DNS
# doctl compute domain records update tonioriol.com <record-id> --record-data <new-ip>

# Or use your DNS provider's interface
```

### Step 7: Setup VPN

```bash
# Install WireGuard
docker run -d \
  --name=wireguard \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=UTC \
  -e SERVERURL=<your-domain> \
  -e SERVERPORT=51820 \
  -e PEERS=phone,laptop \
  -e PEERDNS=1.1.1.1 \
  -e INTERNAL_SUBNET=10.13.13.0 \
  -p 51820:51820/udp \
  -v /home/forge/wireguard:/config \
  -v /lib/modules:/lib/modules \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  linuxserver/wireguard
```

## Timeline

| Step | Duration | Notes |
|------|----------|-------|
| Create droplet | 2 min | Fastest region: nyc3
| Install Docker | 5 min | Automated script
| Deploy stack | 3 min | docker compose up -d
| Migrate data | 10 min | Database export/import
| Test | 15 min | Verify all sites work
| DNS update | 5 min | TTL-dependent propagation
| VPN setup | 5 min | WireGuard container
| **TOTAL** | **~45 min** | Can be done with zero downtime

## Zero Downtime Strategy

1. Deploy new server in parallel
2. Test everything thoroughly
3. Update DNS when ready
4. Keep old server running as fallback
5. Monitor traffic on new server
6. Shutdown old server after 24h

## Cost Savings

Current: Legacy Ubuntu 16.04 on unknown hardware
New: $24/month with modern infrastructure, better performance, and full containerization

## Next Steps

1. ✅ Create new DigitalOcean droplet
2. ✅ Deploy Docker stack
3. ✅ Migrate data
4. ✅ Test all services
5. ✅ Update DNS
6. ✅ Setup VPN
7. ✅ Monitor performance
8. ✅ Shutdown old server

Let me know when you're ready to start the migration!
