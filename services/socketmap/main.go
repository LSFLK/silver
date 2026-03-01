package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"os"
	"strconv"
	"strings"
	"time"
)

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

var (
	HOST = getEnv("SOCKETMAP_HOST", "127.0.0.1")
	PORT = getEnv("SOCKETMAP_PORT", "9100")
)

// Simple in-memory cache for testing
var cache = make(map[string]cacheEntry)

type cacheEntry struct {
	exists  bool
	expires time.Time
}

// readNetstring reads a netstring from the reader
// Netstring format: <length>:<data>,
// Example: "5:hello," represents the string "hello"
func readNetstring(reader *bufio.Reader) (string, error) {
	// Read length prefix (digits before ':')
	lengthStr, err := reader.ReadString(':')
	if err != nil {
		return "", fmt.Errorf("failed to read length: %w", err)
	}
	
	// Remove the ':' and parse length
	lengthStr = strings.TrimSuffix(lengthStr, ":")
	length, err := strconv.Atoi(lengthStr)
	if err != nil {
		return "", fmt.Errorf("invalid length: %w", err)
	}
	
	log.Printf("      Netstring length: %d", length)
	
	// Read exactly 'length' bytes of data
	data := make([]byte, length)
	_, err = reader.Read(data)
	if err != nil {
		return "", fmt.Errorf("failed to read data: %w", err)
	}
	
	// Read and verify the trailing comma
	comma, err := reader.ReadByte()
	if err != nil {
		return "", fmt.Errorf("failed to read comma: %w", err)
	}
	if comma != ',' {
		return "", fmt.Errorf("expected comma, got %c", comma)
	}
	
	return string(data), nil
}

// writeNetstring writes a netstring to the connection
func writeNetstring(conn net.Conn, data string) error {
	netstr := fmt.Sprintf("%d:%s,", len(data), data)
	_, err := conn.Write([]byte(netstr))
	return err
}

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.Printf("===========================================")
	log.Printf("Starting socketmap service")
	log.Printf("===========================================")
	log.Printf("Configuration:")
	log.Printf("  HOST: %s", HOST)
	log.Printf("  PORT: %s", PORT)
	log.Printf("  Bind Address: %s:%s", HOST, PORT)
	log.Printf("===========================================")

	listener, err := net.Listen("tcp", HOST+":"+PORT)
	if err != nil {
		log.Fatalf("Failed to bind to %s:%s: %v", HOST, PORT, err)
	}
	defer listener.Close()

	log.Printf("✓ Socketmap service listening on %s:%s", HOST, PORT)
	log.Printf("✓ Ready to accept connections from Postfix")
	log.Printf("===========================================")

	connectionCount := 0
	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("⚠ Error accepting connection: %v", err)
			continue
		}

		connectionCount++
		log.Printf("")
		log.Printf("═══════════════════════════════════════")
		log.Printf("Connection #%d from %s", connectionCount, conn.RemoteAddr())
		log.Printf("═══════════════════════════════════════")
		go handleConnection(conn)
	}
}

func handleConnection(conn net.Conn) {
	defer conn.Close()
	defer log.Printf("Connection closed: %s", conn.RemoteAddr())

	log.Printf("  Connection established, using netstring protocol...")
	reader := bufio.NewReader(conn)

	for {
		// Set read timeout to prevent hanging connections
		conn.SetReadDeadline(time.Now().Add(30 * time.Second))

		log.Printf("  Waiting to read netstring from connection...")
		
		// Read request using netstring protocol
		request, err := readNetstring(reader)
		if err != nil {
			if err.Error() != "EOF" && !strings.Contains(err.Error(), "EOF") {
				log.Printf("⚠ Error reading netstring from %s: %v", conn.RemoteAddr(), err)
				log.Printf("  Possible causes:")
				log.Printf("  1. Client sent non-netstring data")
				log.Printf("  2. Connection interrupted")
				log.Printf("  3. Protocol version mismatch")
			} else {
				log.Printf("  Connection closed by client (EOF)")
			}
			return
		}

		// Log raw request received
		log.Printf("← Received netstring: %q (length: %d)", request, len(request))
		
		if request == "" {
			log.Printf("⚠ Received empty request, skipping...")
			continue
		}
		
		log.Printf("  Processing request: %q", request)

		// Process the request
		response := processRequest(request)
		log.Printf("→ Preparing response: %q", response)

		// Send response using netstring protocol
		conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
		err = writeNetstring(conn, response)
		if err != nil {
			log.Printf("⚠ Error writing netstring to %s: %v", conn.RemoteAddr(), err)
			return
		}
		log.Printf("  Successfully sent netstring response (length: %d)", len(response))
	}
}

