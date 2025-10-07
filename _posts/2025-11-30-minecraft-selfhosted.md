---
title: "Self-Hosting Minecraft Server: From Bare Metal to Kubernetes"
date: 2025-11-30 10:00:00 +0300
categories: [infrastructure, gaming]
description: "Complete guide to self-hosting Minecraft servers in 2025. Learn how to deploy on bare metal, Docker, and Kubernetes with performance optimization, backups, and security best practices. From my experience running multiplayer servers for years."
draft: true
image:
  path: /assets/img/posts/minecraft-selfhost-guide.webp
  alt: Self-Hosting Minecraft Server Guide - Bare Metal to Kubernetes
---

I've been hosting Minecraft servers since I was around 11-12 years old, back in 2008-2009. It started as a way to play with friends and turned into one of my first real experiences with Linux server administration. Over the years, I've run Minecraft servers on everything from my parents' old desktop to enterprise Kubernetes clusters. Today, I'm sharing everything I've learned about self-hosting Minecraft the right way.

## Why Self-Host Your Minecraft Server?

Before we dive into the technical details, let me be clear about why you'd want to self-host instead of using a hosting provider.

### The Real Benefits

**Complete Control**
When you host your own server, you control everything - the mods, plugins, settings, backups, and most importantly, your data. No hosting company can suddenly change their terms or shut down your server.

**Cost Effective (Eventually)**
A $5/month VPS or your home server can run a Minecraft server for 5-10 players easily. Compare that to $15-30/month for managed hosting. If you already have hardware running, the marginal cost is basically zero.

**Learning Experience**
This is huge. Managing a Minecraft server taught me Linux administration, networking, automation, and troubleshooting - skills that directly translated into my IT career. It's one of the best ways to learn server management while having fun.

**Performance You Control**
You can optimize exactly how you want. More RAM for your server? Done. Want to run on NVMe storage for faster chunk loading? Easy. With managed hosting, you're stuck with their configuration.

### The Honest Challenges

**You're Responsible for Everything**
When the server goes down at 2 AM, you're the one fixing it. No support tickets, no one to blame. This is both scary and empowering.

**Network Complexity**
Port forwarding, DNS, DDoS protection - you'll need to handle all of this. It's not rocket science, but it requires learning.

**Maintenance Burden**
Updates, backups, security patches - these are your responsibility. Automation helps, but you need to set it up first.

**Initial Time Investment**
The first setup will take time. But once it's done and automated, maintenance becomes minimal.

## Choosing Your Hosting Approach

Based on my experience running servers in various configurations, here's how to choose the right approach.

### Bare Metal (Direct Installation)

**Best for:** Learning, small private servers, when you have dedicated hardware

This is where I started. You install Minecraft server directly on a Linux machine. It's the simplest approach and gives you direct access to everything.

**Pros:**
- Straightforward setup
- Direct access to all resources
- Easy to troubleshoot
- No containerization overhead

**Cons:**
- Hard to replicate on other machines
- Manual dependency management
- Difficult to run multiple server versions
- No easy isolation between servers

### Docker

**Best for:** Running multiple servers, easy deployment, version management

Docker changed how I run Minecraft servers. Containerization makes everything cleaner and more reproducible.

**Pros:**
- Easy to deploy and update
- Can run multiple server versions simultaneously
- Environment consistency
- Simple backups with volume management
- Popular community images available

**Cons:**
- Slight performance overhead (minimal)
- Requires understanding Docker basics
- Network configuration can be tricky at first

### Kubernetes

**Best for:** High availability, auto-scaling, professional/large deployments

This is how I currently run my production Minecraft servers. It's overkill for most people, but if you want to learn Kubernetes or need advanced features, it's incredible.

**Pros:**
- Auto-scaling based on player count
- High availability with automatic failover
- Professional-grade monitoring and logging
- Easy to manage multiple servers
- Infrastructure as code

**Cons:**
- Complex initial setup
- Requires Kubernetes knowledge
- Overkill for casual servers
- More resource overhead

## Method 1: Bare Metal Installation

Let's start with the basics. This is the foundation that helped me understand how Minecraft servers actually work.

### Prerequisites

- Ubuntu 22.04 or 24.04 LTS (my preference)
- At least 2GB RAM (4GB+ recommended)
- 10GB free disk space minimum
- Java 21 (for Minecraft 1.20.5+)

### Step 1: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Java 21 (required for modern Minecraft)
sudo apt install openjdk-21-jdk-headless -y

# Verify Java installation
java -version

