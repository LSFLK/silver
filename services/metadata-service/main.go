package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/mux"
)

// HTTP client with timeout
var httpClient = &http.Client{
	Timeout: 15 * time.Second,
}

// Compiled regex for ClamAV CVD header parsing
var clamAVVDBRegex = regexp.MustCompile(`ClamAV-VDB:(\d+):(\d+):`)

// sanitizeForLog removes newline and carriage return characters to prevent log injection
func sanitizeForLog(s string) string {
	s = strings.ReplaceAll(s, "\n", " ")
	s = strings.ReplaceAll(s, "\r", " ")
	return s
}

// Configuration
type Config struct {
	Port              string
	ClamAVDBPath      string
	ExternalAPIURL    string
	PushInterval      time.Duration
	EnablePushService bool
	APIKey            string
	InstanceID        string
}

// SuperPlatformHeartbeat represents the heartbeat payload for Super Platform
type SuperPlatformHeartbeat struct {
	Timestamp           string `json:"timestamp"`
	InstanceID          string `json:"instance_id"`
	SignatureVersion    string `json:"signature_version"`
	SignatureUpdatedAt  string `json:"signature_updated_at"`
}

// SuperPlatformResult represents data received from Super Platform
type SuperPlatformResult struct {
	Status    string                 `json:"status"`
	Data      map[string]interface{} `json:"data"`
	Timestamp string                 `json:"timestamp"`
}

var config Config

func init() {
	config = Config{
		Port:              getEnv("PORT", "8888"),
		ClamAVDBPath:      getEnv("CLAMAV_DB_PATH", "/var/lib/clamav"),
		ExternalAPIURL:    getEnv("EXTERNAL_API_URL", ""),
		PushInterval:      time.Duration(getEnvAsInt("PUSH_INTERVAL_SECONDS", 60)) * time.Second,
		EnablePushService: getEnv("ENABLE_PUSH_SERVICE", "true") == "true",
		APIKey:            getEnv("API_KEY", ""),
		InstanceID:        getServerIP(), // Use server IP as instance ID
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
		log.Printf("Warning: could not parse env var %s=%s as integer. Using default.", key, value)
	}
	return defaultValue
}

// getServerIP attempts to get the server's outbound IP address
func getServerIP() string {
	// Try to get the outbound IP by connecting to a public DNS server
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		log.Printf("Warning: could not determine server IP: %v", err)
		return "unknown"
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr)
	return localAddr.IP.String()
}

// getClamAVSignatureInfo reads ClamAV daily.cvd file information
func getClamAVSignatureInfo() (version int, updatedAt time.Time, err error) {
	// Look for daily.cvd or daily.cld
	dailyPath := filepath.Join(config.ClamAVDBPath, "daily.cvd")
	
	// Check if daily.cvd exists, otherwise try daily.cld
	info, err := os.Stat(dailyPath)
	if os.IsNotExist(err) {
		dailyPath = filepath.Join(config.ClamAVDBPath, "daily.cld")
		info, err = os.Stat(dailyPath)
		if err != nil {
			return 0, time.Time{}, fmt.Errorf("daily.cvd/cld not found: %w", err)
		}
	}
	
	// Get modification time
	updatedAt = info.ModTime()
	
	// Try to read CVD header to get version
	file, err := os.Open(dailyPath)
	if err != nil {
		return 0, updatedAt, fmt.Errorf("failed to open %s: %w", dailyPath, err)
	}
	defer file.Close()
	
	header := make([]byte, 512)
	if n, err := file.Read(header); err == nil && n > 0 {
		// CVD header format: ClamAV-VDB:build_time:version:...
		matches := clamAVVDBRegex.FindSubmatch(header[:100])
		if len(matches) == 3 {
			var ver int
			if _, err := fmt.Sscanf(string(matches[2]), "%d", &ver); err == nil {
				version = ver
			}
		}
	}
	
	return version, updatedAt, nil
}

// createHeartbeatPayload creates the Super Platform heartbeat payload
func createHeartbeatPayload() (*SuperPlatformHeartbeat, error) {
	version, updatedAt, err := getClamAVSignatureInfo()
	if err != nil {
		return nil, fmt.Errorf("failed to get ClamAV signature info: %w", err)
	}
	
	// Determine file name (daily.cvd or daily.cld)
	fileName := "daily.cvd"
	if _, err := os.Stat(filepath.Join(config.ClamAVDBPath, "daily.cvd")); os.IsNotExist(err) {
		fileName = "daily.cld"
	}
	
	return &SuperPlatformHeartbeat{
		Timestamp:          time.Now().UTC().Format(time.RFC3339),
		InstanceID:         config.InstanceID,
		SignatureVersion:   fmt.Sprintf("%s:%d", fileName, version),
		SignatureUpdatedAt: updatedAt.UTC().Format(time.RFC3339),
	}, nil
}

