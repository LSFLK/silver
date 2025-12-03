# Observability Stack

Monitor your mail server from your local machine using Prometheus + Grafana.

## Setup

### 1. Configure Environment

Edit `.env` file:

```bash
# Mail Server Configuration
MAIL_SERVER_IP=xx.xx.xxx.xxx          # Change to your server IP

# Grafana Configuration
GRAFANA_ADMIN_USER=admin               # Change admin username
GRAFANA_ADMIN_PASSWORD=admin           # ⚠️ Change this password!
GRAFANA_PORT=3000                      # Grafana port

# Prometheus Configuration
PROMETHEUS_PORT=9090                   # Prometheus port
PROMETHEUS_RETENTION_DAYS=30d          # Data retention period
PROMETHEUS_SCRAPE_INTERVAL=15s         # Metrics collection interval

# Exporter Ports (on mail server)
NODE_EXPORTER_PORT=9100
CADVISOR_PORT=8080
POSTFIX_EXPORTER_PORT=9154
CLAMAV_EXPORTER_PORT=9810
RSPAMD_METRICS_PORT=11334
```

### 2. Start Services

```bash
docker-compose up -d
```

### 3. Access Dashboards

- **Grafana**: http://localhost:3000 (username/password from `.env`)
- **Prometheus**: http://localhost:9090

## Server Setup

On your mail server, open firewall ports:

```bash
# Allow your local machine IP
sudo ufw allow from YOUR_LOCAL_IP

# Or allow specific ports
sudo ufw allow from YOUR_LOCAL_IP to any port 9100
sudo ufw allow from YOUR_LOCAL_IP to any port 8080
sudo ufw allow from YOUR_LOCAL_IP to any port 9154
sudo ufw allow from YOUR_LOCAL_IP to any port 9810
sudo ufw allow from YOUR_LOCAL_IP to any port 11334
```

## Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart

# View logs
docker compose logs -f

# Check status
docker compose ps
```

## Verify

1. Check Prometheus targets: http://localhost:9090/targets
   - All targets should show **UP** (green)

2. Open Grafana: http://localhost:3000
   - Go to **Dashboards** → **Browse** → **Mail Server**
   - All dashboards should show data

## Troubleshooting

**No data in Grafana?**
- Check Prometheus targets are UP
- Verify firewall on mail server
- Test connection: `curl http://YOUR_SERVER_IP:9100/metrics`

**Can't access Grafana?**
- Check if running: `docker compose ps`
- View logs: `docker compose logs grafana`

**Change configuration?**
- Edit `.env`
- Restart: `docker compose down && docker compose up -d`
