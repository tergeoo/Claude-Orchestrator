package main

import (
	"log"
	"net/http"
	"os"
	"time"

	relay "github.com/claude-orchestrator/relay"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		log.Fatal("JWT_SECRET environment variable is required")
	}
	adminPassword := os.Getenv("ADMIN_PASSWORD")
	if adminPassword == "" {
		log.Fatal("ADMIN_PASSWORD environment variable is required")
	}
	agentSecret := os.Getenv("AGENT_SECRET")
	if agentSecret == "" {
		log.Fatal("AGENT_SECRET environment variable is required")
	}

	hub := relay.NewHub()
	go hub.Run()

	auth := relay.NewAuth(jwtSecret, adminPassword)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	mux.HandleFunc("/auth/login", auth.LoginHandler)
	mux.HandleFunc("/auth/refresh", auth.RefreshHandler)
	mux.HandleFunc("/ws/agent", func(w http.ResponseWriter, r *http.Request) {
		relay.HandleAgentWS(w, r, hub, agentSecret)
	})
	mux.HandleFunc("/ws/client", func(w http.ResponseWriter, r *http.Request) {
		relay.HandleClientWS(w, r, hub, auth)
	})

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 0,
		IdleTimeout:  120 * time.Second,
	}

	log.Printf("Relay server starting on :%s", port)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
