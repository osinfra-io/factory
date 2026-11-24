package tui

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"

	"github.com/osinfra-io/factory/cli/internal/floorclient"
	"github.com/osinfra-io/factory/cli/internal/gitlog"
	"github.com/osinfra-io/factory/cli/internal/plan"
)

type fakeAPI struct {
	plan     plan.Plan
	planErr  error
	approved []string
	rejected []string
}

func (f *fakeAPI) ListWorkspaces(context.Context) ([]floorclient.Workspace, error) {
	return nil, nil
}

func (f *fakeAPI) ReadPlan(context.Context, string, string) (plan.Plan, error) {
	return f.plan, f.planErr
}

func (f *fakeAPI) Approve(_ context.Context, name, planID string, _ bool) (string, error) {
	f.approved = append(f.approved, name+"@"+planID)

	return "approved", nil
}

func (f *fakeAPI) Reject(_ context.Context, name, _ string) (string, error) {
	f.rejected = append(f.rejected, name)

	return "rejected", nil
}

func press(m Model, k string) (Model, tea.Cmd) {
	var msg tea.KeyMsg

	switch k {
	case "esc":
		msg = tea.KeyMsg{Type: tea.KeyEsc}
	case "enter":
		msg = tea.KeyMsg{Type: tea.KeyEnter}
	default:
		msg = tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(k)}
	}

	next, cmd := m.Update(msg)

	return next.(Model), cmd
}

func down(m Model) Model {
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyDown})

	return next.(Model)
}

func loaded(api *fakeAPI) Model {
	m := New(api, "local")
	next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{
		{Name: "ns/idle", Namespace: "ns"},
		{Name: "ns/seed", Namespace: "ns", PendingPlan: "plan-1"},
	}})
	next, _ = next.(Model).Update(planMsg{ref: "ns/seed", id: "plan-1", plan: api.plan, err: api.planErr})

	return next.(Model)
}

func newAPI() *fakeAPI {
	return &fakeAPI{plan: plan.Plan{ID: "plan-1", SHA256: "aa", Changes: []plan.Change{{Address: "a.b", Actions: []string{"create"}}}}}
}

func TestApproveRequiresReviewedPlanAndConfirmation(t *testing.T) {
	api := newAPI()
	m := loaded(api)

	if got := len(m.visible()); got != 1 {
		t.Fatalf("pending visible = %d, want 1", got)
	}

	m, cmd := press(m, "a")
	if m.mode != modeConfirmApprove || cmd != nil || len(api.approved) != 0 {
		t.Fatal("approve must wait for confirmation")
	}

	m, _ = press(m, "esc")
	if m.mode != modeList || len(api.approved) != 0 {
		t.Fatal("cancel must not approve")
	}

	m, _ = press(m, "a")
	_, cmd = press(m, "y")

	if cmd == nil {
		t.Fatal("expected approve command")
	}

	cmd()

	if len(api.approved) != 1 || api.approved[0] != "ns/seed@plan-1" {
		t.Fatalf("approved = %v", api.approved)
	}
}

func TestApproveRefusedWhenPlanChanged(t *testing.T) {
	api := newAPI()
	m, _ := press(loaded(api), "a")
	_, cmd := press(m, "y")

	api.plan.SHA256 = "bb"

	if _, ok := cmd().(actionMsg); !ok || len(api.approved) != 0 {
		t.Fatalf("changed plan must not be approved: %v", api.approved)
	}
}

func TestApproveDisabledWithoutPlan(t *testing.T) {
	api := newAPI()
	api.planErr = ErrPlanUnavailable

	m, _ := press(loaded(api), "a")
	if m.mode != modeList || m.err == nil {
		t.Fatalf("mode=%v err=%v", m.mode, m.err)
	}
}

func TestDestroyingPlanNeedsCapitalD(t *testing.T) {
	api := newAPI()
	api.plan.Changes = []plan.Change{{Address: "a.b", Actions: []string{"delete"}}}

	m, _ := press(loaded(api), "a")

	if m, cmd := press(m, "y"); cmd != nil || m.mode != modeList {
		t.Fatal("y must not approve a destroying plan")
	}

	m, _ = press(loaded(api), "a")
	if _, cmd := press(m, "D"); cmd == nil {
		t.Fatal("D should approve")
	}
}

func TestApproveWithoutPendingPlan(t *testing.T) {
	m := loaded(newAPI())
	m, _ = press(m, "p")
	m = down(m)
	m, _ = press(m, "a")

	if m.mode != modeList || m.status == "" {
		t.Fatalf("mode=%v status=%q", m.mode, m.status)
	}
}

func TestReject(t *testing.T) {
	api := newAPI()
	m, _ := press(loaded(api), "r")
	_, cmd := press(m, "y")
	cmd()

	if len(api.rejected) != 1 || api.rejected[0] != "ns/seed" {
		t.Fatalf("rejected = %v", api.rejected)
	}
}

func clickAt(m Model, x, y int) (Model, tea.Cmd) {
	next, cmd := m.Update(tea.MouseMsg{X: x, Y: y, Button: tea.MouseButtonLeft, Action: tea.MouseActionPress})

	return next.(Model), cmd
}

func TestErrorFooterWrapsWithinFrame(t *testing.T) {
	m := loaded(newAPI())
	m.width, m.height = 80, 24
	message := "connecting to floor: " + strings.Repeat("authentication failed ", 9) + strings.Repeat("界", 40)
	m.err = errors.New(message)

	footer, hits := m.footer(m.size())
	lines := strings.Split(ansi.Strip(footer), "\n")
	compact := func(s string) string { return strings.Join(strings.Fields(s), "") }
	if got, want := compact(strings.Join(lines[:len(lines)-2], "")), compact("Error: "+message); got != want {
		t.Fatalf("wrapped error = %q, want %q", got, want)
	}
	if len(lines) < 3 {
		t.Fatalf("error did not wrap: %q", footer)
	}
	for _, line := range lines {
		if lipgloss.Width(line) > m.width {
			t.Fatalf("footer line exceeds terminal width: %q", line)
		}
	}
	for _, hit := range hits {
		if hit.y0 != m.height-1 || hit.x1 > m.width {
			t.Fatalf("footer hit outside visible row: %+v", hit)
		}
	}
	frame, _ := m.frame()
	if got := lipgloss.Height(frame); got != m.height {
		t.Fatalf("frame height = %d, want %d", got, m.height)
	}
}

