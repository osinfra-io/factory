// Package floorclient is a typed client for the Floor MCP API.
package floorclient

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/modelcontextprotocol/go-sdk/mcp"

	"github.com/osinfra-io/factory/cli/internal/config"
)

// Workspace mirrors the flattened Terraform object Floor exposes.
type Workspace struct {
	Name                string   `json:"name"`
	Namespace           string   `json:"namespace"`
	Path                string   `json:"path"`
	SourceBranch        string   `json:"sourceBranch"`
	Phase               string   `json:"phase"`
	Message             string   `json:"message,omitempty"`
	PendingPlan         string   `json:"pendingPlan"`
	Approved            bool     `json:"approved"`
	DependsOn           []string `json:"dependsOn,omitempty"`
	ApprovedBy          string   `json:"approvedBy,omitempty"`
	ApprovedAt          string   `json:"approvedAt,omitempty"`
	ApprovedPlan        string   `json:"approvedPlan,omitempty"`
	LastAppliedRevision string   `json:"lastAppliedRevision"`
	Review              string   `json:"review"`
	Destroy             bool     `json:"destroy"`
	PlanOnly            bool     `json:"planOnly"`
	PullRequest         int      `json:"pullRequest"`
	PrimaryResource     string   `json:"primaryResource"`
}

// Ref is the name Floor accepts. Floor already prefixes the namespace for
// workspaces outside its default namespace.
func (w Workspace) Ref() string { return w.Name }

// Running says what the controller is doing right now, "planning" or
// "applying", or "" when it is idle or only initializing.
func (w Workspace) Running() string {
	if w.PendingPlan != "" {
		if w.Approved {
			return "applying"
		}

		return ""
	}

	if w.Phase != "Progressing" {
		return ""
	}

	msg := strings.ToLower(w.Message)

	switch {
	case strings.Contains(msg, "apply"):
		return "applying"
	case strings.Contains(msg, "plan"):
		return "planning"
	default:
		return ""
	}
}

// Status describes the workspace phase in plain words.
func (w Workspace) Status() string {
	if r := w.Running(); r != "" && w.PendingPlan == "" {
		return strings.ToUpper(r[:1]) + r[1:]
	}

	switch {
	case w.PendingPlan != "" && w.Approved:
		return "Approved · waiting to apply"
	case w.PendingPlan != "":
		return "Awaiting approval"
	case w.Phase == "":
		return "Unknown"
	default:
		return w.PhaseText()
	}
}

// phaseText covers every reason tofu-controller reports as a phase.
var phaseText = map[string]string{
	"AccessDenied":                "Access denied",
	"ArtifactFailed":              "Source unavailable",
	"DependencyNotReady":          "Waiting on dependencies",
	"DestroySkipped":              "Deleted without destroying (suspended)",
	"DriftDetected":               "Drift detected",
	"DriftDetectionFailed":        "Drift check failed",
	"FinalizeSecretsFailed":       "Cleanup failed",
	"ForceUnlock":                 "Unlocking state",
	"HealthChecksFailed":          "Health checks failed",
	"LockHeld":                    "State locked",
	"NoDrift":                     "No drift",
	"OutputsWritingFailed":        "Writing outputs failed",
	"PostPlanningWebhookFailed":   "Post-plan webhook failed",
	"Progressing":                 "Up to date",
	"ReconciliationFailed":        "Reconciliation failed",
	"RetryLimitReached":           "Retry limit reached",
	"RunnerFailed":                "Runner failed",
	"RunnerQuotaExhausted":        "Runner quota exhausted",
	"SelectWorkspaceFailed":       "Selecting workspace failed",
	"TFExecApplyFailed":           "Apply failed",
	"TFExecDestroyFailed":         "Destroy failed",
	"TFExecInitFailed":            "Init failed",
	"TFExecNewFailed":             "Setup failed",
	"TFExecOutputFailed":          "Reading outputs failed",
	"TFExecPlanFailed":            "Plan failed",
	"TemplateGenerationFailed":    "Template failed",
	"TerraformAppliedFail":        "Apply failed",
	"TerraformAppliedSucceed":     "Applied",
	"TerraformDestroySucceed":     "Destroyed",
	"TerraformOutputsAvailable":   "Applied",
	"TerraformOutputsWritten":     "Applied",
	"TerraformPlanSucceed":        "Plan ready",
	"TerraformPlannedNoChanges":   "Up to date",
	"TerraformPlannedWithChanges": "Changes planned",
	"VarsGenerationFailed":        "Variables failed",
}

// PhaseText describes the controller phase in plain words, falling back to
// the raw phase for ones it does not know.
func (w Workspace) PhaseText() string {
	if t, ok := phaseText[w.Phase]; ok {
		return t
	}

	if w.Phase == "" {
		return "Unknown"
	}

	return w.Phase
}

// Failed reports whether the controller phase is a failure: a phase named for
// a failure or error, or one where the controller has stopped or been refused.
func (w Workspace) Failed() bool {
	phase := strings.ToLower(w.Phase)

	switch w.Phase {
	case "AccessDenied", "RetryLimitReached", "RunnerQuotaExhausted":
		return true
	}

	return strings.Contains(phase, "fail") || strings.Contains(phase, "error")
}

// Waiting reports that the controller is held back by something outside the
// workspace: its dependencies, or a lock on its state.
func (w Workspace) Waiting() bool {
	switch w.Phase {
	case "DependencyNotReady", "LockHeld", "ForceUnlock":
		return true
	}

	return false
}

