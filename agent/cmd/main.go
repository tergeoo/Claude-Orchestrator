package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/claude-orchestrator/agent"
)

func main() {
	var (
		relay  = flag.String("relay", "", "Override RELAY_URL env var")
		secret = flag.String("secret", "", "Override AGENT_SECRET env var")
		name   = flag.String("name", "", "Override AGENT_NAME env var")
	)
	flag.Parse()

	cfg := agent.Config{
		AgentID:        os.Getenv("AGENT_ID"),
		Name:           os.Getenv("AGENT_NAME"),
		Secret:         os.Getenv("AGENT_SECRET"),
		RelayURL:       os.Getenv("RELAY_URL"),
		DefaultCommand: os.Getenv("DEFAULT_COMMAND"),
	}

	if *relay != "" {
		cfg.RelayURL = *relay
	}
	if *secret != "" {
		cfg.Secret = *secret
	}
	if *name != "" {
		cfg.Name = *name
	}

	if err := cfg.Validate(); err != nil {
		log.Fatal(err)
	}

	log.Printf("Starting Claude Agent")
	log.Printf("  Agent ID: %s", cfg.AgentID)
	log.Printf("  Name:     %s", cfg.Name)
	log.Printf("  Relay:    %s", cfg.RelayURL)
	log.Printf("  Command:  %s", cfg.DefaultCommand)

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	agent.NewWSClient(cfg).Run(ctx)

	log.Println("Agent stopped.")
}
