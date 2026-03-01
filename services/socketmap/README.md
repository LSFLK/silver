# Socketmap Service for Virtual Mailbox Maps

A simple Go socketmap service for testing Postfix `virtual_mailbox_maps` lookups.

## What It Does

This service implements the Postfix socketmap protocol to validate email addresses for virtual mailbox delivery. It replaces traditional file/SQL-based `virtual_mailbox_maps` lookups with a network service.

**Important:** This service uses the **netstring protocol** as required by Postfix socketmap. Netstring format: `<length>:<data>,`

Example:
- Request: `32:get user-exists test@example.com,`
- Response: `19:OK test@example.com,`

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

Open another terminal and test the protocol:

```bash
# Test an existing user
printf "get user-exists test@example.com\n" | nc 127.0.0.1 9100

# Test a non-existent user
printf "get user-exists unknown@example.com\n" | nc 127.0.0.1 9100

# Test invalid format
printf "invalid request\n" | nc 127.0.0.1 9100
```

### 3. Configure Postfix

Add to `/etc/postfix/main.cf`:

```
# Domain ownership (required)
virtual_mailbox_domains = example.com, test.com

# Replace traditional map with socketmap
virtual_mailbox_maps = socketmap:inet:127.0.0.1:9100:user-exists

# Your virtual transport
virtual_transport = lmtp:inet:mailstore:24
```

Reload Postfix:
```bash
postfix reload
```

### 4. Test with Postfix

```bash
# Test address validation
postmap -q "test@example.com" socketmap:inet:127.0.0.1:9100:user-exists

# Test SMTP flow
telnet localhost 25
> EHLO test
> MAIL FROM:<sender@test.com>
> RCPT TO:<test@example.com>
```

## Protocol Details

### Request Format
```
get <mapname> <key>\n
```

Example:
```
get user-exists user@example.com
```

### Response Format

| Response | Meaning | SMTP Result |
|----------|---------|-------------|
| `OK <value>` | User exists | RCPT accepted |
| `NOTFOUND` | User doesn't exist | 550 5.1.1 User unknown |
| `TEMP <reason>` | Temporary failure | 451 4.3.0 Try again later |
| `PERM <reason>` | Permanent error | 550 5.3.0 |

## Test Users

For testing purposes, the service accepts:

**Specific users:**
- test@example.com
- user@example.com
- admin@example.com
- postmaster@example.com

**All users from these domains:**
- @example.com
- @test.com

## Logs

The service provides detailed logging:

```
2026/02/27 10:01:23 New connection from 127.0.0.1:54321
2026/02/27 10:01:23 ← Received: "get user-exists test@example.com"
2026/02/27 10:01:23   Command: get, Map: user-exists, Key: test@example.com
2026/02/27 10:01:23   Cache MISS for test@example.com - checking user database
2026/02/27 10:01:23 ✓ User found: test@example.com
2026/02/27 10:01:23 → Sending: "OK test@example.com"
```

## Customization

To modify user validation logic, edit the `checkUserInTestDB()` function in `main.go`:

```go
func checkUserInTestDB(email string) bool {
    // Add your validation logic here
    // Examples:
    // - Call external API
    // - Query database
    // - Check LDAP
    // - Validate against file
    
    return true // or false
}
```

## Production Considerations

This is a **test-only** service. For production:

1. **Add proper IdP integration** (Keycloak, LDAP, database)
2. **Implement timeouts** for external calls (≤200ms)
3. **Add circuit breaker** for IdP failures
4. **Use connection pooling**
5. **Add metrics and monitoring**
6. **Consider Unix socket** instead of TCP
7. **Implement graceful shutdown**
8. **Add negative caching**
9. **Rate limiting**
10. **TLS if not localhost**

## Troubleshooting

### Service not starting
```bash
# Check if port is already in use
lsof -i :9100

# Kill existing process
kill $(lsof -t -i:9100)
```

### Postfix not connecting
```bash
# Check Postfix logs
tail -f /var/log/mail.log

# Test connectivity
telnet 127.0.0.1 9100

# Verify Postfix config
postconf virtual_mailbox_maps
```

### No logs appearing
- Ensure service is running: `ps aux | grep socketmap`
- Check file permissions
- Verify Postfix is actually performing lookups

## Architecture

```
SMTP Client
    ↓
Postfix (RCPT TO)
    ↓
virtual_mailbox_maps lookup
    ↓
Socketmap (127.0.0.1:9100)
    ↓
User validation logic
    ↓
OK / NOTFOUND
    ↓
250 OK / 550 User unknown
```

## Performance

- **Cache TTL:** 60 seconds
- **Connection timeout:** 30 seconds
- **Write timeout:** 5 seconds
- **Concurrent connections:** Unlimited (Go handles this efficiently)