func processRequest(line string) string {
	log.Printf("  ┌─ Processing Request ─────────────────")
	log.Printf("  │ Raw input: %q", line)
	
	parts := strings.Fields(line)
	log.Printf("  │ Split into %d parts: %v", len(parts), parts)

	// Postfix socketmap protocol sends: <mapname> <key>
	// NOT: get <mapname> <key>
	if len(parts) != 2 {
		log.Printf("  │ ⚠ INVALID REQUEST FORMAT")
		log.Printf("  │ Expected: <mapname> <key>")
		log.Printf("  │ Got: %d parts", len(parts))
		log.Printf("  └─────────────────────────────────────")
		return "PERM invalid request format"
	}

	mapname := parts[0]
	key := parts[1]

	log.Printf("  │ Map:     %q", mapname)
	log.Printf("  │ Key:     %q", key)

	// Route to appropriate handler based on map name
	switch mapname {
	case "user-exists":
		return handleUserExistsMap(key)
	case "virtual-domains":
		return handleVirtualDomainsMap(key)
	case "virtual-aliases":
		return handleVirtualAliasesMap(key)
	default:
		log.Printf("  │ ⚠ UNKNOWN MAP")
		log.Printf("  │ Supported maps: user-exists, virtual-domains, virtual-aliases")
		log.Printf("  │ Got: %q", mapname)
		log.Printf("  └─────────────────────────────────────")
		return "NOTFOUND"
	}
}

func handleUserExistsMap(key string) string {
	// Check if user exists
	log.Printf("  │ Checking if user exists...")
	exists := userExists(key)

	if exists {
		log.Printf("  │ ✓ USER FOUND: %s", key)
		log.Printf("  │ Response: OK %s", key)
		log.Printf("  └─────────────────────────────────────")
		return fmt.Sprintf("OK %s", key)
	}

	log.Printf("  │ ✗ USER NOT FOUND: %s", key)
	log.Printf("  │ Response: NOTFOUND")
	log.Printf("  └─────────────────────────────────────")
	return "NOTFOUND"
}

func handleVirtualDomainsMap(domain string) string {
	// Check if domain is valid
	log.Printf("  │ Checking if domain is valid...")
	exists := domainExists(domain)

	if exists {
		log.Printf("  │ ✓ DOMAIN FOUND: %s", domain)
		log.Printf("  │ Response: OK")
		log.Printf("  └─────────────────────────────────────")
		// Return OK for valid domains (Postfix just needs OK response)
		return "OK"
	}

	log.Printf("  │ ✗ DOMAIN NOT FOUND: %s", domain)
	log.Printf("  │ Response: NOTFOUND")
	log.Printf("  └─────────────────────────────────────")
	return "NOTFOUND"
}

func handleVirtualAliasesMap(address string) string {
	// Check if alias exists and return destination
	log.Printf("  │ Checking if alias exists...")
	destination := resolveAlias(address)

	if destination != "" {
		log.Printf("  │ ✓ ALIAS FOUND: %s -> %s", address, destination)
		log.Printf("  │ Response: OK %s", destination)
		log.Printf("  └─────────────────────────────────────")
		return fmt.Sprintf("OK %s", destination)
	}

	log.Printf("  │ ✗ ALIAS NOT FOUND: %s", address)
	log.Printf("  │ Response: NOTFOUND")
	log.Printf("  └─────────────────────────────────────")
	return "NOTFOUND"
}

func userExists(email string) bool {
	log.Printf("    ┌─ User Lookup ───────────────────")
	log.Printf("    │ Email: %s", email)
	
	// Check cache first
	if entry, found := cache[email]; found && time.Now().Before(entry.expires) {
		log.Printf("    │ ✓ CACHE HIT")
		log.Printf("    │ Cached result: exists=%v", entry.exists)
		log.Printf("    │ Expires: %s", entry.expires.Format("15:04:05"))
		log.Printf("    └─────────────────────────────────")
		return entry.exists
	}

	log.Printf("    │ ✗ CACHE MISS")
	log.Printf("    │ Querying user database...")

	// For testing: accept users from specific domains
	// In production, this would call your IdP/database
	exists := checkUserInTestDB(email)

	log.Printf("    │ Database result: exists=%v", exists)
	
	// Cache the result for 60 seconds
	cache[email] = cacheEntry{
		exists:  exists,
		expires: time.Now().Add(60 * time.Second),
	}
	
	log.Printf("    │ Cached for 60 seconds")
	log.Printf("    └─────────────────────────────────")

	return exists
}

func checkUserInTestDB(email string) bool {
	// Simple test logic: accept specific test users
	// Replace this with your actual user validation logic
	
	log.Printf("      ┌─ Test DB Lookup ─────────────")
	log.Printf("      │ Checking: %s", email)

	testUsers := []string{
		"test@example.com",
		"user@example.com",
		"admin@example.com",
		"postmaster@example.com",
	}

	// Check specific test users
	for _, user := range testUsers {
		if strings.EqualFold(email, user) {
			log.Printf("      │ ✓ Matched test user: %s", user)
			log.Printf("      └──────────────────────────────")
			return true
		}
	}
	log.Printf("      │ Not in test users list")

	// Accept any user from allowed domains (for testing)
	allowedDomains := []string{
		"example.com",
		"test.com",
	}

	log.Printf("      │ Checking allowed domains...")
	for _, domain := range allowedDomains {
		if strings.HasSuffix(strings.ToLower(email), "@"+domain) {
			// For testing: accept all users from these domains
			log.Printf("      │ ✓ Matched domain: %s", domain)
			log.Printf("      └──────────────────────────────")
			return true
		}
	}
	
	log.Printf("      │ ✗ Not in allowed domains")
	log.Printf("      │ Allowed: %v", allowedDomains)
	log.Printf("      └──────────────────────────────")
	return false
}

