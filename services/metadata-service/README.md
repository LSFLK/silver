# Silver Metadata Service

A Go service that sends ClamAV signature heartbeat data to the Super Platform.

## What It Does

- Monitors ClamAV signature database (`daily.cvd/cld`)
- Automatically detects server IP address
- Sends heartbeat data every 60 seconds (configurable)
- Receives results from Super Platform

## Quick Start

### 1. Configure

Edit `.env` file:
```bash
EXTERNAL_API_URL=https://your-super-platform.com/v1/silver/events
API_KEY=your-secret-api-key-here
PUSH_INTERVAL_SECONDS=60
```

### 2. Deploy

```bash
docker-compose up -d metadata-service
```

### 3. Check Logs

```bash
docker-compose logs -f metadata-service
```

You should see:
```
Instance ID: 192.168.1.100
Sending heartbeat: {"timestamp":"2026-03-05T10:30:00Z","instance_id":"192.168.1.100"...}
Successfully pushed heartbeat to Super Platform (status: 200)
```

## Heartbeat Payload

The service sends this JSON every 60 seconds:

```json
{
  "timestamp": "2026-03-05T10:31:00Z",
  "instance_id": "192.168.1.100",
  "signature_version": "daily.cvd:27930",
  "signature_updated_at": "2026-03-04T08:55:00Z"
}
```

**Fields:**
- `timestamp` - Current time (UTC)
- `instance_id` - Server IP address (auto-detected)
- `signature_version` - ClamAV database version
- `signature_updated_at` - When signature was last updated

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `EXTERNAL_API_URL` | Yes | - | Super Platform endpoint URL |
| `API_KEY` | Yes* | - | API key for authentication |
| `PUSH_INTERVAL_SECONDS` | No | 60 | Heartbeat frequency |
| `ENABLE_PUSH_SERVICE` | No | true | Enable/disable heartbeat |
| `PORT` | No | 8888 | Service port |
| `CLAMAV_DB_PATH` | No | /var/lib/clamav | ClamAV database location |

*Required for receiving results from Super Platform

## API Endpoints

### GET /health

Health check (no authentication required)

```bash
curl http://localhost:8888/health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2026-03-05T10:30:00Z"
}
```

### POST /api/results

Receive results from Super Platform (requires API key)

```bash
curl -X POST http://localhost:8888/api/results \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-secret-api-key-here" \
  -d '{
    "status": "success",
    "timestamp": "2026-03-05T10:30:00Z",
    "data": {}
  }'
```

## Build & Run

### Using Docker
```bash
docker-compose up -d metadata-service
```

### Using Makefile
```bash
make build    # Build binary
make run      # Run locally
make clean    # Clean up
```

### Manual Build
```bash
go build -o metadata-service main.go
./metadata-service
```

## Troubleshooting

**No heartbeats being sent?**
1. Check `EXTERNAL_API_URL` is set correctly
2. Verify `ENABLE_PUSH_SERVICE=true`
3. Check logs: `docker-compose logs metadata-service`

**Instance ID showing "unknown"?**
- Network connectivity issue
- Check logs for "Warning: could not determine server IP"

**ClamAV signature version is 0?**
1. Verify `/var/lib/clamav/daily.cvd` exists
2. Check ClamAV container is running
3. Wait for ClamAV to download signatures

**Authentication errors?**
- Verify `API_KEY` matches between client and server
- Include `X-API-Key` header in requests

## More Information

- [API Authentication Guide](./API_AUTHENTICATION.md)
- [Super Platform Integration](./SUPER_PLATFORM_INTEGRATION.md)
- [Instance ID Changes](./INSTANCE_ID_CHANGE.md)
