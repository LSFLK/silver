package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

var (
	HOST                  = getEnv("SOCKETMAP_HOST", "127.0.0.1")
	PORT                  = getEnv("SOCKETMAP_PORT", "9100")
	THUNDER_HOST          = getEnv("THUNDER_HOST", "thunder-server")
	THUNDER_PORT          = getEnv("THUNDER_PORT", "8090")
	CACHE_TTL_SECONDS     = getEnvInt("CACHE_TTL_SECONDS", 300)       // 5 minutes default
	TOKEN_REFRESH_SECONDS = getEnvInt("TOKEN_REFRESH_SECONDS", 3300)  // 55 minutes default
)

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}

// Cache structures
var (
	cache      = make(map[string]cacheEntry)
	cacheMutex sync.RWMutex
)

type cacheEntry struct {
	exists     bool
	data       string      // For storing additional data (e.g., alias destination)
	expires    time.Time
	lastUpdate time.Time
}

// Thunder authentication state
var (
	thunderAuth      *ThunderAuth
	thunderAuthMutex sync.RWMutex
)

type ThunderAuth struct {
	SampleAppID  string
	FlowID       string
	BearerToken  string
	ExpiresAt    time.Time
	LastRefresh  time.Time
}

// Thunder API response structures
type FlowStartResponse struct {
	FlowID string `json:"flowId"`
}

type FlowCompleteResponse struct {
	Assertion string `json:"assertion"`
}