func domainExists(domain string) bool {
	log.Printf("    ┌─ Domain Lookup ─────────────────")
	log.Printf("    │ Domain: %s", domain)
	
	// Check cache first
	cacheKey := "domain:" + domain
	if entry, found := cache[cacheKey]; found && time.Now().Before(entry.expires) {
		log.Printf("    │ ✓ CACHE HIT")
		log.Printf("    │ Cached result: exists=%v", entry.exists)
		log.Printf("    │ Expires: %s", entry.expires.Format("15:04:05"))
		log.Printf("    └─────────────────────────────────")
		return entry.exists
	}

	log.Printf("    │ ✗ CACHE MISS")
	log.Printf("    │ Querying domain database...")

	// For testing: accept specific domains
	// In production, this would query your domain configuration
	exists := checkDomainInTestDB(domain)

	log.Printf("    │ Database result: exists=%v", exists)
	
	// Cache the result for 300 seconds (5 minutes)
	cache[cacheKey] = cacheEntry{
		exists:  exists,
		expires: time.Now().Add(300 * time.Second),
	}
	
	log.Printf("    │ Cached for 300 seconds")
	log.Printf("    └─────────────────────────────────")

	return exists
}

func checkDomainInTestDB(domain string) bool {
	log.Printf("      ┌─ Test Domain DB Lookup ──────")
	log.Printf("      │ Checking: %s", domain)

	// For testing: accept specific domains
	// In production, read from silver.yaml or database
	allowedDomains := []string{
		"example.com",
		"test.com",
		"localhost",
	}

	for _, allowed := range allowedDomains {
		if strings.EqualFold(domain, allowed) {
			log.Printf("      │ ✓ Matched domain: %s", allowed)
			log.Printf("      └──────────────────────────────")
			return true
		}
	}
	
	log.Printf("      │ ✗ Not in allowed domains")
	log.Printf("      │ Allowed: %v", allowedDomains)
	log.Printf("      └──────────────────────────────")
	return false
}

func resolveAlias(address string) string {
	log.Printf("    ┌─ Alias Lookup ──────────────────")
	log.Printf("    │ Address: %s", address)
	
	// Check cache first
	cacheKey := "alias:" + address
	if entry, found := cache[cacheKey]; found && time.Now().Before(entry.expires) {
		log.Printf("    │ ✓ CACHE HIT")
		// For aliases, we store the destination in exists field (hacky but works)
		// Actually, we need a better cache structure for this
		log.Printf("    │ Expires: %s", entry.expires.Format("15:04:05"))
		log.Printf("    └─────────────────────────────────")
		// Return empty string for now from cache, will fix cache structure
	}

	log.Printf("    │ ✗ CACHE MISS or uncached")
	log.Printf("    │ Querying alias database...")

	// For testing: check if alias exists and return destination
	// In production, this would query your alias configuration
	destination := checkAliasInTestDB(address)

	log.Printf("    │ Database result: destination=%s", destination)
	
	// Cache the result for 300 seconds (5 minutes)
	// Note: This cache structure is simplified - in production use a proper cache
	// that can store the destination address
	cache[cacheKey] = cacheEntry{
		exists:  destination != "",
		expires: time.Now().Add(300 * time.Second),
	}
	
	log.Printf("    │ Cached for 300 seconds")
	log.Printf("    └─────────────────────────────────")

	return destination
}

func checkAliasInTestDB(address string) string {
	log.Printf("      ┌─ Test Alias DB Lookup ───────")
	log.Printf("      │ Checking: %s", address)

	// For testing: define some common aliases
	// In production, read from configuration or database
	aliases := map[string]string{
		"postmaster@example.com": "admin@example.com",
		"abuse@example.com":      "admin@example.com",
		"hostmaster@example.com": "admin@example.com",
		"webmaster@example.com":  "admin@example.com",
		"info@example.com":       "admin@example.com",
		"support@test.com":       "help@test.com",
	}

	// Check if alias exists
	if destination, found := aliases[strings.ToLower(address)]; found {
		log.Printf("      │ ✓ Alias found: %s -> %s", address, destination)
		log.Printf("      └──────────────────────────────")
		return destination
	}
	
	log.Printf("      │ ✗ Alias not found")
	log.Printf("      └──────────────────────────────")
	return ""
}