// ShortRevision reduces a revision such as "main@sha1:7ed51fad…" to its
// first seven hex characters.
func ShortRevision(rev string) string {
	if i := strings.LastIndex(rev, ":"); i >= 0 {
		rev = rev[i+1:]
	}

	return rev[:min(len(rev), 7)]
}

// ShortPlan trims the plan ID to its revision, dropping the long prefix.
func (w Workspace) ShortPlan() string {
	i := strings.LastIndex(w.PendingPlan, "-")
	if i < 0 {
		return w.PendingPlan
	}

	return w.PendingPlan[i+1:]
}

// Client calls Floor tools over streamable HTTP.
type Client struct {
	endpoint string
	http     *http.Client
}

// Transport returns the base transport for env: the localhost dialer plus any
// extra CA roots.
func Transport(env config.Environment) (http.RoundTripper, error) {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.DialContext = localhostDialer(&net.Dialer{Timeout: 10 * time.Second})

	if env.CAFile != "" {
		pem, err := os.ReadFile(env.CAFile)
		if err != nil {
			return nil, err
		}

		pool, err := x509.SystemCertPool()
		if err != nil || pool == nil {
			pool = x509.NewCertPool()
		}

		if !pool.AppendCertsFromPEM(pem) {
			return nil, fmt.Errorf("no certificates found in %s", env.CAFile)
		}

		transport.TLSClientConfig = &tls.Config{RootCAs: pool, MinVersion: tls.VersionTLS12}
	}

	return transport, nil
}

// New builds a client for env. Basic auth is used when the environment
// configures an app password; otherwise wrap, when given, adds credentials.
func New(env config.Environment, wrap ...func(http.RoundTripper) http.RoundTripper) (*Client, error) {
	transport, err := Transport(env)
	if err != nil {
		return nil, err
	}

	rt := transport

	switch {
	case env.Username != "":
		raw, err := os.ReadFile(env.PasswordFile)
		if err != nil {
			return nil, fmt.Errorf("reading password file: %w", err)
		}

		rt = basicAuth{user: env.Username, password: strings.TrimSpace(string(raw)), next: transport}
	case len(wrap) > 0 && wrap[0] != nil:
		rt = wrap[0](transport)
	}

	return &Client{
		endpoint: env.URL,
		http:     &http.Client{Transport: rt, Timeout: 30 * time.Second},
	}, nil
}

type basicAuth struct {
	user, password string
	next           http.RoundTripper
}

func (b basicAuth) RoundTrip(r *http.Request) (*http.Response, error) {
	r = r.Clone(r.Context())
	r.SetBasicAuth(b.user, b.password)

	return b.next.RoundTrip(r)
}

// ListWorkspaces returns every workspace Floor can see.
func (c *Client) ListWorkspaces(ctx context.Context) ([]Workspace, error) {
	var out struct {
		Workspaces []Workspace `json:"workspaces"`
	}

	if err := c.call(ctx, "list_workspaces", map[string]any{}, &out); err != nil {
		return nil, err
	}

	return out.Workspaces, nil
}

// GetWorkspace returns a single workspace by namespace/name.
func (c *Client) GetWorkspace(ctx context.Context, name string) (Workspace, error) {
	var out struct {
		Workspace Workspace `json:"workspace"`
	}

	err := c.call(ctx, "get_workspace", map[string]any{"name": name}, &out)

	return out.Workspace, err
}

// Approve approves the pending plan identified by planID.
func (c *Client) Approve(ctx context.Context, name, planID string, acknowledgeDestroys bool) (string, error) {
	var out struct {
		Message string `json:"message"`
	}

	err := c.call(ctx, "approve", map[string]any{
		"name": name, "planId": planID, "acknowledgeDestroys": acknowledgeDestroys,
	}, &out)

	return out.Message, err
}

// Reject records a rejection of the pending plan.
func (c *Client) Reject(ctx context.Context, name, reason string) (string, error) {
	var out struct {
		Message string `json:"message"`
	}

	err := c.call(ctx, "reject", map[string]any{"name": name, "reason": reason}, &out)

	return out.Message, err
}

func (c *Client) call(ctx context.Context, tool string, args map[string]any, out any) error {
	client := mcp.NewClient(&mcp.Implementation{Name: "factory-cli", Version: "0.1.0"}, nil)

	session, err := client.Connect(ctx, &mcp.StreamableClientTransport{Endpoint: c.endpoint, HTTPClient: c.http}, nil)
	if err != nil {
		return fmt.Errorf("connecting to floor: %w", err)
	}
	defer func() { _ = session.Close() }()

	res, err := session.CallTool(ctx, &mcp.CallToolParams{Name: tool, Arguments: args})
	if err != nil {
		return err
	}

	if res.IsError {
		return errors.New(toolText(res))
	}

	raw, err := json.Marshal(res.StructuredContent)
	if err != nil {
		return err
	}

	return json.Unmarshal(raw, out)
}

func toolText(res *mcp.CallToolResult) string {
	for _, c := range res.Content {
		if t, ok := c.(*mcp.TextContent); ok {
			return t.Text
		}
	}

	return "floor returned an error"
}

// localhostDialer resolves *.localhost to loopback itself (RFC 6761), since
// not every system resolver does.
func localhostDialer(d *net.Dialer) func(context.Context, string, string) (net.Conn, error) {
	return func(ctx context.Context, network, addr string) (net.Conn, error) {
		if host, port, err := net.SplitHostPort(addr); err == nil && strings.HasSuffix(host, ".localhost") {
			addr = net.JoinHostPort("127.0.0.1", port)
		}

		return d.DialContext(ctx, network, addr)
	}
}