func TestMouseCanBeReleasedForTextSelection(t *testing.T) {
	m := loaded(newAPI())
	m.err = errors.New("connection failed")
	var cmd tea.Cmd
	m, cmd = press(m, "M")
	if !m.mouseReleased || cmd == nil {
		t.Fatal("M should release the mouse")
	}
	disabled := cmd()
	footer, _ := m.footer(m.size())
	if !strings.Contains(ansi.Strip(footer), "M restore mouse") {
		t.Fatalf("missing restore hint: %q", footer)
	}
	m, cmd = press(m, "M")
	if m.mouseReleased || cmd == nil {
		t.Fatal("M should restore the mouse")
	}
	if enabled := cmd(); fmt.Sprintf("%T", disabled) == fmt.Sprintf("%T", enabled) {
		t.Fatal("mouse release and restore must send different commands")
	}
}

func TestLongErrorFooterScrollsAndResets(t *testing.T) {
	m := loaded(newAPI())
	m.width, m.height = 60, 16
	m.err = errors.New("first " + strings.Repeat("middle ", 150) + "last")

	footer, _ := m.footer(m.size())
	if !strings.Contains(ansi.Strip(footer), "[/] scroll") || !strings.Contains(ansi.Strip(footer), "first") {
		t.Fatalf("missing first page or scroll hint: %q", footer)
	}
	for i := 0; i < 100; i++ {
		m, _ = press(m, "]")
	}
	footer, _ = m.footer(m.size())
	if !strings.Contains(ansi.Strip(footer), "last") {
		t.Fatalf("missing end of error: %q", footer)
	}
	lastScroll := m.errorScroll
	m, _ = press(m, "[")
	if m.errorScroll != lastScroll-1 {
		t.Fatal("scrolling back from the end should move immediately")
	}
	frame, _ := m.frame()
	if got := lipgloss.Height(frame); got != m.height {
		t.Fatalf("frame height = %d, want %d", got, m.height)
	}
	m.err = errors.New("new first " + strings.Repeat("new middle ", 100) + "new last")
	footer, _ = m.footer(m.size())
	if !strings.Contains(ansi.Strip(footer), "new first") {
		t.Fatalf("new error should start at the beginning: %q", footer)
	}
}

func TestMouseApproveButtonThenConfirmButton(t *testing.T) {
	api := newAPI()
	m := loaded(api)

	m, _ = clickAt(m, 5, headerH+5) // approve on the selected card
	if m.mode != modeConfirmApprove {
		t.Fatalf("mode = %v, want confirm", m.mode)
	}

	_, foot := m.footer(m.size())
	if len(foot) == 0 {
		t.Fatal("confirmation buttons should be clickable")
	}

	_, h := m.size()
	_, cmd := clickAt(m, foot[0].x0, h-1)
	if cmd == nil {
		t.Fatal("clicking the confirm button should approve")
	}

	cmd()

	if len(api.approved) != 1 {
		t.Fatalf("approved = %v", api.approved)
	}
}

func TestMouseIgnoredBehindConfirmation(t *testing.T) {
	m := loaded(newAPI())
	m, _ = press(m, "a")

	m, cmd := clickAt(m, 3, headerH+1)
	if m.mode != modeConfirmApprove || cmd != nil {
		t.Fatal("clicking a card must not change or dismiss a confirmation")
	}
}

func TestMouseTabsAndWheel(t *testing.T) {
	m := loaded(newAPI())

	m, _ = clickAt(m, 38+20, headerH+tabsRow) // Details tab
	if m.tab != tabDetails {
		t.Fatalf("tab = %v", m.tab)
	}

	next, _ := m.Update(tea.MouseMsg{X: 60, Y: 10, Button: tea.MouseButtonWheelDown, Action: tea.MouseActionPress})

	if next.(Model).scroll == 0 {
		t.Fatal("wheel over the pane should scroll it")
	}
}

func TestClickResourceExpandsAndCollapses(t *testing.T) {
	api := newAPI()
	api.plan.Changes[0].Attrs = []plan.Attr{{Name: "name", After: `"web"`, HasAfter: true}}
	m := loaded(api)

	m, _ = clickAt(m, 45, headerH+chromeRows+3)
	if m.open != 1 {
		t.Fatalf("open = %d, want 1", m.open)
	}

	view := m.View()
	if !strings.Contains(view, "name") || !strings.Contains(view, `"web"`) {
		t.Fatalf("attribute changes missing:\n%s", view)
	}

	m, _ = clickAt(m, 45, headerH+chromeRows+3)
	if m.open != 0 {
		t.Fatal("clicking the resource again should collapse it")
	}
}

func TestApprovedWorkspaceStaysVisibleWithBannerUntilDismissed(t *testing.T) {
	api := newAPI()
	m, _ := press(loaded(api), "a")
	m, cmd := press(m, "y")

	if !strings.Contains(m.View(), "Approving") {
		t.Fatal("banner should show the approval in flight")
	}

	next, _ := m.Update(cmd())
	m = next.(Model)

	// Floor no longer lists a pending plan once it is approved.
	next, _ = m.Update(loadedMsg{workspaces: []floorclient.Workspace{{Name: "ns/seed", Namespace: "ns", Phase: "Progressing"}}})
	m = next.(Model)

	if len(m.visible()) != 1 {
		t.Fatal("the approved workspace must stay visible")
	}

	view := m.View()
	if !strings.Contains(view, "applying") || !strings.Contains(view, "a.b") {
		t.Fatalf("want applying banner and the reviewed changes:\n%s", view)
	}

	next, _ = m.Update(loadedMsg{workspaces: []floorclient.Workspace{{Name: "ns/seed", Namespace: "ns", Phase: "Ready", LastAppliedRevision: "abc"}}})
	if !strings.Contains(next.(Model).View(), "Applied") {
		t.Fatal("banner should report the applied revision")
	}

	m, _ = press(next.(Model), "esc")
	if len(m.visible()) != 0 || strings.Contains(m.View(), "Applied") {
		t.Fatal("esc should dismiss the outcome")
	}
}