# Create minecraft user (security best practice)
sudo useradd -r -m -U -d /opt/minecraft -s /bin/bash minecraft
```

Why a separate user? Never run game servers as root. This limits potential damage if the server is compromised.

### Step 2: Download and Configure Server

```bash
# Switch to minecraft user
sudo su - minecraft

# Create server directory
mkdir -p ~/server
cd ~/server

# Download server jar (Paper for better performance)
wget https://api.papermc.io/v2/projects/paper/versions/1.20.6/builds/147/downloads/paper-1.20.6-147.jar -O server.jar

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash
java -Xms2G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions \
  -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \
  -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 \
  -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 \
  -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \
  -XX:InitiatingHeapOccupancyPercent=15 \
  -XX:G1MixedGCLiveThresholdPercent=90 \
  -XX:G1RSetUpdatingPauseTimePercent=5 \
  -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem \
  -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs \
  -Daikars.new.flags=true \
  -jar server.jar --nogui
EOF

chmod +x start.sh

# First run to generate files
./start.sh
```

The server will stop after generating `eula.txt`. This is expected.

### Step 3: Accept EULA and Configure

```bash
# Accept EULA
echo "eula=true" > eula.txt

# Configure server properties
nano server.properties
```

Essential settings to change:

```properties
# Basic Settings
server-port=25565
max-players=20
difficulty=normal
gamemode=survival
enable-command-block=false

# Performance
view-distance=10
simulation-distance=10
max-tick-time=60000

# Security
online-mode=true
enable-rcon=false
white-list=false

# World Settings
level-name=world
spawn-protection=16
```

### Step 4: Create Systemd Service

Exit back to your regular user and create a service file:

```bash
sudo nano /etc/systemd/system/minecraft.service
```

```ini
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=minecraft
Nice=1
KillMode=none
SuccessExitStatus=0 1
ProtectHome=true
ProtectSystem=full
PrivateDevices=true
NoNewPrivileges=true
WorkingDirectory=/opt/minecraft/server
ExecStart=/opt/minecraft/server/start.sh
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff "say Server shutting down in 10 seconds..."\015'
ExecStop=/bin/sleep 10
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff "stop"\015'

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl enable minecraft
sudo systemctl start minecraft

# Check status
sudo systemctl status minecraft

# View logs
sudo journalctl -u minecraft -f
```

### Step 5: Port Forwarding and Firewall

```bash
# Open firewall port
sudo ufw allow 25565/tcp

# For port forwarding, you need to:
# 1. Find your server's local IP: ip addr show
# 2. Access your router admin panel
# 3. Forward external port 25565 to your server's IP:25565
```

## Method 2: Docker Deployment

This is my preferred method for most use cases. Docker makes everything cleaner and more manageable.

### Prerequisites

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo apt install docker-compose-plugin -y
```

### Docker Compose Setup

Create a project directory:

```bash
mkdir -p ~/minecraft-server
cd ~/minecraft-server
```

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  minecraft:
    image: itzg/minecraft-server:java21
    container_name: minecraft-server
    restart: unless-stopped
    ports:
      - "25565:25565"
    environment:
      EULA: "TRUE"
      TYPE: "PAPER"
      VERSION: "1.20.6"
      MEMORY: "4G"
      
      # Server Settings
      SERVER_NAME: "My Minecraft Server"
      DIFFICULTY: "normal"
      MAX_PLAYERS: "20"
      VIEW_DISTANCE: "10"
      SIMULATION_DISTANCE: "10"
      
      # Performance
      USE_AIKAR_FLAGS: "true"
      
      # Timezone
      TZ: "Europe/Bucharest"
      
      # Plugins (optional)
      SPIGET_RESOURCES: "8631,9089"  # EssentialsX, LuckPerms
      
    volumes:
      - ./data:/data
      - ./plugins:/plugins
      - ./mods:/mods
    networks:
      - minecraft-net
    
    # Resource limits (optional but recommended)
    deploy:
      resources:
        limits:
          memory: 5G
        reservations:
          memory: 2G

  # Optional: Backup service
  backup:
    image: itzg/mc-backup
    container_name: minecraft-backup
    restart: unless-stopped
    environment:
      BACKUP_INTERVAL: "6h"
      PRUNE_BACKUPS_DAYS: "7"
      RCON_HOST: minecraft
      RCON_PASSWORD: "your-rcon-password"
    volumes:
      - ./data:/data:ro
      - ./backups:/backups
    networks:
      - minecraft-net
    depends_on:
      - minecraft

  # Optional: Web map with BlueMap
  bluemap:
    image: ghcr.io/bluemap-minecraft/bluemap:latest
    container_name: minecraft-bluemap
    restart: unless-stopped
    ports:
      - "8100:8100"
    volumes:
      - ./data:/data:ro
      - ./bluemap-web:/web
      - ./bluemap-config:/config
    networks:
      - minecraft-net
    depends_on:
      - minecraft

