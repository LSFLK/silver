# Socketmap Service - Postfix Virtual Mailbox Maps

A Go-based socketmap service for Postfix virtual mailbox maps integrated with Thunder IDP.

## What It Does

This service implements the Postfix socketmap protocol to provide dynamic virtual mailbox maps backed by the Thunder Identity Provider (IDP). It validates users, domains, and aliases in real-time by querying Thunder's organization units and user database.

**Key Features:**
- ✅ Real-time user validation via Thunder IDP
- ✅ Domain validation via Thunder organization units
- ✅ Alias resolution support
- ✅ Thread-safe caching with configurable TTL
- ✅ Automatic Thunder authentication and token refresh
- ✅ Netstring protocol implementation
- ✅ Production-ready modular architecture

**Important:** This service uses the **netstring protocol** as required by Postfix socketmap. Netstring format: `<length>:<data>,`

Example:
- Request: `18:user-exists user@domain.com,`
- Response: `23:OK user@domain.com,`

## Deployment Options

### Option 1: Docker Compose (Recommended for Production)

The service is integrated into the Silver mail server stack. See [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) for details.

```bash
# From services directory
docker-compose up -d socketmap-server

# View logs
docker-compose logs -f socketmap-server
```

### Option 2: Standalone (Development/Testing)

Run the service locally for development and testing.

## Quick Start (Standalone)

### 1. Build and Run

```bash
cd services/socketmap
go build -o socketmap
./socketmap
```

You should see:
```
2026/02/27 10:00:00 Starting socketmap service on 127.0.0.1:9100
2026/02/27 10:00:00 ✓ Socketmap service listening on 127.0.0.1:9100
2026/02/27 10:00:00 Ready to accept connections from Postfix
```

### 2. Test Manually

Open another terminal and use the test script:

```bash
# Test user validation (requires Thunder IDP running)
printf "18:user-exists admin@openmail.lk,\n" | nc 127.0.0.1 9100

# Test domain validation
printf "24:virtual-domains openmail.lk,\n" | nc 127.0.0.1 9100

# Test alias resolution
printf "33:virtual-aliases postmaster@openmail.lk,\n" | nc 127.0.0.1 9100
```

**Note:** The service validates against Thunder IDP, so ensure Thunder is running and accessible.

### 3. Configure Postfix

Add to `/etc/postfix/main.cf`:

```
# Domain ownership - use socketmap for dynamic domain validation
virtual_mailbox_domains = socketmap:inet:127.0.0.1:9100:virtual-domains

# User validation - use socketmap for dynamic user validation
virtual_mailbox_maps = socketmap:inet:127.0.0.1:9100:user-exists

# Alias resolution - use socketmap for dynamic alias resolution
virtual_alias_maps = socketmap:inet:127.0.0.1:9100:virtual-aliases

# Your virtual transport
virtual_transport = lmtp:inet:mailstore:24
```

Reload Postfix:
```bash
postfix reload
```

### 4. Test with Postfix

```bash
# Test user validation
postmap -q "admin@openmail.lk" socketmap:inet:127.0.0.1:9100:user-exists

# Test domain validation
postmap -q "openmail.lk" socketmap:inet:127.0.0.1:9100:virtual-domains

# Test alias resolution
postmap -q "postmaster@openmail.lk" socketmap:inet:127.0.0.1:9100:virtual-aliases

# Test SMTP flow
telnet localhost 25
> EHLO test
> MAIL FROM:<sender@test.com>
> RCPT TO:<admin@openmail.lk>
```

## Configuration

The service is configured via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SOCKETMAP_HOST` | `127.0.0.1` | Bind address |
| `SOCKETMAP_PORT` | `9100` | Bind port |
| `THUNDER_HOST` | `thunder-server` | Thunder IDP hostname |
| `THUNDER_PORT` | `8090` | Thunder IDP port |
| `CACHE_TTL_SECONDS` | `300` | Cache TTL (5 minutes) |
| `TOKEN_REFRESH_SECONDS` | `3300` | Token refresh interval (55 minutes) |
| `THUNDER_SAMPLE_APP_ID` | (auto-detect) | Thunder application ID |

Example Docker Compose configuration:
```yaml
socketmap-server:
  environment:
    - SOCKETMAP_HOST=0.0.0.0
    - SOCKETMAP_PORT=9100
    - THUNDER_HOST=thunder-server
    - THUNDER_PORT=8090
    - CACHE_TTL_SECONDS=300
    - TOKEN_REFRESH_SECONDS=3300
```

## Supported Maps

### 1. user-exists (Virtual Mailbox Maps)
Validates if a user exists in Thunder IDP.

**Input:** `user-exists user@domain.com`
**Output:** 
- `OK user@domain.com` - User exists
- `NOTFOUND` - User doesn't exist

**Caching:** Only positive results (user exists) are cached for 5 minutes.

### 2. virtual-domains (Domain Validation)
Validates if a domain exists as a Thunder organization unit.

**Input:** `virtual-domains domain.com`
**Output:** 
- `OK 1` - Domain exists
- `NOTFOUND` - Domain doesn't exist

**Caching:** Only positive results (domain exists) are cached for 5 minutes.

### 3. virtual-aliases (Alias Resolution)
Resolves email aliases.

**Input:** `virtual-aliases alias@domain.com`
**Output:** 
- `OK target@domain.com` - Alias resolved
- `NOTFOUND` - No alias found

**Current Implementation:** Test implementation supporting `postmaster@domain` → `admin@domain`

**Caching:** Both positive and negative results cached for 5 minutes.

## Logs

The service provides detailed logging with visual hierarchy:

```
╔════════════════════════════════════════════════════════════╗
║       Socketmap Service - Postfix Virtual Mailbox Maps    ║
╚════════════════════════════════════════════════════════════╝