func TestRefreshAfterApprovalKeepsReviewedPlan(t *testing.T) {
	api := newAPI()
	m, _ := press(loaded(api), "a")
	m, cmd := press(m, "y")
	next, _ := m.Update(cmd())

	// Floor still lists the plan as pending, but its readable copy is gone.
	api.planErr = errors.New("no current pending plan")
	next, _ = next.(Model).Update(loadedMsg{workspaces: []floorclient.Workspace{{Name: "ns/seed", Namespace: "ns", PendingPlan: "plan-1"}}})
	m, cmd = press(next.(Model), "R")

	if cmd == nil {
		t.Fatal("refresh should reload workspaces")
	}

	view := m.View()
	if strings.Contains(view, "unavailable") || !strings.Contains(view, "a.b") {
		t.Fatalf("the reviewed plan should stay on screen:\n%s", view)
	}
}

func TestApprovedWorkspaceFromFloorShowsBannerAndRefusesReapproval(t *testing.T) {
	api := newAPI()
	m := New(api, "local")
	next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{
		{Name: "ns/seed", Namespace: "ns", PendingPlan: "plan-1", Approved: true, Phase: "DependencyNotReady"},
	}})
	next, _ = next.(Model).Update(planMsg{ref: "ns/seed", id: "plan-1", plan: api.plan})

	if !strings.Contains(next.(Model).View(), "waiting to apply") {
		t.Fatal("an approved workspace should say it is waiting to apply")
	}

	m, _ = press(next.(Model), "a")
	if m.mode != modeList || !strings.Contains(m.status, "Already approved") {
		t.Fatal("approving twice must be refused")
	}
}

func TestDependenciesTabShowsTreeAndJumps(t *testing.T) {
	m := New(newAPI(), "local")
	next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{
		{Name: "ns/assembly", Namespace: "ns", DependsOn: []string{"ns/foundation"}, Phase: "DependencyNotReady"},
		{Name: "ns/foundation", Namespace: "ns", DependsOn: []string{"ns/bootstrap"}, Phase: "DependencyNotReady"},
		{Name: "ns/bootstrap", Namespace: "ns", Phase: "TFExecPlanFailed"},
		{Name: "ns/regional", Namespace: "ns", DependsOn: []string{"ns/assembly"}, Phase: "DependencyNotReady"},
	}})
	m = next.(Model)
	m.pendingOnly = false

	m, _ = press(m, "t")

	view := m.View()
	for _, want := range []string{"ns/foundation", "ns/bootstrap", "Plan failed", "Required by", "ns/regional"} {
		if !strings.Contains(view, want) {
			t.Fatalf("dependencies view is missing %q:\n%s", want, view)
		}
	}

	if !m.jumpTo("ns/bootstrap") {
		t.Fatal("expected to jump to the dependency")
	}

	if ws, _ := m.selected(); ws.Ref() != "ns/bootstrap" {
		t.Fatalf("selected %q, want ns/bootstrap", ws.Ref())
	}
}

func TestPlansAreCachedPerWorkspace(t *testing.T) {
	api := newAPI()
	m := New(api, "local")
	next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{
		{Name: "ns/a", Namespace: "ns", PendingPlan: "plan-1"},
		{Name: "ns/b", Namespace: "ns", PendingPlan: "plan-1"},
	}})
	m = next.(Model)

	next, _ = m.Update(planMsg{ref: "ns/a", id: "plan-1", plan: api.plan})
	m = next.(Model)

	if !m.plans["ns/b|plan-1"].loading {
		t.Fatal("a second workspace sharing a plan ID must load its own plan")
	}
}

func TestDetailsExplainRevisionApplyAndApproval(t *testing.T) {
	m := New(newAPI(), "local")
	next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{
		{
			Name: "ns/assembly", Namespace: "ns", PendingPlan: "plan-src-0116683fcc",
			LastAppliedRevision: "src@sha1:7ed51fad89d7", DependsOn: []string{"ns/foundation"},
			ApprovedBy: "brett@osinfra.io", ApprovedAt: "2026-01-02T15:04:05Z",
		},
		{Name: "ns/foundation", Namespace: "ns", Phase: "DependencyNotReady"},
	}})
	m = next.(Model)
	m.pendingOnly = false
	m, _ = press(m, "d")

	view := m.View()
	for _, want := range []string{"7ed51fa → 0116683", "waits on ns/foundation", "brett@osinfra.io"} {
		if !strings.Contains(view, want) {
			t.Fatalf("details are missing %q:\n%s", want, view)
		}
	}

	if strings.Contains(view, "Destroy mode") || strings.Contains(view, "Plan only") {
		t.Fatal("destroy mode and plan only should be hidden unless set")
	}
}

func TestFailedWorkspaceExplainsWhy(t *testing.T) {
	m := New(newAPI(), "local")
	next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{
		{Name: "ns/seed", Namespace: "ns", Phase: "TFExecPlanFailed", Message: "error running Plan\n\nError: googleapi: Error 401: Request had invalid authentication credentials."},
	}})
	m = next.(Model)
	m.pendingOnly = false

	view := m.View()
	for _, want := range []string{"Plan failed", "Error 401", "bootstrap/seed/prepare.sh"} {
		if !strings.Contains(view, want) {
			t.Fatalf("failed workspace view is missing %q:\n%s", want, view)
		}
	}
}