networks:
  minecraft-net:
    driver: bridge

volumes:
  data:
  backups:
  plugins:
  mods:
```

### Start the Server

```bash
# Start server
docker compose up -d

# View logs
docker compose logs -f minecraft

# Stop server
docker compose down

# Update server
docker compose pull
docker compose up -d

# Access server console
docker exec -i minecraft rcon-cli
```

### Managing Plugins

```bash
# Add plugins manually
cd ~/minecraft-server/plugins
wget https://github.com/EssentialsX/Essentials/releases/download/2.20.1/EssentialsX-2.20.1.jar

# Restart server to load plugins
docker compose restart minecraft
```

### Docker Advantages in Practice

What I love about this setup:

1. **Easy Updates:** `docker compose pull && docker compose up -d`
2. **Multiple Versions:** Run 1.16, 1.19, and 1.20 servers simultaneously
3. **Isolated Environments:** Each server has its own dependencies
4. **Simple Backups:** Just backup the `data` directory
5. **Reproducible:** Same `docker-compose.yml` works everywhere

## Method 3: Kubernetes Deployment

This is how I currently run my production servers. It's definitely overkill for most people, but if you want to learn Kubernetes or need enterprise features, here's the real-world implementation.

### Prerequisites

- Running Kubernetes cluster (I use k3s for simplicity)
- kubectl configured
- Basic understanding of Kubernetes concepts
- Persistent storage solution (I use Longhorn)

### Why Kubernetes for Minecraft?

Before the manifests, let me explain why this isn't completely crazy:

- **Auto-healing:** Server crashes? Kubernetes restarts it automatically
- **Resource Management:** Prevent one server from consuming all resources
- **Easy Scaling:** Run multiple worlds/servers with minimal overhead
- **Professional Monitoring:** Prometheus, Grafana, logging - all integrated
- **Infrastructure as Code:** Entire setup version controlled

### Kubernetes Manifests

Create `minecraft-namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: minecraft
```

Create `minecraft-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minecraft-data
  namespace: minecraft
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn  # or your storage class
  resources:
    requests:
      storage: 20Gi
```

Create `minecraft-configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: minecraft-config
  namespace: minecraft
data:
  EULA: "TRUE"
  TYPE: "PAPER"
  VERSION: "1.20.6"
  MEMORY: "4G"
  DIFFICULTY: "normal"
  MAX_PLAYERS: "20"
  VIEW_DISTANCE: "10"
  SIMULATION_DISTANCE: "10"
  USE_AIKAR_FLAGS: "true"
  ENABLE_RCON: "true"
```

Create `minecraft-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minecraft-secret
  namespace: minecraft
type: Opaque
stringData:
  RCON_PASSWORD: "your-secure-rcon-password-here"
```

Create `minecraft-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minecraft-server
  namespace: minecraft
  labels:
    app: minecraft
spec:
  replicas: 1
  strategy:
    type: Recreate  # Important: Minecraft can't run multiple replicas
  selector:
    matchLabels:
      app: minecraft
  template:
    metadata:
      labels:
        app: minecraft
    spec:
      containers:
      - name: minecraft
        image: itzg/minecraft-server:java21
        ports:
        - containerPort: 25565
          name: minecraft
          protocol: TCP
        - containerPort: 25575
          name: rcon
          protocol: TCP
        envFrom:
        - configMapRef:
            name: minecraft-config
        - secretRef:
            name: minecraft-secret
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "5Gi"
            cpu: "2000m"
        livenessProbe:
          exec:
            command:
            - mc-health
          initialDelaySeconds: 120
          periodSeconds: 60
        readinessProbe:
          exec:
            command:
            - mc-health
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minecraft-data
```

Create `minecraft-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: minecraft-service
  namespace: minecraft
spec:
  type: LoadBalancer  # or NodePort for home setups
  selector:
    app: minecraft
  ports:
  - name: minecraft
    port: 25565
    targetPort: 25565
    protocol: TCP
  - name: rcon
    port: 25575
    targetPort: 25575
    protocol: TCP