type OrgUnitResponse struct {
	ID          string  `json:"id"`
	Handle      string  `json:"handle"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Parent      *string `json:"parent"`
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
	
	// Read exactly 'length' bytes of data using io.ReadFull
	data := make([]byte, length)
	if _, err := io.ReadFull(reader, data); err != nil {
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

// ============================================
// Thunder IDP Integration Functions
// ============================================

// getHTTPClient returns an HTTP client with TLS verification disabled for self-signed certs
func getHTTPClient() *http.Client {
	return &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		},
	}
}

// getSampleAppIDFromLogs extracts Sample App ID from Thunder setup container logs
func getSampleAppIDFromLogs() (string, error) {
	log.Printf("  │ Extracting Sample App ID from thunder-setup logs...")
	
	// Execute docker logs command to get Sample App ID
	cmd := exec.Command("docker", "logs", "thunder-setup")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to read thunder-setup logs: %w", err)
	}
	
	// Search for Sample App ID pattern
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.Contains(line, "Sample App ID:") {
			// Extract UUID pattern (e.g., 019cd1e1-a123-73e7-9ce8-98ea46c9a640)
			re := regexp.MustCompile(`[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}`)
			matches := re.FindString(line)
			if matches != "" {
				log.Printf("  │ ✓ Sample App ID extracted: %s", matches)
				return matches, nil
			}
		}
	}
	
	return "", fmt.Errorf("Sample App ID not found in thunder-setup logs")
}

// authenticateWithThunder performs the full authentication flow with Thunder IDP
func authenticateWithThunder() (*ThunderAuth, error) {
	log.Printf("  ┌─ Thunder Authentication ─────────")
	
	// Step 1: Get Sample App ID from environment or extract from logs
	sampleAppID := getEnv("THUNDER_SAMPLE_APP_ID", "")
	if sampleAppID == "" {
		log.Printf("  │ THUNDER_SAMPLE_APP_ID not set, extracting from logs...")
		var err error
		sampleAppID, err = getSampleAppIDFromLogs()
		if err != nil {
			log.Printf("  │ ✗ Failed to get Sample App ID: %v", err)
			log.Printf("  └───────────────────────────────────")
			return nil, fmt.Errorf("failed to get Sample App ID: %w", err)
		}
	} else {
		log.Printf("  │ Using Sample App ID from environment")
	}
	
	client := getHTTPClient()
	baseURL := fmt.Sprintf("https://%s:%s", THUNDER_HOST, THUNDER_PORT)
	
	// Step 2: Start authentication flow
	log.Printf("  │ Starting authentication flow...")
	flowPayload := map[string]interface{}{
		"applicationId": sampleAppID,
		"flowType":      "AUTHENTICATION",
	}
	flowData, _ := json.Marshal(flowPayload)
	
	resp, err := client.Post(baseURL+"/flow/execute", "application/json", bytes.NewBuffer(flowData))
	if err != nil {
		log.Printf("  │ ✗ Failed to start flow: %v", err)
		log.Printf("  └───────────────────────────────────")
		return nil, fmt.Errorf("failed to start flow: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != 200 {
		log.Printf("  │ ✗ Flow start failed (HTTP %d)", resp.StatusCode)
		log.Printf("  └───────────────────────────────────")
		return nil, fmt.Errorf("flow start failed with status %d", resp.StatusCode)
	}
	
	var flowResp FlowStartResponse
	if err := json.NewDecoder(resp.Body).Decode(&flowResp); err != nil {
		log.Printf("  │ ✗ Failed to parse flow response: %v", err)
		log.Printf("  └───────────────────────────────────")
		return nil, fmt.Errorf("failed to parse flow response: %w", err)
	}
	
	log.Printf("  │ ✓ Flow started (ID: %s)", flowResp.FlowID)
	
	// Step 3: Complete authentication flow
	log.Printf("  │ Completing authentication...")
	authPayload := map[string]interface{}{
		"flowId": flowResp.FlowID,
		"inputs": map[string]string{
			"username":             "admin",
			"password":             "admin",
			"requested_permissions": "system",
		},
		"action": "action_001",
	}
	authData, _ := json.Marshal(authPayload)
	
	resp2, err := client.Post(baseURL+"/flow/execute", "application/json", bytes.NewBuffer(authData))
	if err != nil {
		log.Printf("  │ ✗ Failed to complete auth: %v", err)
		log.Printf("  └───────────────────────────────────")
		return nil, fmt.Errorf("failed to complete auth: %w", err)
	}
	defer resp2.Body.Close()
	
	if resp2.StatusCode != 200 {
		log.Printf("  │ ✗ Auth completion failed (HTTP %d)", resp2.StatusCode)
		log.Printf("  └───────────────────────────────────")
		return nil, fmt.Errorf("auth completion failed with status %d", resp2.StatusCode)
	}
	
	var authResp FlowCompleteResponse
	if err := json.NewDecoder(resp2.Body).Decode(&authResp); err != nil {
		log.Printf("  │ ✗ Failed to parse auth response: %v", err)
		log.Printf("  └───────────────────────────────────")
		return nil, fmt.Errorf("failed to parse auth response: %w", err)
	}
	
	log.Printf("  │ ✓ Authentication successful")
	log.Printf("  └───────────────────────────────────")
	
	auth := &ThunderAuth{
		SampleAppID:  sampleAppID,
		FlowID:       flowResp.FlowID,
		BearerToken:  authResp.Assertion,
		ExpiresAt:    time.Now().Add(time.Duration(TOKEN_REFRESH_SECONDS) * time.Second),
		LastRefresh:  time.Now(),
	}
	
	return auth, nil
}

// getThunderAuth returns a valid Thunder auth token, refreshing if needed
func getThunderAuth() (*ThunderAuth, error) {
	thunderAuthMutex.RLock()
	auth := thunderAuth
	thunderAuthMutex.RUnlock()
	
	// Check if we have a valid token
	if auth != nil && time.Now().Before(auth.ExpiresAt) {
		return auth, nil
	}
	
	// Need to authenticate or refresh
	thunderAuthMutex.Lock()
	defer thunderAuthMutex.Unlock()
	
	// Double-check after acquiring write lock
	if thunderAuth != nil && time.Now().Before(thunderAuth.ExpiresAt) {
		return thunderAuth, nil
	}
	
	// Authenticate
	newAuth, err := authenticateWithThunder()
	if err != nil {
		return nil, err
	}
	
	thunderAuth = newAuth
	return thunderAuth, nil
}

// validateDomainWithThunder checks if a domain exists in Thunder IDP
func validateDomainWithThunder(domain string) (bool, error) {
	log.Printf("      ┌─ Thunder Domain Validation ──")
	log.Printf("      │ Domain: %s", domain)
	
	// Get authentication token
	auth, err := getThunderAuth()
	if err != nil {
		log.Printf("      │ ⚠ Auth failed: %v", err)
		log.Printf("      └──────────────────────────────")
		return false, err
	}
	
	// Parse domain into OU path
	// Example: silver.openmail.lk -> openmail.lk/silver
	parts := strings.Split(domain, ".")
	if len(parts) < 2 {
		log.Printf("      │ ✗ Invalid domain format")
		log.Printf("      └──────────────────────────────")
		return false, nil
	}
	
	// Build OU path: root is last two parts (e.g., openmail.lk)
	// subdomain parts become child OUs
	var ouPath string
	if len(parts) == 2 {
		// Simple domain like openmail.lk
		ouPath = domain
	} else {
		// Multi-level domain like silver.openmail.lk
		// Root OU: openmail.lk, Child OU: silver
		rootDomain := strings.Join(parts[len(parts)-2:], ".")
		subdomains := parts[:len(parts)-2]
		ouPath = rootDomain + "/" + strings.Join(subdomains, "/")
	}
	
	log.Printf("      │ OU Path: %s", ouPath)
	
	// Query Thunder API
	client := getHTTPClient()
	url := fmt.Sprintf("https://%s:%s/organization-units/tree/%s", THUNDER_HOST, THUNDER_PORT, ouPath)
	
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		log.Printf("      │ ✗ Failed to create request: %v", err)
		log.Printf("      └──────────────────────────────")
		return false, err
	}
	
	req.Header.Set("Authorization", "Bearer "+auth.BearerToken)
	req.Header.Set("Content-Type", "application/json")
	
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("      │ ✗ Request failed: %v", err)
		log.Printf("      └──────────────────────────────")
		return false, err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == 404 {
		log.Printf("      │ ✗ Domain not found in Thunder")
		log.Printf("      └──────────────────────────────")
		return false, nil
	}
	
	if resp.StatusCode != 200 {
		log.Printf("      │ ⚠ Unexpected status: %d", resp.StatusCode)
		log.Printf("      └──────────────────────────────")
		return false, fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}
	
	var ouResp OrgUnitResponse
	if err := json.NewDecoder(resp.Body).Decode(&ouResp); err != nil {
		log.Printf("      │ ✗ Failed to parse response: %v", err)
		log.Printf("      └──────────────────────────────")
		return false, err
	}
	
	log.Printf("      │ ✓ Domain found in Thunder")
	log.Printf("      │ OU ID: %s", ouResp.ID)
	log.Printf("      │ OU Name: %s", ouResp.Name)
	log.Printf("      └──────────────────────────────")
	
	return true, nil
}

// Track active connections for graceful shutdown
var (
	activeConnections sync.WaitGroup
)

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

	log.Printf("✓ Socketmap service listening on %s:%s", HOST, PORT)
	log.Printf("✓ Ready to accept connections from Postfix")
	log.Printf("===========================================")

	// Setup graceful shutdown
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Accept connections in a goroutine
	connectionCount := 0
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				select {
				case <-ctx.Done():
					// Shutdown in progress, exit gracefully
					return
				default:
					log.Printf("⚠ Error accepting connection: %v", err)
					continue
				}
			}

			connectionCount++
			log.Printf("")
			log.Printf("═══════════════════════════════════════")
			log.Printf("Connection #%d from %s", connectionCount, conn.RemoteAddr())
			log.Printf("═══════════════════════════════════════")
			
			activeConnections.Add(1)
			go func(c net.Conn) {
				defer activeConnections.Done()
				handleConnection(c)
			}(conn)
		}
	}()

	// Wait for shutdown signal
	<-ctx.Done()
	log.Printf("")
	log.Printf("===========================================")
	log.Printf("Received shutdown signal, closing listener...")
	log.Printf("===========================================")
	
	// Close listener to stop accepting new connections
	listener.Close()
	
	// Wait for active connections to complete (with timeout)
	done := make(chan struct{})
	go func() {
		activeConnections.Wait()
		close(done)
	}()

	select {
	case <-done:
		log.Printf("All connections closed gracefully")
	case <-time.After(30 * time.Second):
		log.Printf("Shutdown timeout reached, forcing exit")
	}

	log.Printf("Socketmap service stopped")
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
		// For virtual_mailbox_maps, Postfix expects a mailbox pathname
		// The actual path doesn't matter since we use virtual_transport = lmtp
		// But we must return SOMETHING for Postfix to consider the user valid
		mailboxPath := key // Just return the email address as the "path"
		
		log.Printf("  │ ✓ USER FOUND: %s", key)
		log.Printf("  │ Response: OK %s", mailboxPath)
		log.Printf("  └─────────────────────────────────────")
		return fmt.Sprintf("OK %s", mailboxPath)
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
		return "OK 1"
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
	
	// Check cache first (read lock)
	cacheMutex.RLock()
	entry, found := cache[email]
	cacheMutex.RUnlock()
	
	now := time.Now()
	
	if found {
		// Cache hit - check if still valid
		if now.Before(entry.expires) {
			log.Printf("    │ ✓ CACHE HIT (fresh)")
			log.Printf("    │ Cached result: exists=%v", entry.exists)
			log.Printf("    │ Expires: %s", entry.expires.Format("15:04:05"))
			log.Printf("    └─────────────────────────────────")
			return entry.exists
		}
		
		// Cache expired - check if we should refresh
		cacheAge := now.Sub(entry.lastUpdate).Seconds()
		log.Printf("    │ ✓ CACHE HIT (stale)")
		log.Printf("    │ Age: %.0f seconds", cacheAge)
		log.Printf("    │ Refreshing from database...")
	} else {
		log.Printf("    │ ✗ CACHE MISS")
		log.Printf("    │ Querying user database...")
	}

	// Query database for user
	exists := checkUserInTestDB(email)

	log.Printf("    │ Database result: exists=%v", exists)
	
	// Update cache (write lock)
	cacheMutex.Lock()
	cache[email] = cacheEntry{
		exists:     exists,
		expires:    now.Add(time.Duration(CACHE_TTL_SECONDS) * time.Second),
		lastUpdate: now,
	}
	cacheMutex.Unlock()
	
	log.Printf("    │ Cached for %d seconds", CACHE_TTL_SECONDS)
	log.Printf("    └─────────────────────────────────")

	return exists
}

func checkUserInTestDB(email string) bool {
	log.Printf("      ┌─ Test DB Lookup ─────────────")
	log.Printf("      │ Checking: %s", email)

	// Define SPECIFIC valid mailboxes - not just domains!
	// In production, replace this with database/YAML query
	validMailboxes := []string{
		// example.com domain users
		"test@example.com",
		"user@example.com",
		"admin@example.com",
		"postmaster@example.com",
		
		// test.com domain users
		"user@test.com",
		"admin@test.com",
		
		// aravindahwk.org domain users
		"user1@aravindahwk.org",
		"user2@aravindahwk.org",
		"admin@aravindahwk.org",
		"postmaster@aravindahwk.org",
		"abuse@aravindahwk.org",
		"hostmaster@aravindahwk.org",
	}

	// Check if the exact email address exists
	for _, mailbox := range validMailboxes {
		if strings.EqualFold(email, mailbox) {
			log.Printf("      │ ✓ Matched mailbox: %s", mailbox)
			log.Printf("      └──────────────────────────────")
			return true
		}
	}
	
	log.Printf("      │ ✗ User not found")
	log.Printf("      │ Valid mailboxes: %d configured", len(validMailboxes))
	log.Printf("      └──────────────────────────────")
	return false
}

func domainExists(domain string) bool {
	log.Printf("    ┌─ Domain Lookup ─────────────────")
	log.Printf("    │ Domain: %s", domain)
	
	// Check cache first (read lock)
	cacheKey := "domain:" + domain
	cacheMutex.RLock()
	entry, found := cache[cacheKey]
	cacheMutex.RUnlock()
	
	now := time.Now()
	
	if found {
		// Cache hit - check if still valid
		if now.Before(entry.expires) {
			log.Printf("    │ ✓ CACHE HIT (fresh)")
			log.Printf("    │ Cached result: exists=%v", entry.exists)
			log.Printf("    │ Expires: %s", entry.expires.Format("15:04:05"))
			log.Printf("    └─────────────────────────────────")
			return entry.exists
		}
		
		// Cache expired but exists - check if we should refresh
		cacheAge := now.Sub(entry.lastUpdate).Seconds()
		log.Printf("    │ ✓ CACHE HIT (stale)")
		log.Printf("    │ Age: %.0f seconds", cacheAge)
		log.Printf("    │ Refreshing from IDP...")
	} else {
		log.Printf("    │ ✗ CACHE MISS")
		log.Printf("    │ Querying IDP...")
	}

	// Query Thunder IDP for domain validation
	exists, err := validateDomainWithThunder(domain)
	if err != nil {
		log.Printf("    │ ⚠ IDP query failed: %v", err)
		log.Printf("    │ Falling back to test DB...")
		// Fallback to test DB if Thunder is unavailable
		exists = checkDomainInTestDB(domain)
	}

	log.Printf("    │ IDP result: exists=%v", exists)
	
	// Update cache (write lock)
	cacheMutex.Lock()
	cache[cacheKey] = cacheEntry{
		exists:     exists,
		expires:    now.Add(time.Duration(CACHE_TTL_SECONDS) * time.Second),
		lastUpdate: now,
	}
	cacheMutex.Unlock()
	
	log.Printf("    │ Cached for %d seconds", CACHE_TTL_SECONDS)
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
		"aravindahwk.org",
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
	
	// Check cache first (read lock)
	cacheKey := "alias:" + address
	cacheMutex.RLock()
	entry, found := cache[cacheKey]
	cacheMutex.RUnlock()
	
	now := time.Now()
	
	if found {
		// Cache hit - check if still valid
		if now.Before(entry.expires) {
			log.Printf("    │ ✓ CACHE HIT (fresh)")
			log.Printf("    │ Destination: %s", entry.data)
			log.Printf("    │ Expires: %s", entry.expires.Format("15:04:05"))
			log.Printf("    └─────────────────────────────────")
			return entry.data
		}
		
		// Cache expired - refresh
		cacheAge := now.Sub(entry.lastUpdate).Seconds()
		log.Printf("    │ ✓ CACHE HIT (stale)")
		log.Printf("    │ Age: %.0f seconds", cacheAge)
		log.Printf("    │ Refreshing from database...")
	} else {
		log.Printf("    │ ✗ CACHE MISS")
		log.Printf("    │ Querying alias database...")
	}

	// Query database for alias
	destination := checkAliasInTestDB(address)

	log.Printf("    │ Database result: destination=%s", destination)
	
	// Update cache (write lock)
	cacheMutex.Lock()
	cache[cacheKey] = cacheEntry{
		exists:     destination != "",
		data:       destination,
		expires:    now.Add(time.Duration(CACHE_TTL_SECONDS) * time.Second),
		lastUpdate: now,
	}
	cacheMutex.Unlock()
	
	log.Printf("    │ Cached for %d seconds", CACHE_TTL_SECONDS)
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