func TestProgressNamesRootBlocker(t *testing.T) {
	m := New(newAPI(), "local")
	next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{
		{Name: "ns/assembly", Namespace: "ns", Approved: true, PendingPlan: "p", DependsOn: []string{"ns/foundation"}, Phase: "DependencyNotReady"},
		{Name: "ns/foundation", Namespace: "ns", DependsOn: []string{"ns/bootstrap"}, Phase: "DependencyNotReady"},
		{Name: "ns/bootstrap", Namespace: "ns", Phase: "TFExecPlanFailed", Message: "Error: 401 expired"},
	}})
	m = next.(Model)

	ws := m.workspaces[0]
	out := strings.Join(m.progressLines(ws, 80), "\n")

	for _, want := range []string{"Approved", "Waiting on dependencies", "ns/bootstrap", "Plan failed", "prepare.sh"} {
		if !strings.Contains(out, want) {
			t.Fatalf("progress is missing %q:\n%s", want, out)
		}
	}

	if strings.Contains(out, "ns/foundation") {
		t.Fatalf("progress should name only the root blocker:\n%s", out)
	}
}

func TestChangeBlockReadsLikeATofuPlan(t *testing.T) {
	out := ansi.Strip(strings.Join(changeBlock(plan.Change{
		Address: `google_dns_record_set.records["www:CNAME"]`,
		Actions: []string{"create"},
		Attrs: []plan.Attr{
			{Name: "name", After: `"www"`, HasAfter: true},
			{Name: "ttl", After: "300", HasAfter: true},
			{Name: "unused", After: "null", HasAfter: true},
		},
	}, 80), "\n"))

	for _, want := range []string{
		`+ resource "google_dns_record_set" "records" {`,
		`+ name = "www"`,
		`+ ttl  = 300`,
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("block is missing %q:\n%s", want, out)
		}
	}

	if strings.Contains(out, "unused") {
		t.Fatalf("null attributes of a new resource should be hidden:\n%s", out)
	}
}

func TestExpandAllShowsEveryChange(t *testing.T) {
	api := newAPI()
	api.plan.Changes = []plan.Change{
		{Address: "a.one", Actions: []string{"create"}, Attrs: []plan.Attr{{Name: "x", After: "1", HasAfter: true}}},
		{Address: "a.two", Actions: []string{"create"}, Attrs: []plan.Attr{{Name: "y", After: "2", HasAfter: true}}},
	}

	m := loaded(api)
	m, _ = press(m, "e")

	view := m.View()
	for _, want := range []string{"a.one", "a.two", `+ resource "a" "one" {`} {
		if !strings.Contains(view, want) {
			t.Fatalf("expand all is missing %q:\n%s", want, view)
		}
	}

	m, _ = press(m, "e")
	if strings.Contains(m.View(), "+ resource") {
		t.Fatal("second press should collapse")
	}
}

func batchModel(api *fakeAPI) Model {
	m := New(api, "local")
	next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{
		{Name: "ns/one", Namespace: "ns", PendingPlan: "plan-1"},
		{Name: "ns/two", Namespace: "ns", PendingPlan: "plan-1"},
		{Name: "ns/gone", Namespace: "ns", PendingPlan: "plan-1"},
	}})
	m = next.(Model)

	for _, ref := range []string{"ns/one", "ns/two"} {
		next, _ = m.Update(planMsg{ref: ref, id: "plan-1", plan: api.plan})
		m = next.(Model)
	}

	destroy := api.plan
	destroy.Changes = []plan.Change{{Address: "a.b", Actions: []string{"delete"}}}
	next, _ = m.Update(planMsg{ref: "ns/gone", id: "plan-1", plan: destroy})

	return next.(Model)
}

func TestBatchApproveSelectedPlansSkippingDestroys(t *testing.T) {
	api := newAPI()
	m := batchModel(api)

	for i := 0; i < 3; i++ {
		m, _ = press(m, " ")
		m = down(m)
	}

	m, _ = press(m, "A")
	if m.mode != modeConfirmBatch {
		t.Fatalf("mode = %v, status %q, err %v", m.mode, m.status, m.err)
	}

	m, cmd := press(m, "y")

	msg, ok := cmd().(batchMsg)
	if !ok || len(msg.failed) != 0 || len(msg.approved) != 2 {
		t.Fatalf("batch result = %+v", msg)
	}

	if strings.Join(api.approved, ",") != "ns/one@plan-1,ns/two@plan-1" {
		t.Fatalf("approved = %v", api.approved)
	}

	next, _ := m.Update(msg)
	if len(next.(Model).marked) != 1 {
		t.Fatalf("only the skipped plan should stay selected: %v", next.(Model).marked)
	}
}

func TestBatchApproveStopsOnChangedPlan(t *testing.T) {
	api := newAPI()
	m := batchModel(api)
	m, _ = press(m, "m")
	m, _ = press(m, "A")
	_, cmd := press(m, "y")

	api.plan.SHA256 = "changed"

	msg := cmd().(batchMsg)
	if len(msg.approved) != 0 || len(msg.failed) != 2 || len(api.approved) != 0 {
		t.Fatalf("changed plans must not be approved: %+v %v", msg, api.approved)
	}
}

func TestBatchNeedsSelection(t *testing.T) {
	m, _ := press(batchModel(newAPI()), "A")
	if m.mode != modeList || m.status == "" {
		t.Fatalf("mode=%v status=%q", m.mode, m.status)
	}
}

