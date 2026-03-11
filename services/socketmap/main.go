package main

import (
	"log"
	"time"

	"socketmap/config"
	"socketmap/internal/cache"
	"socketmap/internal/server"
	"socketmap/internal/thunder"
)

func main() {
	log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds)
	log.Println("╔════════════════════════════════════════════════════════════╗")
	log.Println("║       Socketmap Service - Postfix Virtual Mailbox Maps    ║")
	log.Println("╚════════════════════════════════════════════════════════════╝")
	log.Println("")

	// Load configuration
	cfg := config.Load()

	// Authenticate with Thunder at startup
	log.Println("┌─ Thunder Authentication ─────────")
	auth, err := thunder.Authenticate(cfg.ThunderHost, cfg.ThunderPort, cfg.TokenRefreshSeconds)
	if err != nil {
		log.Printf("│ ⚠ Initial authentication failed: %v", err)
		log.Printf("│ Service will attempt to authenticate on first request")
		log.Println("└───────────────────────────────────")
	} else {
		thunder.SetAuth(auth)
		log.Println("└───────────────────────────────────")
	}
	log.Println("")

	// Start token refresh goroutine
	go func() {
		ticker := time.NewTicker(time.Duration(cfg.TokenRefreshSeconds) * time.Second)
		defer ticker.Stop()
		
		for range ticker.C {
			log.Println("⏰ Token refresh timer triggered")
			newAuth, err := thunder.Authenticate(cfg.ThunderHost, cfg.ThunderPort, cfg.TokenRefreshSeconds)
			if err != nil {
				log.Printf("⚠ Token refresh failed: %v", err)
			} else {
				thunder.SetAuth(newAuth)
				log.Println("✓ Token refreshed successfully")
			}
		}
	}()

	// Initialize cache
	cacheManager := cache.New(cfg.CacheTTLSeconds)

	// Display configuration
	log.Printf("Starting socketmap service on %s:%s", cfg.Host, cfg.Port)
	log.Printf("Configuration:")
	log.Printf("  • Thunder Host: %s:%s", cfg.ThunderHost, cfg.ThunderPort)
	log.Printf("  • Cache TTL: %d seconds", cfg.CacheTTLSeconds)
	log.Printf("  • Token Refresh: %d seconds", cfg.TokenRefreshSeconds)
	log.Println("")

	// Create and start server
	srv := server.New(cfg, cacheManager)
	if err := srv.Start(); err != nil {
		log.Fatalf("✗ Failed to start server: %v", err)
	}
}
