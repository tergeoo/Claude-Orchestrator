package agent

import (
	"fmt"
	"os"

	"github.com/google/uuid"
)

// Config holds agent configuration. Populated from environment variables.
type Config struct {
	AgentID        string
	Name           string
	Secret         string
	RelayURL       string
	DefaultCommand string
}

// Validate fills defaults and returns an error if required fields are missing.
func (c *Config) Validate() error {
	if c.AgentID == "" {
		c.AgentID = uuid.New().String()
	}
	if c.Name == "" {
		c.Name, _ = os.Hostname()
	}
	if c.DefaultCommand == "" {
		c.DefaultCommand = "bash"
	}
	if c.RelayURL == "" || c.Secret == "" {
		return fmt.Errorf("RELAY_URL and AGENT_SECRET are required\n\n" +
			"Set them in agent/.env (dev) or in the launchd plist EnvironmentVariables (production).\n\n" +
			"Or pass as flags:\n  claude-agent --relay ws://HOST:8080 --secret SECRET")
	}
	return nil
}