```

### Deploy to Kubernetes

```bash
# Apply all manifests
kubectl apply -f minecraft-namespace.yaml
kubectl apply -f minecraft-pvc.yaml
kubectl apply -f minecraft-configmap.yaml
kubectl apply -f minecraft-secret.yaml
kubectl apply -f minecraft-deployment.yaml
kubectl apply -f minecraft-service.yaml

# Watch deployment
kubectl get pods -n minecraft -w

# View logs
kubectl logs -n minecraft -l app=minecraft -f

# Get service IP
kubectl get svc -n minecraft

# Access RCON console
kubectl exec -it -n minecraft deployment/minecraft-server -- rcon-cli
```

### Kubernetes Monitoring

Create `minecraft-servicemonitor.yaml` (if using Prometheus):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: minecraft-metrics
  namespace: minecraft
spec:
  selector:
    matchLabels:
      app: minecraft
  endpoints:
  - port: metrics
    interval: 30s
```

### Backup CronJob

Create `minecraft-backup-cronjob.yaml`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: minecraft-backup
  namespace: minecraft
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: itzg/mc-backup
            env:
            - name: BACKUP_METHOD
              value: "tar"
            - name: DEST_DIR
              value: "/backups"
            - name: BACKUP_NAME
              value: "minecraft-backup"
            - name: PRUNE_BACKUPS_DAYS
              value: "7"
            volumeMounts:
            - name: data
              mountPath: /data
              readOnly: true
            - name: backups
              mountPath: /backups
          restartPolicy: OnFailure
          volumes:
          - name: data
            persistentVolumeClaim:
              claimName: minecraft-data
          - name: backups
            persistentVolumeClaim:
              claimName: minecraft-backups
```

## Performance Optimization

Regardless of your deployment method, here are the optimizations I've learned over years of hosting.

### JVM Flags (Aikar's Flags)

These are included in the start scripts above, but here's why they matter:

```bash
-XX:+UseG1GC                    # Use G1 garbage collector
-XX:+ParallelRefProcEnabled     # Parallel reference processing
-XX:MaxGCPauseMillis=200        # Target max GC pause
-XX:G1HeapRegionSize=8M         # Heap region size
```

These flags reduced my server lag spikes by about 70%.

### Server Properties Tuning

```properties
# Reduce view distance for better performance
view-distance=8
simulation-distance=6

# Entity limits per chunk
spawn-limits.monsters=50
spawn-limits.animals=10
spawn-limits.water-animals=5
spawn-limits.ambient=15

# Network compression
network-compression-threshold=256
```

### Paper/Spigot Optimizations

Edit `paper-global.yml`:

```yaml
chunk-loading-advanced:
  auto-config-send-distance: true
  player-max-concurrent-chunk-loads: 4.0

packet-limiter:
  kick-message: '&cSent too many packets'
  limits:
    all:
      interval: 7.0
      max-packet-rate: 500.0

unsupported-settings:
  allow-piston-duplication: false
  allow-permanent-block-break-exploits: false
```

### Linux System Tuning

```bash
# Increase file descriptor limits
echo "minecraft soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "minecraft hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# TCP tuning for better network performance
cat << 'EOF' | sudo tee -a /etc/sysctl.conf
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
EOF

sudo sysctl -p
```

## Backup Strategies

Losing your world is heartbreaking. Trust me, I've been there. Here's how to prevent it.

### Automated Backups Script

```bash
#!/bin/bash
# minecraft-backup.sh

BACKUP_DIR="/opt/backups/minecraft"
SERVER_DIR="/opt/minecraft/server"
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create timestamped backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/minecraft_backup_$TIMESTAMP.tar.gz"

# Announce backup
screen -S minecraft -p 0 -X stuff "say Backup starting in 10 seconds...$(printf \\r)"
sleep 10

# Disable auto-save
screen -S minecraft -p 0 -X stuff "save-off$(printf \\r)"
screen -S minecraft -p 0 -X stuff "save-all$(printf \\r)"
sleep 5

# Create backup
tar -czf "$BACKUP_FILE" -C "$SERVER_DIR" world world_nether world_the_end

# Re-enable auto-save
screen -S minecraft -p 0 -X stuff "save-on$(printf \\r)"

# Announce completion
screen -S minecraft -p 0 -X stuff "say Backup completed!$(printf \\r)"

# Remove old backups
find "$BACKUP_DIR" -name "minecraft_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

# Upload to S3 (optional)
# aws s3 cp "$BACKUP_FILE" s3://my-bucket/minecraft-backups/