┌─ Thunder Authentication ─────────
│ Using Sample App ID from environment variable
│ Sample App ID: 019cd1e1-a123-73e7-9ce8-98ea46c9a640
│ Starting authentication flow...
│ ✓ Flow started (ID: ...)
│ Completing authentication...
│ ✓ Authentication successful
└───────────────────────────────────

Starting socketmap service on 0.0.0.0:9100
Configuration:
  • Thunder Host: thunder-server:8090
  • Cache TTL: 300 seconds
  • Token Refresh: 3300 seconds

✓ Socketmap service listening on 0.0.0.0:9100
Ready to accept connections from Postfix

╔════════════════════════════════════════════════╗
║ New connection from 172.18.0.5:45678
╚════════════════════════════════════════════════╝
  Connection established, using netstring protocol...
  Waiting to read netstring from connection...
← Received netstring: "user-exists admin@openmail.lk" (length: 31)
  Processing request: "user-exists admin@openmail.lk"
  ┌─ Processing Request ─────────────────
  │ Raw input: "user-exists admin@openmail.lk"
  │ Split into 2 parts: [user-exists admin@openmail.lk]
  │ Map:     "user-exists"
  │ Key:     "admin@openmail.lk"
  │ Checking if user exists...
    ┌─ User Lookup ───────────────────
    │ Email: admin@openmail.lk
    │ ✗ CACHE MISS
    │ Querying IDP...
      ┌─ Thunder User Validation ─────
      │ Email: admin@openmail.lk
      │ Username: admin
      │ Domain: openmail.lk
      │ OU ID: 019cd1e1-...
      │ Query: https://thunder-server:8090/users?filter=...
      │ Total results: 1
      │ Found user ID: 019cd1e1-...
      │ User OU: 019cd1e1-...
      │ ✓ User found and OU matches!
      └──────────────────────────────
    │ IDP result: exists=true
    │ ✓ Cached positive result for 300 seconds
    └─────────────────────────────────
  │ ✓ USER FOUND: admin@openmail.lk
  │ Response: OK admin@openmail.lk
  └─────────────────────────────────────
→ Preparing response: "OK admin@openmail.lk"
  Successfully sent netstring response (length: 23)
```

## Architecture

For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).

**High-level flow:**
```
SMTP Client
    ↓
Postfix (RCPT TO)
    ↓
virtual_mailbox_maps lookup
    ↓
Socketmap (0.0.0.0:9100) - Netstring Protocol
    ↓
Cache Check (5min TTL)
    ├─ HIT → Return cached result
    └─ MISS → Query Thunder IDP
               ↓
         Thunder API (HTTPS)
               ↓
         Validate User/Domain
               ↓
         Cache Result (if positive)
               ↓
         Return OK/NOTFOUND
    ↓
250 OK / 550 User unknown
```

**Project Structure:**
```
socketmap/
├── main.go                    # Entry point
├── config/                    # Configuration
├── internal/
│   ├── cache/                 # Caching layer
│   ├── protocol/              # Netstring protocol
│   ├── thunder/               # Thunder IDP integration
│   ├── handler/               # Business logic
│   └── server/                # TCP server
└── [Documentation]
```

See [INDEX.md](INDEX.md) for complete documentation guide.

## Troubleshooting

### Docker Build Fails
```bash
# Ensure all source files are present
ls -la config/ internal/

# Check go.mod module name
cat go.mod  # Should be: module socketmap

# Rebuild without cache
docker compose build --no-cache socketmap-server
```

### Service Not Starting
```bash
# Check if port is already in use
lsof -i :9100

# Check Thunder connectivity
curl -k https://thunder-server:8090/health

# Check environment variables
docker compose config | grep socketmap -A 20
```

### Thunder Authentication Fails
```bash
# Check Thunder is running
docker ps | grep thunder

# Check Thunder logs
docker logs thunder-server

# Verify Sample App ID
docker logs thunder-setup 2>&1 | grep "Sample App ID"

# Set manually if needed
export THUNDER_SAMPLE_APP_ID="your-app-id-here"
```

### Postfix Not Connecting
```bash
# Check Postfix logs
tail -f /var/log/mail.log

# Test connectivity
telnet 127.0.0.1 9100

# Verify Postfix config
postconf virtual_mailbox_maps
postconf virtual_mailbox_domains
```

### Cache Issues
```bash
# Cache is working if you see:
# "✓ CACHE HIT (fresh)" in logs

# To clear cache, restart the service:
docker compose restart socketmap-server
```

## Performance

- **Cache TTL:** 300 seconds (5 minutes)
- **Token Refresh:** 3300 seconds (55 minutes)
- **Connection timeout:** 30 seconds
- **Write timeout:** 5 seconds
- **Concurrent connections:** Handled efficiently via goroutines
- **Cache Strategy:** Only positive results cached (ensures new users are immediately accessible)

## Documentation

- **[INDEX.md](INDEX.md)** - Documentation navigation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture
- **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - Refactoring details
- **[VISUAL_COMPARISON.md](VISUAL_COMPARISON.md)** - Structure comparison

## Development

```bash
# Build locally
go build -o socketmap

# Run locally
./socketmap

# Run tests (when implemented)
go test ./...

# Format code
go fmt ./...

# Vet code
go vet ./...
```
