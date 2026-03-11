package thunder

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"sync"
	"time"
)

var (
	thunderAuth      *Auth
	thunderAuthMutex sync.RWMutex
)

// getSampleAppIDFromThunderSetup extracts Sample App ID from thunder-setup container
func getSampleAppIDFromThunderSetup() (string, error) {
	log.Printf("  │ Extracting Sample App ID from thunder-setup container...")
	
	// Execute: docker logs thunder-setup 2>&1 | grep 'Sample App ID:' | head -n1
	cmd := exec.Command("docker", "logs", "thunder-setup")
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Check if docker command doesn't exist
		if strings.Contains(err.Error(), "executable file not found") {
			return "", fmt.Errorf("docker command not available in PATH")
		}
		// Docker command exists but failed - might be permission issue
		log.Printf("  │ ⚠ Warning: docker logs command failed: %v", err)
		log.Printf("  │ This might be due to:")
		log.Printf("  │   - thunder-setup container doesn't exist")
		log.Printf("  │   - No permission to access Docker")
		log.Printf("  │   - Running inside a container without Docker socket")
	}
	
	// Search for "Sample App ID:" in logs (case-insensitive)
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.Contains(line, "Sample App ID:") {
			// Extract UUID pattern: [a-f0-9-]{36}
			re := regexp.MustCompile(`[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}`)
			match := re.FindString(line)
			if match != "" {
				log.Printf("  │ ✓ Sample App ID extracted: %s", match)
				return match, nil
			}
		}
	}
	
	return "", fmt.Errorf("Sample App ID not found in thunder-setup logs")
}

// Authenticate performs the full authentication flow with Thunder IDP
func Authenticate(host, port string, tokenRefreshSeconds int) (*Auth, error) {
	log.Printf("  ┌─ Thunder Authentication ─────────")
	
	// Step 1: Get Sample App ID
	sampleAppID := os.Getenv("THUNDER_SAMPLE_APP_ID")
	
	if sampleAppID != "" {
		log.Printf("  │ Using Sample App ID from environment variable")
		log.Printf("  │ Sample App ID: %s", sampleAppID)
	} else {
		log.Printf("  │ THUNDER_SAMPLE_APP_ID not set")
		log.Printf("  │ Attempting to extract from thunder-setup container logs...")
		
		var err error
		sampleAppID, err = getSampleAppIDFromThunderSetup()
		if err != nil {
			log.Printf("  │ ✗ Failed to extract Sample App ID: %v", err)
			log.Printf("  │")
			log.Printf("  │ Please ensure Thunder setup container has completed successfully")
			log.Printf("  │")
			log.Printf("  │ To fix this issue:")
			log.Printf("  │ 1. Check thunder-setup logs: docker logs thunder-setup")
			log.Printf("  │ 2. Extract App ID manually and set environment:")
			log.Printf("  │    export THUNDER_SAMPLE_APP_ID=$(docker logs thunder-setup 2>&1 | grep 'Sample App ID:' | grep -o '[a-f0-9-]\\{36\\}')")
			log.Printf("  │ 3. Or if running in Docker, mount the Docker socket:")
			log.Printf("  │    volumes: ['/var/run/docker.sock:/var/run/docker.sock']")
			log.Printf("  └───────────────────────────────────")
			return nil, fmt.Errorf("failed to get Sample App ID: %w", err)
		}
	}
	
	client := GetHTTPClient()
	baseURL := fmt.Sprintf("https://%s:%s", host, port)
	
	// Step 2: Start authentication flow
	log.Printf("  │ Starting authentication flow...")
	flowPayload := map[string]interface{}{
		"applicationId": sampleAppID,
		"flowType":      "AUTHENTICATION",
	}
	flowData, err := json.Marshal(flowPayload)
    if err != nil {
        log.Printf("  │ ✗ Failed to marshal flow payload: %v", err)
        log.Printf("  └───────────────────────────────────")
        return nil, fmt.Errorf("failed to marshal flow payload: %w", err)
    }
	
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
	
	auth := &Auth{
		SampleAppID:  sampleAppID,
		FlowID:       flowResp.FlowID,
		BearerToken:  authResp.Assertion,
		ExpiresAt:    time.Now().Add(time.Duration(tokenRefreshSeconds) * time.Second),
		LastRefresh:  time.Now(),
	}
	
	return auth, nil
}

// GetAuth returns a valid Thunder auth token, refreshing if needed
func GetAuth(host, port string, tokenRefreshSeconds int) (*Auth, error) {
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
	newAuth, err := Authenticate(host, port, tokenRefreshSeconds)
	if err != nil {
		return nil, err
	}
	
	thunderAuth = newAuth
	return thunderAuth, nil
}

// SetAuth sets the global auth state (for initialization)
func SetAuth(auth *Auth) {
	thunderAuthMutex.Lock()
	defer thunderAuthMutex.Unlock()
	thunderAuth = auth
}
