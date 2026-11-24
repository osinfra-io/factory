// Command factory is the terminal UI for managing Factory through Floor.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/osinfra-io/factory/cli/internal/auth"
	"github.com/osinfra-io/factory/cli/internal/config"
	"github.com/osinfra-io/factory/cli/internal/floorclient"
	"github.com/osinfra-io/factory/cli/internal/gitlog"
	"github.com/osinfra-io/factory/cli/internal/plan"
	"github.com/osinfra-io/factory/cli/internal/tui"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "factory:", err)
		os.Exit(1)
	}
}

func run() error {
	args := os.Args[1:]

	login := len(args) > 0 && args[0] == "login"
	if login {
		args = args[1:]
	}

	fs := flag.NewFlagSet("factory", flag.ExitOnError)
	envName := fs.String("env", config.DefaultEnvironment, "environment to connect to (local, sandbox, non-production, production)")
	path := fs.String("config", "", "config file (default: user config dir/factory/config.json)")
	_ = fs.Parse(args)

	if *path == "" {
		p, err := config.DefaultPath()
		if err != nil {
			return err
		}

		*path = p
	}

	cfg, err := config.Load(*path)
	if err != nil {
		return err
	}

	if login {
		return signInTo(cfg, *envName)
	}

	api, err := connect(cfg, *envName)
	if err != nil {
		return err
	}

	names := make([]string, 0, len(cfg.Environments))
	for name := range cfg.Environments {
		names = append(names, name)
	}

	sort.Strings(names)

	info := map[string]string{}

	for name, env := range cfg.Environments {
		info[name] = describe(env)
	}

	model := tui.New(api, *envName).WithInfo(info).WithEnvironments(names, func(name string) (tui.API, error) { return connect(cfg, name) })

	_, err = tea.NewProgram(model, tea.WithAltScreen(), tea.WithMouseCellMotion()).Run()

	return err
}

// signInTo runs the interactive sign-in for one environment.
func signInTo(cfg config.Config, name string) error {
	env, err := cfg.Environment(name)
	if err != nil {
		return err
	}

	if env.OIDC == nil || env.Username != "" {
		return fmt.Errorf("environment %q does not use interactive sign-in (no oidc config, or an app password is set)", name)
	}

	tokenPath, err := auth.TokenPath(name)
	if err != nil {
		return err
	}

	base, err := floorclient.Transport(env)
	if err != nil {
		return err
	}

	return signIn(auth.New(*env.OIDC, base, tokenPath), name)
}

// connect builds the backend for one environment.
func connect(cfg config.Config, name string) (backend, error) {
	env, err := cfg.Environment(name)
	if err != nil {
		return backend{}, err
	}

	var wrap func(http.RoundTripper) http.RoundTripper

	if env.OIDC != nil && env.Username == "" {
		tokenPath, err := auth.TokenPath(name)
		if err != nil {
			return backend{}, err
		}

		base, err := floorclient.Transport(env)
		if err != nil {
			return backend{}, err
		}

		wrap = func(next http.RoundTripper) http.RoundTripper {
			return auth.Bearer{Auth: auth.New(*env.OIDC, base, tokenPath), Next: next}
		}
	}

	client, err := floorclient.New(env, wrap)
	if err != nil {
		return backend{}, err
	}

	b := backend{Client: client}
	if env.KubeContext != "" {
		b.reader = plan.NewReader(env.KubeContext)
	}

	b.repoDir = factoryCheckout()
	b.local = env.KubeContext == "docker-desktop"

	return b, nil
}

func signIn(a *auth.Authenticator, env string) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	err := a.Login(ctx, func(link string) {
		fmt.Printf("Open this URL in your browser and sign in with Google:\n\n%s\n\nWaiting for sign-in...\n", link)
	})
	if err != nil {
		return err
	}

	fmt.Printf("Signed in to %s.\n", env)

	return nil
}

// backend serves workspaces and approvals from Floor and plan contents from
// the cluster, when the environment has a kube context.
type backend struct {
	*floorclient.Client

	reader *plan.Reader
	// repoDir is the Factory checkout whose prepare.sh renews local tokens.
	repoDir string
	local   bool
}

// TokenExpiry tells when the runner's Google token in namespace expires.
func (b backend) TokenExpiry(ctx context.Context, namespace string) (time.Time, error) {
	if b.reader == nil {
		return time.Time{}, tui.ErrPlanUnavailable
	}

	return b.reader.TokenExpiry(ctx, namespace)
}

// RenewToken reruns bootstrap/seed/prepare.sh for the environment that owns
// namespace, which writes a fresh Google token for its runner.
func (b backend) RenewToken(ctx context.Context, namespace string) error {
	environment, ok := strings.CutPrefix(namespace, "bootstrap-")
	if !ok || !b.local || b.repoDir == "" {
		return errors.New("renewal is only available for local bootstrap workspaces")
	}

	cmd := exec.CommandContext(ctx, "bash", "bootstrap/seed/prepare.sh", environment)
	cmd.Dir = b.repoDir

	if out, err := cmd.CombinedOutput(); err != nil {
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")

		return fmt.Errorf("prepare.sh failed: %s", lines[len(lines)-1])
	}

	return nil
}

// CommitLog describes the commits between two revisions of a workspace's
// source, from the local Factory checkout.
func (b backend) CommitLog(ctx context.Context, from, to, path string) (gitlog.Log, error) {
	return gitlog.Read(ctx, b.repoDir, from, to, path)
}

// CommitDiff returns the code diff behind a workspace's revision range.
func (b backend) CommitDiff(ctx context.Context, from, to, path, file string) ([]string, int, error) {
	return gitlog.Diff(ctx, b.repoDir, from, to, path, file)
}

// ApplyActivity reads what the runner applying name has reported.
func (b backend) ApplyActivity(ctx context.Context, namespace, name string) (plan.Activity, error) {
	if b.reader == nil {
		return plan.Activity{}, tui.ErrPlanUnavailable
	}

	return b.reader.ApplyActivity(ctx, namespace, name)
}

func (b backend) ReadPlan(ctx context.Context, namespace, name string) (plan.Plan, error) {
	if b.reader == nil {
		return plan.Plan{}, tui.ErrPlanUnavailable
	}

	return b.reader.Read(ctx, namespace, name)
}

// describe summarises where an environment's Floor and cluster are.
func describe(env config.Environment) string {
	host := env.URL
	if u, err := url.Parse(env.URL); err == nil && u.Host != "" {
		host = u.Host
	}

	if env.KubeContext != "" {
		return env.KubeContext + " · " + host
	}

	return host
}

// factoryCheckout returns the repository root when run inside a Factory
// checkout, or an empty string.
func factoryCheckout() string {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return ""
	}

	dir := strings.TrimSpace(string(out))
	if _, err := os.Stat(filepath.Join(dir, "bootstrap", "seed", "prepare.sh")); err != nil {
		return ""
	}

	return dir
}
