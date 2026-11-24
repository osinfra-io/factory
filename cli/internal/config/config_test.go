package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadMissingFileDefaultsToLocal(t *testing.T) {
	cfg, err := Load(filepath.Join(t.TempDir(), "none.json"))
	if err != nil {
		t.Fatal(err)
	}

	env, err := cfg.Environment(DefaultEnvironment)
	if err != nil || env.URL == "" {
		t.Fatalf("local environment = %+v, %v", env, err)
	}
}

func TestLoadFileAndUnknownEnvironment(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(`{"environments":{"sandbox":{"url":"https://floor.example/mcp"}}}`), 0o600); err != nil {
		t.Fatal(err)
	}

	cfg, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}

	if env, err := cfg.Environment("sandbox"); err != nil || env.URL != "https://floor.example/mcp" {
		t.Fatalf("sandbox = %+v, %v", env, err)
	}

	if _, err := cfg.Environment("prod"); err == nil {
		t.Fatal("expected error for unknown environment")
	}
}

func TestLoadInvalidJSON(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(`{`), 0o600); err != nil {
		t.Fatal(err)
	}

	if _, err := Load(path); err == nil {
		t.Fatal("expected parse error")
	}
}