echo "Backup completed: $BACKUP_FILE"
```

```bash
# Make executable
chmod +x minecraft-backup.sh

# Add to crontab (every 6 hours)
crontab -e
0 */6 * * * /opt/minecraft/minecraft-backup.sh >> /var/log/minecraft-backup.log 2>&1
```

### Restore from Backup

```bash
# Stop server
sudo systemctl stop minecraft  # or docker compose down

# Backup current world (just in case)
cd /opt/minecraft/server
tar -czf world_before_restore.tar.gz world world_nether world_the_end

# Remove current worlds
rm -rf world world_nether world_the_end

# Restore from backup
tar -xzf /opt/backups/minecraft/minecraft_backup_TIMESTAMP.tar.gz

# Start server
sudo systemctl start minecraft
```

## Security Best Practices

Running game servers exposed to the internet requires proper security.

### Firewall Configuration

```bash
# UFW (Ubuntu)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 25565/tcp   # Minecraft
sudo ufw enable

# firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=25565/tcp
sudo firewall-cmd --reload
```

### DDoS Protection with iptables

```bash
# Limit connections per IP
sudo iptables -A INPUT -p tcp --dport 25565 -m connlimit --connlimit-above 3 -j DROP

# Rate limiting
sudo iptables -A INPUT -p tcp --dport 25565 -m state --state NEW -m recent --set
sudo iptables -A INPUT -p tcp --dport 25565 -m state --state NEW -m recent --update --seconds 60 --hitcount 10 -j DROP
```

### Whitelist Mode (Recommended for Private Servers)

```bash
# In server console or RCON
whitelist on
whitelist add PlayerName
whitelist list
```

### Regular Updates

```bash
# Create update script
cat > update-server.sh << 'EOF'
#!/bin/bash
echo "Announcing server update..."
screen -S minecraft -p 0 -X stuff "say Server update in 5 minutes!$(printf \\r)"
sleep 240
screen -S minecraft -p 0 -X stuff "say Server update in 1 minute!$(printf \\r)"
sleep 60
screen -S minecraft -p 0 -X stuff "say Server restarting now!$(printf \\r)"
sleep 5

# Stop server
sudo systemctl stop minecraft

# Backup current version
cp server.jar server.jar.old

# Download new version
wget https://api.papermc.io/v2/projects/paper/versions/1.20.6/builds/latest/downloads/paper-1.20.6-latest.jar -O server.jar

# Start server
sudo systemctl start minecraft

echo "Update completed!"
EOF

chmod +x update-server.sh
```

## Monitoring and Maintenance

You need to know what's happening on your server.

### Log Analysis

```bash
# View latest logs
tail -f logs/latest.log

# Search for errors
grep -i error logs/latest.log

# Find player join/leave
grep -E "joined|left" logs/latest.log

# Count unique players today
grep "$(date +%Y-%m-%d)" logs/latest.log | grep -i "joined" | cut -d'[' -f3 | cut -d']' -f1 | sort -u | wc -l
```

### Performance Monitoring Script

```bash
#!/bin/bash
# minecraft-stats.sh

echo "=== Minecraft Server Statistics ==="
echo "Timestamp: $(date)"
echo ""

# Memory usage
echo "Memory Usage:"
ps aux | grep "[j]ava.*minecraft" | awk '{print "  RSS: " $6/1024 "MB, VSZ: " $5/1024 "MB"}'
echo ""

# CPU usage
echo "CPU Usage:"
ps aux | grep "[j]ava.*minecraft" | awk '{print "  CPU: " $3 "%"}'
echo ""

# Online players
echo "Online Players:"
PLAYERS=$(screen -S minecraft -p 0 -X stuff "list$(printf \\r)" 2>&1 | grep -oP '\d+(?= of)')
echo "  Count: ${PLAYERS:-Unknown}"
echo ""

# Disk usage
echo "Disk Usage:"
du -sh /opt/minecraft/server/world* | awk '{print "  " $1 " - " $2}'
echo ""

# Last backup
echo "Last Backup:"
ls -lh /opt/backups/minecraft/ | tail -1 | awk '{print "  " $9 " - " $5}'
```

### Grafana Dashboard (for Kubernetes)

If you're running on Kubernetes with Prometheus, here's a basic monitoring setup:

```yaml
# minecraft-exporter.yaml
apiVersion: v1
kind: Service
metadata:
  name: minecraft-exporter
  namespace: minecraft
  labels:
    app: minecraft-exporter
