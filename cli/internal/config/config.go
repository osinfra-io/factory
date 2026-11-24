// Package config loads the named Floor environments the CLI can connect to.
package config

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

// DefaultEnvironment is used when no environment is selected.
const DefaultEnvironment = "local"

// Environment describes how to reach one Floor.
type Environment struct {
	// URL is the Floor MCP endpoint.
	URL string `json:"url"`

	// CAFile is an optional PEM bundle trusted in addition to system roots.
	CAFile string `json:"caFile,omitempty"`

	// KubeContext is the kubectl context used to read plan contents. Without
	// it plans cannot be reviewed, so approval is disabled.
	KubeContext string `json:"kubeContext,omitempty"`

	// OIDC enables interactive sign-in through authentik (`factory login`).
	OIDC *OIDC `json:"oidc,omitempty"`

	// Username and PasswordFile configure authentik app-password auth, the
	// non-interactive fallback to the OIDC login.
	Username     string `json:"username,omitempty"`
	PasswordFile string `json:"passwordFile,omitempty"`
}

// OIDC identifies the authentik provider the CLI signs in with.
type OIDC struct {
	Issuer   string `json:"issuer"`
	ClientID string `json:"clientId"`

	// ExchangeClientID is the Floor proxy provider's client ID. The login
	// token is exchanged for one issued to it, which the outpost accepts.
	ExchangeClientID string `json:"exchangeClientId,omitempty"`
}

// Config maps environment names to their Floor.
type Config struct {
	Environments map[string]Environment `json:"environments"`
}

// DefaultPath returns the config file location under the user config dir.
func DefaultPath() (string, error) {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}

	return filepath.Join(dir, "factory", "config.json"), nil
}

// Load reads the config at path. A missing file yields the built-in local
// environment only.
func Load(path string) (Config, error) {
	cfg := Config{Environments: map[string]Environment{}}

	data, err := os.ReadFile(path)

	switch {
	case errors.Is(err, os.ErrNotExist):
	case err != nil:
		return cfg, err
	default:
		if err := json.Unmarshal(data, &cfg); err != nil {
			return cfg, fmt.Errorf("parsing %s: %w", path, err)
		}
	}

	if _, ok := cfg.Environments[DefaultEnvironment]; !ok {
		cfg.Environments[DefaultEnvironment] = Environment{
			URL:         "https://floor.localhost/mcp",
			KubeContext: "docker-desktop",
			OIDC:        &OIDC{Issuer: "https://authentik.localhost/application/o/factory-cli/", ClientID: "factory-cli"},
		}
	}

	return cfg, nil
}

// Environment returns the named environment.
func (c Config) Environment(name string) (Environment, error) {
	env, ok := c.Environments[name]
	if !ok {
		return Environment{}, fmt.Errorf("unknown environment %q", name)
	}

	if env.URL == "" {
		return Environment{}, fmt.Errorf("environment %q has no url", name)
	}

	return env, nil
}