func TestBatchProgressFollowsEachApply(t *testing.T) {
	api := newAPI()
	m := batchModel(api)
	m, _ = press(m, "m")
	m, _ = press(m, "A")
	m, cmd := press(m, "y")

	if !m.batch.busy || !strings.Contains(ansi.Strip(m.View()), "Approving") {
		t.Fatalf("batch should show approving:\n%s", m.View())
	}

	next, _ := m.Update(cmd())
	m = next.(Model)

	if !m.watching() {
		t.Fatal("a batch with applies in flight should keep polling")
	}

	view := ansi.Strip(m.View())
	for _, want := range []string{"Approved 2 of 3 plans", "ns/one", "ns/two", "Not included"} {
		if !strings.Contains(view, want) {
			t.Fatalf("batch progress is missing %q:\n%s", want, view)
		}
	}

	next, _ = m.Update(loadedMsg{workspaces: []floorclient.Workspace{
		{Name: "ns/one", Namespace: "ns", LastAppliedRevision: "r2", Phase: "TerraformAppliedSucceed"},
		{Name: "ns/two", Namespace: "ns", Phase: "TFExecApplyFailed", Message: "Error: boom"},
		{Name: "ns/gone", Namespace: "ns", PendingPlan: "plan-1"},
	}})
	m = next.(Model)

	view = ansi.Strip(m.View())
	for _, want := range []string{"Applied", "Apply failed", "boom"} {
		if !strings.Contains(view, want) {
			t.Fatalf("batch progress is missing %q:\n%s", want, view)
		}
	}

	if m.watching() {
		t.Fatal("polling should stop once every approved plan finished")
	}
}

func TestApproveWithSelectionApprovesAllSelectedAndTotals(t *testing.T) {
	m := batchModel(newAPI())
	m, _ = press(m, "m")
	m, _ = press(m, "a")

	if m.mode != modeConfirmBatch {
		t.Fatalf("mode = %v, want batch confirmation", m.mode)
	}

	if view := ansi.Strip(m.View()); !strings.Contains(view, "2 create in total") {
		t.Fatalf("batch should total every plan:\n%s", view)
	}
}

func TestEnvironmentDropdownSwitches(t *testing.T) {
	m := New(newAPI(), "local").WithEnvironments([]string{"local", "sandbox"}, func(string) (API, error) { return newAPI(), nil })
	m.width, m.height = 120, 40

	m, _ = press(m, "E")
	if !m.envMenu || !strings.Contains(ansi.Strip(m.View()), "sandbox") {
		t.Fatal("dropdown should list environments")
	}

	m = down(m)
	m, _ = press(m, "enter")

	if m.environment != "sandbox" || m.envMenu {
		t.Fatalf("environment = %q, menu open = %v", m.environment, m.envMenu)
	}
}

func TestOverviewSummarisesAndLinksWorkspaces(t *testing.T) {
	m := New(newAPI(), "local")
	m.width, m.height = 110, 34
	m.workspaces = []floorclient.Workspace{
		{Name: "a", Namespace: "ns", Phase: "TerraformPlannedNoChanges"},
		{Name: "b", Namespace: "ns", Phase: "TFExecPlanFailed", Message: "Error: boom", DependsOn: []string{"ns/a"}},
	}

	m.home = true
	m.expanded["ns"] = true

	view := ansi.Strip(m.View())
	for _, want := range []string{"2 workspaces", "1 healthy", "1 failed", "boom", "✓ 1 applied", "● b · plan failed"} {
		if !strings.Contains(view, want) {
			t.Fatalf("overview missing %q:\n%s", want, view)
		}
	}

	_, hits := m.frame()

	found := false

	for _, h := range hits {
		found = found || h.key == "dep:ns/b"
	}

	if !found {
		t.Fatal("map entries should be clickable")
	}
}

func TestOverviewMapIsKeyboardNavigable(t *testing.T) {
	m := New(newAPI(), "local")
	m.width, m.height = 110, 34
	m.workspaces = []floorclient.Workspace{
		{Name: "a", Namespace: "ns", Phase: "TerraformPlannedNoChanges"},
		{Name: "b", Namespace: "ns", Phase: "DependencyNotReady", DependsOn: []string{"ns/a"}},
	}

	m.expanded["ns"] = true

	m = down(m)
	m = down(m)
	m, _ = press(m, "enter")

	if ws, ok := m.selected(); !ok || ws.Name != "b" || m.pendingOnly {
		t.Fatalf("enter should open b, got %v %v", ws.Name, ok)
	}
}

func TestEscGoesBackToOverview(t *testing.T) {
	m := New(newAPI(), "local")
	m.width, m.height = 110, 34
	m.workspaces = []floorclient.Workspace{
		{Name: "a", Namespace: "ns", Phase: "TerraformPlannedNoChanges"},
		{Name: "b", Namespace: "ns", Phase: "DependencyNotReady", DependsOn: []string{"ns/a"}},
	}

	m.expanded["ns"] = true

	m = down(m)
	m = down(m)
	m, _ = press(m, "enter")

	if ws, ok := m.selected(); !ok || ws.Name != "b" {
		t.Fatalf("down then enter should open b, got %q", ws.Name)
	}

	m, _ = press(m, "esc")
	if !m.overviewShown() || m.mapCursor != 1 {
		t.Fatalf("esc should return to the overview on b, home=%v cursor=%d", m.home, m.mapCursor)
	}
}

func TestOverviewTokenWarningAndCompactList(t *testing.T) {
	m := New(newAPI(), "local")
	m.width, m.height = 140, 40
	m.pendingOnly = false
	m.workspaces = []floorclient.Workspace{
		{Name: "a", Namespace: "ns", Phase: "TerraformPlannedNoChanges", LastAppliedRevision: "main@sha1:0116683fcc"},
		{Name: "b", Namespace: "ns", Phase: "DependencyNotReady", DependsOn: []string{"ns/a"}},
	}
	m.tokens = map[string]time.Time{"ns": time.Now().Add(-time.Minute)}
	m.home = true
	m.expanded["ns"] = true

	view := ansi.Strip(m.View())
	for _, want := range []string{"▲ Google token expired", "token expired", "● b · waiting on a"} {
		if !strings.Contains(view, want) {
			t.Fatalf("missing %q:\n%s", want, view)
		}
	}

	if strings.Contains(view, "Up to date") {
		t.Fatalf("compact list should not use full cards:\n%s", view)
	}
}