spec:
  ports:
  - port: 9225
    name: metrics
  selector:
    app: minecraft

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minecraft-exporter
  namespace: minecraft
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minecraft-exporter
  template:
    metadata:
      labels:
        app: minecraft-exporter
    spec:
      containers:
      - name: exporter
        image: sladkoff/minecraft-prometheus-exporter
        ports:
        - containerPort: 9225
        env:
        - name: MINECRAFT_SERVER_IP
          value: "minecraft-service"
        - name: MINECRAFT_SERVER_PORT
          value: "25565"
```

## Troubleshooting Common Issues

### Server Won't Start

```bash
# Check logs
docker logs minecraft-server  # Docker
kubectl logs -n minecraft -l app=minecraft  # Kubernetes
sudo journalctl -u minecraft -n 50  # Systemd

# Common issues:
# - EULA not accepted: echo "eula=true" > eula.txt
# - Java version mismatch: update-alternatives --config java
# - Port already in use: lsof -i :25565
# - Out of memory: increase -Xmx in start script
```

### Lag Issues

```bash
# Enable timings report
timings on
timings paste

# Check TPS (should be 20)
# In server console: /tps

# Identify laggy chunks
# Install LagGoggles plugin for detailed analysis

# Common fixes:
# - Reduce view distance
# - Clear unnecessary entities: /kill @e[type=item]
# - Limit mob farms
# - Use Paper optimizations
```

### Connection Issues

```bash
# Test if port is open
nc -zv your-ip 25565

# Check firewall
sudo ufw status
sudo iptables -L -n

# Verify server is listening
netstat -tulpn | grep 25565

# Check if you can connect locally
telnet localhost 25565
```

### World Corruption

```bash
# Stop server immediately
sudo systemctl stop minecraft

# Run region fixer
java -jar mcaselector-2.4.1.jar --select "xPos >= -10 AND xPos <= 10 AND zPos >= -10 AND zPos <= 10" --delete

# Restore from backup if needed
tar -xzf /opt/backups/minecraft/minecraft_backup_TIMESTAMP.tar.gz

# Restart server
sudo systemctl start minecraft
```

## Cost Analysis

Let me break down actual costs from my experience.

### Home Server

**Initial Investment:**
- Used PC: $200-400
- Power consumption: ~$10-15/month (varies by location)
- Internet: Usually no extra cost

**Annual Cost:** ~$120-180

**Pros:** Complete control, no recurring hosting fees
**Cons:** Single point of failure, internet upload speed limits

### VPS Hosting

**Budget Option (Hetzner, OVH):**
- 4GB RAM VPS: ~$5-8/month
- Annual Cost: ~$60-96

**Premium Option (DigitalOcean, Linode):**
- 4GB RAM: ~$18/month
- Annual Cost: ~$216

**Pros:** Reliable uptime, professional datacenter
**Cons:** Ongoing costs, resource limits

### Managed Minecraft Hosting

**Budget Hosts:**
- $5-10/month for 2GB
- Annual Cost: ~$60-120

**Premium Hosts:**
- $15-30/month for 4GB
- Annual Cost: ~$180-360

**Pros:** Zero technical knowledge needed, support available
**Cons:** Expensive, limited control, resource restrictions

### My Recommendation

For learning and small servers (5-10 players): Start with a cheap VPS or home server
For serious projects: Docker on a decent VPS
For enterprise/learning Kubernetes: Cloud Kubernetes cluster

## Plugin and Mod Recommendations

After managing servers for years, these are the plugins I always install.

### Essential Server Management

**EssentialsX** - The swiss army knife of Minecraft plugins
```bash
# Features: /home, /warp, /tpa, economy, kits
wget -O plugins/EssentialsX.jar https://github.com/EssentialsX/Essentials/releases/download/2.20.1/EssentialsX-2.20.1.jar
```

**LuckPerms** - Permission management done right
```bash
# Best permission plugin, period
wget -O plugins/LuckPerms.jar https://download.luckperms.net/1544/bukkit/loader/LuckPerms-Bukkit-5.4.102.jar
```

**CoreProtect** - Block logging and rollback
```bash
# Essential for grief protection
# Download from: https://www.spigotmc.org/resources/coreprotect.8631/
```

### Performance Plugins

**Spark** - Performance profiler
```bash
# Identify lag sources
wget -O plugins/spark.jar https://sparkapi.lucko.me/download/bukkit
```

**ClearLag** - Remove entities causing lag
```bash
# Configure carefully to not annoy players
# Download from SpigotMC
```

### Quality of Life

**DiscordSRV** - Bridge Minecraft chat with Discord
```yaml
# My config for DiscordSRV
# config.yml
BotToken: "YOUR_DISCORD_BOT_TOKEN"
Channels:
  global: "DISCORD_CHANNEL_ID"