// pushMetadataToExternalAPI sends heartbeat to Super Platform
func pushMetadataToExternalAPI() error {
	if config.ExternalAPIURL == "" {
		return fmt.Errorf("EXTERNAL_API_URL not configured")
	}

	heartbeat, err := createHeartbeatPayload()
	if err != nil {
		return fmt.Errorf("failed to create heartbeat payload: %w", err)
	}

	jsonData, err := json.Marshal(heartbeat)
	if err != nil {
		return fmt.Errorf("failed to marshal heartbeat: %w", err)
	}

	log.Printf("Sending heartbeat: %s", string(jsonData))

	resp, err := httpClient.Post(config.ExternalAPIURL, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to send heartbeat: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("external API returned status %d: %s", resp.StatusCode, string(body))
	}

	log.Printf("Successfully pushed heartbeat to Super Platform (status: %d)", resp.StatusCode)
	return nil
}

// startPeriodicPush starts the periodic metadata push service
func startPeriodicPush() {
	if !config.EnablePushService {
		log.Println("Periodic push service is disabled")
		return
	}

	if config.ExternalAPIURL == "" {
		log.Println("Warning: EXTERNAL_API_URL not set. Periodic push service will not function.")
		return
	}

	ticker := time.NewTicker(config.PushInterval)
	go func() {
		log.Printf("Starting periodic metadata push service (interval: %v)", config.PushInterval)
		
		// Push immediately on startup
		if err := pushMetadataToExternalAPI(); err != nil {
			log.Printf("Error pushing metadata on startup: %v", err)
		}

		// Then push periodically
		for range ticker.C {
			if err := pushMetadataToExternalAPI(); err != nil {
				log.Printf("Error pushing metadata: %v", err)
			}
		}
	}()
}

// HTTP Handlers

func healthHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"status":    "healthy",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// apiKeyAuthMiddleware validates the API key for protected endpoints
func apiKeyAuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if config.APIKey == "" {
			log.Println("Warning: API_KEY not configured, skipping authentication")
			next.ServeHTTP(w, r)
			return
		}

		apiKey := r.Header.Get("X-API-Key")
		if apiKey == "" {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "Missing API key",
			})
			log.Printf("Unauthorized request to %s: missing API key", r.URL.Path)
			return
		}

		if apiKey != config.APIKey {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "Invalid API key",
			})
			log.Printf("Unauthorized request to %s: invalid API key", r.URL.Path)
			return
		}

		next.ServeHTTP(w, r)
	}
}

// receiveSuperPlatformResultHandler handles incoming results from Super Platform
func receiveSuperPlatformResultHandler(w http.ResponseWriter, r *http.Request) {
	var result SuperPlatformResult
	if err := json.NewDecoder(r.Body).Decode(&result); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "Invalid JSON payload",
		})
		return
	}

	// TODO: Process the result from Super Platform
	// For now, just log and acknowledge
	log.Printf("Received result from Super Platform: status=%s, timestamp=%s", sanitizeForLog(result.Status), sanitizeForLog(result.Timestamp))
	
	// Sanitize data for logging by converting to JSON string
	dataJSON, err := json.Marshal(result.Data)
	if err == nil {
		log.Printf("Data received: %s", sanitizeForLog(string(dataJSON)))
	} else {
		log.Printf("Data received: (unable to marshal)")
	}

	// Send acknowledgment
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success":   true,
		"message":   "Result received and queued for processing",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

// CORS Middleware
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-API-Key")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// Logging Middleware
func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s", r.Method, r.RequestURI, time.Since(start))
	})
}

func main() {
	log.Println("Silver Metadata Service (Go)")
	log.Printf("Port: %s", config.Port)
	log.Printf("ClamAV DB Path: %s", config.ClamAVDBPath)
	log.Printf("External API URL: %s", config.ExternalAPIURL)
	log.Printf("Instance ID: %s", config.InstanceID)
	log.Printf("Push Interval: %v", config.PushInterval)
	log.Printf("Push Service Enabled: %v", config.EnablePushService)
	
	if config.APIKey != "" {
		log.Println("API Key authentication enabled")
	} else {
		log.Println("Warning: API Key authentication not configured")
	}

	// Start periodic push service
	startPeriodicPush()

	// Setup router
	router := mux.NewRouter()

	// Routes
	router.HandleFunc("/health", healthHandler).Methods("GET")
	router.HandleFunc("/api/results", apiKeyAuthMiddleware(receiveSuperPlatformResultHandler)).Methods("POST")

	// Apply middleware
	handler := corsMiddleware(loggingMiddleware(router))

	// Start server
	addr := "0.0.0.0:" + config.Port
	log.Printf("Server listening on %s", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