func TestProgressShowsApplyActivity(t *testing.T) {
	ws := floorclient.Workspace{Name: "ns/seed", Namespace: "ns", Phase: "Progressing", Approved: true}
	m := New(nil, "local")
	m.activity = map[string]plan.Activity{ws.Ref(): {Steps: []plan.Step{
		{Address: `module.a["x"].random_id.this`, Done: true, Elapsed: "0s"},
		{Address: `module.a["x"].google_container_cluster.this`, Verb: "creating", Elapsed: "1m10s"},
	}}}

	out := strings.Join(m.progressLines(ws, 100), "\n")
	for _, want := range []string{"1 resources finished · 1 running", "google_container_cluster.this", "creating · 1m10s", "random_id.this"} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing %q in:\n%s", want, out)
		}
	}
}

type renewer struct {
	*fakeAPI
	called []string
}

func (r *renewer) RenewToken(_ context.Context, ns string) error {
	r.called = append(r.called, ns)

	return nil
}

func TestRenewHintAndKeyOnlyForExpiringTokens(t *testing.T) {
	m := New(&renewer{fakeAPI: &fakeAPI{}}, "local")
	m.tokens = map[string]time.Time{"bootstrap-sandbox": time.Now().Add(time.Hour)}

	if m.canRenew() {
		t.Fatal("fresh token should not offer renewal")
	}

	m.tokens["bootstrap-sandbox"] = time.Now().Add(5 * time.Minute)

	if !m.canRenew() || len(m.expiringNamespaces()) != 1 {
		t.Fatal("expiring token should offer renewal")
	}

	next, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("T")})
	if cmd == nil || !next.(Model).renewing {
		t.Fatal("T should start renewing")
	}
}

func TestDetailsListCommitsBehindRevision(t *testing.T) {
	ws := floorclient.Workspace{Name: "ns/a", Namespace: "ns", Path: "./a", PendingPlan: "plan-a-bbbbbbb1", LastAppliedRevision: "main@sha1:aaaaaaa1"}
	m := New(nil, "local")

	if from, to := revisions(ws); from != "aaaaaaa" || to != "bbbbbbb1" {
		t.Fatalf("revisions = %q, %q", from, to)
	}

	m.commits = map[string]*gitlog.Log{commitKey(ws): {
		Commits: []gitlog.Commit{{Hash: "bbbbbbb", Subject: "Add the cluster", Author: "Brett", Date: "2026-11-21"}},
		Files:   []gitlog.File{{Path: "a/main.tofu", Added: "10", Deleted: "2"}},
	}}

	body, hits := m.details(ws, planState{}, 0, 100)
	out := strings.Join(body, "\n")

	if len(hits) != 1 || hits[0].key != "file:a/main.tofu" {
		t.Fatalf("hits = %+v", hits)
	}

	for _, want := range []string{"Commits to apply", "bbbbbbb Add the cluster", "Brett · 2026-11-21", "a/main.tofu", "+10"} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing %q in:\n%s", want, out)
		}
	}
}

type differ struct{ *fakeAPI }

func (differ) CommitDiff(context.Context, string, string, string, string) ([]string, int, error) {
	return []string{"@@ -1 +1 @@", "-old", "+new"}, 5, nil
}

func TestDiffTabOpensAndGoesBackToDetails(t *testing.T) {
	ws := floorclient.Workspace{Name: "ns/a", Namespace: "ns", Path: "./a", PendingPlan: "plan-a-bbbbbbb1", LastAppliedRevision: "main@sha1:aaaaaaa1"}
	m := New(differ{newAPI()}, "local")
	m.workspaces = []floorclient.Workspace{ws}
	m.pendingOnly = false
	m.home = false

	cmd := m.openDiff("a/main.tofu")
	if cmd == nil || m.tab != tabDiff {
		t.Fatalf("diff not opened: tab=%v", m.tab)
	}

	next, _ := m.Update(diffMsg{key: diffKey(ws, "a/main.tofu"), lines: []string{"@@ -1 +1 @@", "-old", "+new"}, more: 5})
	m = next.(Model)

	out := strings.Join(m.diffLines(ws, 80, 30), "\n")
	for _, want := range []string{"a/main.tofu", "+new", "5 more lines not shown"} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing %q in:\n%s", want, out)
		}
	}

	next, _ = m.Update(tea.KeyMsg{Type: tea.KeyEsc})
	if next.(Model).tab != tabDetails {
		t.Fatal("esc should return to Details")
	}
}

func TestListSplitsCardsFromHealthyRows(t *testing.T) {
	m := New(nil, "local")
	m.pendingOnly = false
	m.home = true
	m.workspaces = []floorclient.Workspace{
		{Name: "a-healthy", Namespace: "ns", Phase: "TerraformPlannedNoChanges"},
		{Name: "z-pending", Namespace: "ns", PendingPlan: "plan-z-abc1234"},
		{Name: "b-healthy", Namespace: "ns", Phase: "TerraformPlannedNoChanges"},
	}

	if got := m.visible()[0].Name; got != "z-pending" {
		t.Fatalf("first = %q, want the one that needs you", got)
	}

	list, hits := m.cards(40, 30)
	view := ansi.Strip(list)

	for _, want := range []string{"▾ ns", "╭", "z-pending", "Awaiting approval", "a-healthy", "b-healthy"} {
		if !strings.Contains(view, want) {
			t.Fatalf("missing %q:\n%s", want, view)
		}
	}

	if len(hits) != 5 {
		t.Fatalf("hits = %+v", hits)
	}
}