```

**Dynmap** - Live web map of your world
```bash
# Shows player locations and world in browser
# Access at http://your-server:8123
```

### Anti-Grief and Moderation

**WorldGuard + WorldEdit** - Region protection
```bash
# Protect spawn, create safe zones
# Must-have for public servers
```

**LiteBans** - Advanced ban management
```bash
# History tracking, temp bans, IP bans
# Way better than vanilla banning
```

## Advanced Configurations

### Reverse Proxy with Nginx

For running multiple servers on one IP:

```nginx
# /etc/nginx/streams.conf
stream {
    upstream minecraft_vanilla {
        server 127.0.0.1:25565;
    }
    
    upstream minecraft_modded {
        server 127.0.0.1:25566;
    }
    
    map $ssl_preread_server_name $minecraft_backend {
        vanilla.yourdomain.com minecraft_vanilla;
        modded.yourdomain.com minecraft_modded;
        default minecraft_vanilla;
    }
    
    server {
        listen 25565;
        proxy_pass $minecraft_backend;
        ssl_preread on;
    }
}
```

### BungeeCord Setup (Network of Servers)

For running multiple worlds with shared playerbase:

```yaml
# BungeeCord config.yml
listeners:
- host: 0.0.0.0:25565
  motd: 'My Server Network'
  max_players: 100
  force_default_server: true
  forced_hosts:
    lobby.myserver.com: lobby
    survival.myserver.com: survival
    creative.myserver.com: creative

servers:
  lobby:
    address: localhost:25566
    restricted: false
  survival:
    address: localhost:25567
    restricted: false
  creative:
    address: localhost:25568
    restricted: false
```

### Velocity (Modern BungeeCord Alternative)

```toml
# velocity.toml
bind = "0.0.0.0:25565"
motd = "A Velocity Server"

[servers]
lobby = "localhost:25566"
survival = "localhost:25567"

try = [
  "lobby"
]

[forced-hosts]
"lobby.example.com" = [
  "lobby"
]
"survival.example.com" = [
  "survival"
]
```

## Real-World Examples

Let me share actual configurations from servers I've run.

### Small Private Server (5-10 Friends)

**Hardware:** Raspberry Pi 4 (8GB) or old desktop
**Setup:** Bare metal with Paper
**Specs:** 4GB allocated to Minecraft
**Cost:** Power only (~$5/month)
**Uptime:** 99%+ (occasionally restart for updates)

This worked perfectly for casual gameplay with friends. The key was using Paper for better performance and keeping plugins minimal.

### Medium Public Server (20-50 Players)

**Hardware:** Hetzner VPS (8GB RAM, 4 vCPU)
**Setup:** Docker with automated backups
**Specs:** 6GB to Minecraft, 2GB for system
**Cost:** $15/month
**Plugins:** ~15 plugins for gameplay and protection

Used Docker for easy management and updates. Automated daily backups to S3. This setup handled peak loads well with proper optimization.

### Large Modded Network (50-100 Players)

**Hardware:** Kubernetes cluster (3 nodes, 16GB each)
**Setup:** Multiple servers behind Velocity proxy
**Specs:** Dedicated pods for each world
**Cost:** $120/month (cloud hosting)
**Uptime:** 99.9% with auto-scaling

This was overkill but taught me a lot about Kubernetes. Auto-scaling worked beautifully during peak hours. Each server type (vanilla, modded, creative) ran in separate pods.

## Migration Strategies

### Moving from Managed Host to Self-Hosted

```bash
# 1. Download world from old host (usually via FTP)
# 2. Stop your self-hosted server
sudo systemctl stop minecraft

# 3. Copy world files
cd /opt/minecraft/server
rm -rf world world_nether world_the_end
scp -r user@oldhost:/path/to/world* .

# 4. Fix permissions
chown -R minecraft:minecraft world*

# 5. Start server
sudo systemctl start minecraft

# 6. Update DNS/IP for players
# 7. Monitor for 24-48 hours before canceling old host
```

### Moving from Bare Metal to Docker

```bash
# 1. Prepare docker-compose.yml (as shown above)

# 2. Stop bare metal server
sudo systemctl stop minecraft

# 3. Copy world to Docker volume location
mkdir -p ~/minecraft-server/data
cp -r /opt/minecraft/server/world* ~/minecraft-server/data/

