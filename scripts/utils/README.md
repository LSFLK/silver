# Rspamd Worker Controller Configuration

## Setup Rspamd Web UI Password

### 1. Create `.env` file

```bash
cd services
cp .env.example .env
nano .env
```

Set your password:
```bash
RSPAMD_PASSWORD=your_secure_password
```

### 2. Run the script

```bash
cd scripts/utils
./generate-rspamd-worker-controller.sh
```

This will:
- Generate password hash
- Create `worker-controller.inc` config
- Restart Rspamd container

### 3. Access

**Rspamd Web UI:**
- URL: http://YOUR_SERVER_IP:11334
- Password: `your_secure_password` (from .env)

**Prometheus Metrics:**
- URL: http://YOUR_SERVER_IP:11334/metrics
- No password required (public access)

## Configuration Details

The generated config allows:

✅ **Metrics endpoint** (`/metrics`) - No password required
- Accessible from anywhere for Prometheus scraping

✅ **Web UI** - Password required
- Requires `RSPAMD_PASSWORD` for access
- Protected endpoints: `/index.html`, `/graph`, API calls

## Security

The `secure_ip = ["0.0.0.0/0"]` allows all IPs to access `/metrics` without password.

To restrict metrics access to specific IPs:

Edit `services/silver-config/rspamd/worker-controller.inc`:
```
secure_ip = ["YOUR_PROMETHEUS_IP/32", "127.0.0.1"];
```

Then restart: `docker-compose restart rspamd-server`