func TestSidebarNamespaceDropdowns(t *testing.T) {
	m := New(nil, "local")
	m.width, m.height, m.pendingOnly, m.home = 120, 30, false, true
	m.workspaces = []floorclient.Workspace{
		{Name: "b/main", Namespace: "b"},
		{Name: "main", Namespace: "a"},
	}
	m.cursor = 1
	list, hits := m.cards(40, 20)
	text := ansi.Strip(list)
	if !strings.Contains(text, "▾ a\n    ● main\n▾ b\n    ● main") {
		t.Fatalf("workspaces should appear beneath their namespaces:\n%s", text)
	}
	var namespaceHit hit
	for _, h := range hits {
		if h.key == "sidebar-ns:a" {
			namespaceHit = h
		}
	}
	if namespaceHit.key == "" {
		t.Fatal("missing clickable namespace")
	}
	m, _ = clickAt(m, namespaceHit.x0, namespaceHit.y0)
	list, _ = m.cards(40, 20)
	if got := ansi.Strip(list); !strings.Contains(got, "▸ a\n▾ b\n    ● main") {
		t.Fatalf("collapsing a should leave b open:\n%s", got)
	}
	if m.expanded["a"] {
		t.Fatal("sidebar dropdown must not change the overview dropdown")
	}
	m, _ = press(m, "N")
	list, _ = m.cards(40, 20)
	if got := ansi.Strip(list); !strings.Contains(got, "▾ a\n    ● main") {
		t.Fatalf("N should reopen the current namespace:\n%s", got)
	}
}

func TestSidebarNavigationKeepsNamespaceVisible(t *testing.T) {
	m := New(nil, "local")
	m.pendingOnly = false
	for _, ns := range []string{"a", "b"} {
		for i := 0; i < 8; i++ {
			m.workspaces = append(m.workspaces, floorclient.Workspace{Name: fmt.Sprintf("%s/item-%d", ns, i), Namespace: ns})
		}
	}
	m.selectIndex(6)
	list, _ := m.cards(40, 4)
	if got := ansi.Strip(list); !strings.HasPrefix(got, "▾ a\n") || !strings.Contains(got, "item-6") {
		t.Fatalf("scrolling must keep the namespace and selected workspace visible:\n%s", got)
	}
	m.toggleSidebarNamespace("b")
	m = down(m)
	m = down(m)
	ws, _ := m.selected()
	if ws.Namespace != "b" || m.sidebarCollapsed["b"] {
		t.Fatalf("navigation should reveal the selected namespace: workspace=%+v collapsed=%v", ws, m.sidebarCollapsed)
	}
}

func TestOverviewSummarisesNamespacesAndExpandsOnEnter(t *testing.T) {
	m := New(nil, "local")
	m.width, m.height = 100, 34
	m.home = true
	m.workspaces = []floorclient.Workspace{
		{Name: "a", Namespace: "ns", Phase: "TerraformAppliedSucceed"},
		{Name: "b", Namespace: "ns", PendingPlan: "p", Approved: true, ApprovedAt: time.Now().Add(-90 * time.Second).Format(time.RFC3339)},
		{Name: "c", Namespace: "ns", Phase: "DependencyNotReady", DependsOn: []string{"ns/b"}},
	}

	view := ansi.Strip(m.View())
	for _, want := range []string{"1/3 applied", "▸ ns", "stage 1 of 2", "1 running", "Now", "ns/b · applying · 1m 3", "1 workspace waiting on b · applying"} {
		if !strings.Contains(view, want) {
			t.Fatalf("missing %q:\n%s", want, view)
		}
	}

	if strings.Contains(view, " 1  ") {
		t.Fatalf("stages should be folded:\n%s", view)
	}

	m = down(m)
	next, _ := m.key("enter")
	m = next.(Model)

	if view := ansi.Strip(m.View()); !strings.Contains(view, "▾ ns") || !strings.Contains(view, "● c · waiting on b") {
		t.Fatalf("enter should expand the namespace:\n%s", view)
	}
}

func TestFailureSticksWhileControllerRetries(t *testing.T) {
	m := New(nil, "local")
	send := func(phase string) {
		next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{{Name: "w", Namespace: "ns", Phase: phase}}})
		m = next.(Model)
	}

	send("TFExecPlanFailed")
	send("Progressing")

	if !m.workspaces[0].Failed() || !m.needsYou(m.workspaces[0]) {
		t.Fatalf("retrying workspace should still show as failed, got %q", m.workspaces[0].Phase)
	}

	send("TerraformPlannedNoChanges")

	if m.workspaces[0].Failed() {
		t.Fatal("failure should clear once the workspace settles")
	}

	send("Progressing")

	if m.workspaces[0].Failed() {
		t.Fatal("a fresh run must not inherit an old failure")
	}
}

func TestHeaderShowsTokenRenewal(t *testing.T) {
	m := New(nil, "local")
	m.renewing = true

	if got := m.tokenAlert(); !strings.Contains(got, "Renewing the runner token") {
		t.Fatalf("header alert = %q", got)
	}
}

func TestDiffTabIsInTheTabBarAndCycle(t *testing.T) {
	ws := floorclient.Workspace{Name: "ns/a", Namespace: "ns", Path: "./a", PendingPlan: "plan-a-bbbbbbb1", LastAppliedRevision: "main@sha1:aaaaaaa1"}
	m := New(differ{newAPI()}, "local")
	m.workspaces = []floorclient.Workspace{ws}
	m.pendingOnly = false
	m.home = false
	m.commits = map[string]*gitlog.Log{commitKey(ws): {Commits: []gitlog.Commit{{Hash: "bbbbbbb1"}}}}
	m.diffs = map[string]*diffState{}

	m.tab = tabDetails

	if cmd := m.nextTab(); cmd == nil || m.tab != tabDiff {
		t.Fatalf("tab after Details should be Diff, got %v", m.tab)
	}

	if m.nextTab(); m.tab != tabDependencies {
		t.Fatalf("tab after Diff should be Dependencies, got %v", m.tab)
	}
}