# 4. Start Docker container
cd ~/minecraft-server
docker compose up -d

# 5. Test thoroughly
# 6. Disable systemd service
sudo systemctl disable minecraft
```

### Moving to Kubernetes

```bash
# 1. Create PVC and ensure it's available
kubectl get pvc -n minecraft

# 2. Copy world data to PVC
kubectl run -n minecraft tmp-pod --image=busybox --restart=Never -- sleep 3600
kubectl cp /opt/minecraft/server/world minecraft/tmp-pod:/data/
kubectl delete pod -n minecraft tmp-pod

# 3. Deploy Kubernetes manifests
kubectl apply -f minecraft/

# 4. Monitor deployment
kubectl get pods -n minecraft -w
```

## Community and Resources

### Where I Learned (and Still Learn)

**SpigotMC Forums** - Plugin development and server management
**r/admincraft** - Reddit community for server admins
**Paper Discord** - Best place for Paper-specific help
**Minecraft@Home** - Self-hosting community

### Useful Tools

**MCASelector** - World editor for fixing corrupted chunks
**NBTExplorer** - Edit player data and world files
**spark** - Performance profiling (better than Timings)
**Plan** - Analytics plugin for player activity

### Learning Resources

**Paper Documentation** - Well-written optimization guides
**Aikar's Flags** - JVM optimization explained
**Spigot Wiki** - Plugin configuration guides
**YouTube: BisectHosting** - Good tutorial content

## My Current Setup

Since people always ask, here's what I'm running now:

**Infrastructure:**
- k3s Kubernetes cluster (3 nodes)
- Longhorn for persistent storage
- Traefik for ingress
- Prometheus + Grafana monitoring

**Servers:**
- Vanilla survival (Paper 1.20.6)
- Creative plot world
- Event server (for special occasions)

**Players:** 15-30 regular players
**Uptime:** 99.8% over last 6 months
**Backups:** Every 6 hours to S3, 30-day retention

**Why Kubernetes?** Honestly, it's overkill. But I wanted to learn Kubernetes in a real scenario, and this has been perfect for that. Plus, the auto-healing and monitoring are genuinely useful.

## Final Thoughts

After hosting Minecraft servers for over 15 years, I can confidently say that self-hosting is one of the best ways to learn system administration. It's practical, it's fun, and when something breaks at 2 AM, you learn real troubleshooting skills.

Start simple. A bare metal installation teaches you the fundamentals. Once you're comfortable, Docker makes your life easier. And if you want to go deep, Kubernetes is waiting for you.

The mistakes I made early on - running servers as root, no backups, terrible security - are exactly the lessons that made me a better sysadmin. Don't be afraid to break things. Your friends might complain when the server goes down, but you'll learn more from that downtime than from weeks of smooth operation.

### Key Takeaways

- **Start Simple:** Bare metal or Docker, not Kubernetes
- **Backup Everything:** You will lose data otherwise, guaranteed
- **Optimize Early:** Use Paper, Aikar's flags, proper JVM settings
- **Monitor Actively:** Know what's happening before players complain
- **Secure Properly:** Firewall, whitelist, regular updates
- **Automate Ruthlessly:** Backups, updates, restarts - all automated

### What's Next?

I'm currently working on:
- GitOps pipeline for server configurations
- Better monitoring dashboards
- Automated testing for plugin updates
- Multi-region setup for lower latency

If you're starting your own server, I'd love to hear about it. Drop a comment with your setup, challenges, or questions. I try to help where I can because the community helped me get started years ago.

And remember - the best way to learn is by doing. Install that server, break it, fix it, and break it again. That's how you become good at this.

Now if you'll excuse me, I need to investigate why my survival world's TPS just dropped to 15. Some things never change.

---

**Resources and Downloads:**
- Paper: https://papermc.io/downloads
- itzg Docker Image: https://github.com/itzg/docker-minecraft-server
- My Kubernetes manifests: github.com/merox (when I clean them up and publish)
- SpigotMC: https://www.spigotmc.org/
- Minecraft Server Optimization Guide: https://github.com/YouHaveTrouble/minecraft-optimization

**Want More Infrastructure Content?**
Check out my other guides:
- [SSH Hardening for Production Servers](/posts/ssh-hardening-linux-servers/)
- [From Windows to Linux Transition Guide](/posts/windows-to-linux-transition-guide/)
- [SMB Authentication with Active Directory](/posts/smb-authentication-ad-linux/)
- [Dual Boot Windows 11 and Ubuntu](/posts/dual-boot-windows-11-ubuntu-25/)