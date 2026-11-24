package floorclient

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/modelcontextprotocol/go-sdk/mcp"

	"github.com/osinfra-io/factory/cli/internal/config"
)

var errTest = errors.New("boom")

type nameIn struct {
	Name string `json:"name"`
}

type wsOut struct {
	Workspaces []Workspace `json:"workspaces"`
}

type msgOut struct {
	Message string `json:"message"`
}

func fakeFloor(t *testing.T) *Client {
	t.Helper()

	srv := mcp.NewServer(&mcp.Implementation{Name: "fake", Version: "0"}, nil)

	mcp.AddTool(srv, &mcp.Tool{Name: "list_workspaces", Description: "list"},
		func(context.Context, *mcp.CallToolRequest, struct{}) (*mcp.CallToolResult, wsOut, error) {
			return nil, wsOut{Workspaces: []Workspace{{Name: "bootstrap-sandbox/seed", Namespace: "bootstrap-sandbox", PendingPlan: "plan-bootstrap-branch-0116683fcc"}}}, nil
		})
	mcp.AddTool(srv, &mcp.Tool{Name: "reject", Description: "reject"},
		func(_ context.Context, _ *mcp.CallToolRequest, in struct {
			Name   string `json:"name"`
			Reason string `json:"reason"`
		}) (*mcp.CallToolResult, msgOut, error) {
			return nil, msgOut{Message: "rejected " + in.Name + ": " + in.Reason}, nil
		})
	mcp.AddTool(srv, &mcp.Tool{Name: "get_workspace", Description: "get"},
		func(_ context.Context, _ *mcp.CallToolRequest, in nameIn) (*mcp.CallToolResult, struct {
			Workspace Workspace `json:"workspace"`
		}, error) {
			return nil, struct {
				Workspace Workspace `json:"workspace"`
			}{}, errTest
		})

	ts := httptest.NewServer(mcp.NewStreamableHTTPHandler(func(*http.Request) *mcp.Server { return srv }, nil))
	t.Cleanup(ts.Close)

	c, err := New(config.Environment{URL: ts.URL})
	if err != nil {
		t.Fatal(err)
	}

	return c
}

func TestListAndReject(t *testing.T) {
	c := fakeFloor(t)

	list, err := c.ListWorkspaces(context.Background())
	if err != nil || len(list) != 1 || list[0].Ref() != "bootstrap-sandbox/seed" {
		t.Fatalf("list = %+v, %v", list, err)
	}

	msg, err := c.Reject(context.Background(), "bootstrap-sandbox/seed", "nope")
	if err != nil || msg != "rejected bootstrap-sandbox/seed: nope" {
		t.Fatalf("reject = %q, %v", msg, err)
	}
}

func TestToolErrorSurfaces(t *testing.T) {
	if _, err := fakeFloor(t).GetWorkspace(context.Background(), "x"); err == nil {
		t.Fatal("expected tool error")
	}
}

func TestStatusAndShortPlan(t *testing.T) {
	w := Workspace{Phase: "TerraformPlannedWithChanges", PendingPlan: "plan-bootstrap-branch-0116683fcc"}
	if w.Status() != "Awaiting approval" || w.ShortPlan() != "0116683fcc" {
		t.Fatalf("status=%q plan=%q", w.Status(), w.ShortPlan())
	}

	if got := (Workspace{Phase: "Progressing"}).Status(); got != "Up to date" {
		t.Fatalf("status = %q", got)
	}
}

func TestEveryPhaseHasAPlainLabelAndAKind(t *testing.T) {
	for phase, failed := range map[string]bool{"TFExecInitFailed": true, "RetryLimitReached": true, "AccessDenied": true, "LockHeld": false, "DriftDetected": false} {
		w := Workspace{Phase: phase}
		if w.Failed() != failed || w.PhaseText() == phase {
			t.Fatalf("%s: failed=%v text=%q", phase, w.Failed(), w.PhaseText())
		}
	}

	if !(Workspace{Phase: "LockHeld"}).Waiting() || (Workspace{Phase: "DriftDetected"}).Waiting() {
		t.Fatal("a held lock waits; drift does not")
	}
}

func TestRunningDistinguishesPlanningFromApplying(t *testing.T) {
	cases := []struct {
		w    Workspace
		want string
	}{
		{Workspace{Phase: "Progressing", Message: "Terraform Planning"}, "planning"},
		{Workspace{Phase: "Progressing", Message: "Terraform Applying"}, "applying"},
		{Workspace{Phase: "Progressing", Message: "Initializing"}, ""},
		{Workspace{Phase: "TerraformPlannedWithChanges", PendingPlan: "p", Approved: true}, "applying"},
		{Workspace{Phase: "TerraformPlannedWithChanges", PendingPlan: "p"}, ""},
	}

	for _, c := range cases {
		if got := c.w.Running(); got != c.want {
			t.Errorf("%+v = %q, want %q", c.w, got, c.want)
		}
	}
}