func TestFailureExplainsWhyNotJustWhat(t *testing.T) {
	msg := "error running Apply: rpc error: code = Internal desc = exit status 1\n\nError: installation failed\n\n  with module.openbao[\"this\"].helm_release.openbao,\n  on ../../modules/kubernetes/openbao/regional/main.tofu line 4, in resource \"helm_release\" \"openbao\":\n   4: resource \"helm_release\" \"openbao\" {\n\ncannot re-use a name that is still in use\n"
	ws := floorclient.Workspace{Name: "w", Namespace: "ns", Phase: "TerraformAppliedFail", Message: msg}

	if got := firstProblem(ws); got != "installation failed: cannot re-use a name that is still in use" {
		t.Fatalf("firstProblem = %q", got)
	}

	out := ansi.Strip(strings.Join(problemLines(ws, 100), "\n"))
	for _, want := range []string{"Why", "cannot re-use a name", "Resource", "helm_release.openbao", "Fix", "Uninstall or import"} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing %q:\n%s", want, out)
		}
	}
}

func TestFailureSplitsParagraphsAndTidiesProviderNames(t *testing.T) {
	msg := "Error: Provider produced inconsistent result after apply\n\nWhen applying changes to module.m[\"this\"].kubernetes_manifest.p, provider \"provider[\\\"registry.opentofu.org/hashicorp/kubernetes\\\"]\" produced an unexpected new value.\n\nThis is a bug in the provider."
	ws := floorclient.Workspace{Name: "w", Namespace: "ns", Phase: "TerraformAppliedFail", Message: msg}

	out := ansi.Strip(strings.Join(problemLines(ws, 120), "\n"))
	for _, want := range []string{"Resource", "module.m[\"this\"].kubernetes_manifest.p", "\"registry.opentofu.org/hashicorp/kubernetes\" produced", "This is a bug"} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing %q:\n%s", want, out)
		}
	}

	if strings.Contains(out, `\"`) {
		t.Fatalf("escaping should be removed:\n%s", out)
	}
}

func TestNeedsAttentionAndNowOpenTheWorkspace(t *testing.T) {
	m := New(newAPI(), "local")
	m.width, m.height = 110, 34
	m.home = true
	m.workspaces = []floorclient.Workspace{
		{Name: "bad", Namespace: "ns", Phase: "TerraformAppliedFail", Message: "Error: boom"},
	}

	_, hits := m.frame()

	for _, h := range hits {
		if h.key == "dep:ns/bad" {
			m, _ = clickAt(m, h.x0+2, h.y0)

			if ws, ok := m.selected(); !ok || ws.Name != "bad" {
				t.Fatalf("clicking the failure should open it, got %q", ws.Name)
			}

			return
		}
	}

	t.Fatal("failures under Needs attention should be clickable")
}

func TestHeldFailureKeepsItsError(t *testing.T) {
	m := New(nil, "local")
	send := func(phase, msg string) {
		next, _ := m.Update(loadedMsg{workspaces: []floorclient.Workspace{{Name: "w", Namespace: "ns", Phase: phase, Message: msg}}})
		m = next.(Model)
	}

	send("TerraformAppliedFail", "Error: boom")
	send("Progressing", "Terraform Planning")

	if got := firstProblem(m.workspaces[0]); got != "boom" {
		t.Fatalf("held failure should keep its error, got %q", got)
	}
}

func TestActivityShowsApproverChangesAndCommit(t *testing.T) {
	m := New(nil, "local")
	m.width, m.height = 140, 34
	m.home = true
	m.workspaces = []floorclient.Workspace{{
		Name: "w", Namespace: "ns", Phase: "TerraformAppliedSucceed", ApprovedBy: "floor-verify", ApprovedAt: "2026-11-22T09:13:00Z",
		ApprovedPlan: "plan-main-abc1234", LastAppliedRevision: "main@sha1:abc1234def",
	}}
	m.plans["w|plan-main-abc1234"] = planState{plan: plan.Plan{Changes: []plan.Change{{Actions: []string{"create"}}, {Actions: []string{"update"}}}}}
	m.heads = map[string]gitlog.Commit{"abc1234": {Hash: "abc1234", Subject: "Fix the gateway", Author: "Brett"}}

	view := ansi.Strip(m.View())
	for _, want := range []string{"approved by floor-verify", "1 create, 1 update", "abc1234 Fix the gateway (Brett)"} {
		if !strings.Contains(view, want) {
			t.Fatalf("missing %q:\n%s", want, view)
		}
	}
}

func TestExpandedNamespaceDetailsPendingPlans(t *testing.T) {
	m := New(nil, "local")
	m.width, m.height = 140, 34
	m.home = true
	m.workspaces = []floorclient.Workspace{{Name: "ns/w", Namespace: "ns", PendingPlan: "plan-main-abc1234", Approved: true, ApprovedBy: "brett"}}
	m.plans["ns/w|plan-main-abc1234"] = planState{plan: plan.Plan{Changes: []plan.Change{{Actions: []string{"delete"}}}}}
	m.heads = map[string]gitlog.Commit{"abc1234": {Hash: "abc1234", Subject: "Drop it", Author: "Brett"}}
	m.expanded["ns"] = true

	view := ansi.Strip(m.View())
	for _, want := range []string{"approved by brett", "1 delete", "abc1234 Drop it (Brett)"} {
		if !strings.Contains(view, want) {
			t.Fatalf("missing %q:\n%s", want, view)
		}
	}
}

func TestOverviewShowsPlanningAndApplying(t *testing.T) {
	m := New(nil, "local")
	m.width, m.height = 120, 34
	m.home = true
	m.workspaces = []floorclient.Workspace{
		{Name: "ns/p", Namespace: "ns", Phase: "Progressing", Message: "Terraform Planning"},
		{Name: "ns/i", Namespace: "ns", Phase: "Progressing", Message: "Initializing"},
	}

	view := ansi.Strip(m.View())
	for _, want := range []string{"1 running", "Now", "◇ ns/p · planning", "1 healthy"} {
		if !strings.Contains(view, want) {
			t.Fatalf("missing %q:\n%s", want, view)
		}
	}
}
