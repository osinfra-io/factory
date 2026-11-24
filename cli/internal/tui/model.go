// Package tui is the Bubble Tea interface for reviewing and approving
// Floor plans.
package tui

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync/atomic"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"

	"github.com/osinfra-io/factory/cli/internal/floorclient"
	"github.com/osinfra-io/factory/cli/internal/gitlog"
	"github.com/osinfra-io/factory/cli/internal/plan"
)

// ErrPlanUnavailable means plan contents cannot be read for this environment.
var ErrPlanUnavailable = errors.New("plan contents are not available for this environment yet")

// API is the Floor surface the UI depends on.
type API interface {
	ListWorkspaces(ctx context.Context) ([]floorclient.Workspace, error)
	ReadPlan(ctx context.Context, namespace, name string) (plan.Plan, error)
	Approve(ctx context.Context, name, planID string, acknowledgeDestroys bool) (string, error)
	Reject(ctx context.Context, name, reason string) (string, error)
}

type mode int

const (
	modeList mode = iota
	modeConfirmApprove
	modeConfirmReject
	modeConfirmBatch
)

const (
	refreshInterval = 10 * time.Second
	watchInterval   = 2 * time.Second
	maxChangeLines  = 12
)

// Palette shared with the editor and terminal theme.
var (
	accent  = lipgloss.Color("#ffb400")
	green   = lipgloss.Color("#90A57D")
	yellow  = lipgloss.Color("#D7AF87")
	red     = lipgloss.Color("#D78787")
	blue    = lipgloss.Color("#7FA5BD")
	text    = lipgloss.Color("#D0D0D0")
	muted   = lipgloss.Color("#8A8782")
	border  = lipgloss.Color("#313131")
	surface = lipgloss.Color("#232323")
	panel   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(border).Padding(0, 1)
	dim     = lipgloss.NewStyle().Foreground(muted)
	bold    = lipgloss.NewStyle().Bold(true).Foreground(text)
	errText = lipgloss.NewStyle().Foreground(red)
	keyPill = lipgloss.NewStyle().Bold(true).Foreground(surface).Background(accent).Padding(0, 1)
)

type (
	diffMsg struct {
		key   string
		lines []string
		more  int
		err   error
	}
	headMsg struct {
		sha    string
		commit gitlog.Commit
	}
	commitsMsg struct {
		key string
		log gitlog.Log
		err error
	}
	renewedMsg struct {
		namespaces []string
		err        error
	}
	tokenMsg    struct{ expiry map[string]time.Time }
	activityMsg struct {
		ref string
		act plan.Activity
	}
	loadedMsg struct {
		workspaces []floorclient.Workspace
		err        error
	}
	planMsg struct {
		ref  string
		id   string
		plan plan.Plan
		err  error
	}
	batchMsg struct {
		approved []string
		failed   map[string]error
	}
	actionMsg struct {
		message string
		err     error
	}
	tickMsg  struct{}
	watchMsg struct{}
)

// outcome is the result of the last approve or reject, kept on screen until
// the user moves to another workspace.
type outcome struct {
	ref           string
	verb          string
	planID        string
	plan          plan.Plan
	appliedBefore string
	busy          bool
	started       time.Time
	err           error
	message       string
}

// batchResult is one line of a batch approval.
type batchResult struct {
	ref           string
	appliedBefore string
	// skipped explains why a ticked plan was left out of the batch.
	skipped string
	done    bool
	err     error
}

// batch tracks the last batch approval so its progress stays on screen.
type batch struct {
	active  bool
	busy    bool
	started time.Time
	results []batchResult
}

type planState struct {
	plan    plan.Plan
	err     error
	loading bool
}

// Model is the root Bubble Tea model.
type Model struct {
	api         API
	environment string
	loading     *atomic.Bool

	workspaces  []floorclient.Workspace
	plans       map[string]planState
	cursor      int
	mode        mode
	pendingOnly bool
	status      string
	outcome     outcome
	err         error

	width, height int
	tab           tab
	scroll        int
	errorScroll   int
	scrolledError string
	mouseReleased bool
	// open is the 1-based index of the change shown in full, or 0.
	open int
	// expandAll shows every change in full, like a complete plan.
	expandAll bool
	// marked holds the workspaces ticked for a batch approval, by Ref.
	marked map[string]bool
	// failures remembers the failed phase of workspaces the controller is retrying.
	failures map[string]string
	batch    batch

	// environments and connect let the header switch Floor. Without more
	// than one environment the header is a plain label.
	environments []string
	connect      func(name string) (API, error)
	envMenu      bool
	envCursor    int

	// mapCursor is the overview map entry highlighted for the keyboard, or -1
	// before the keyboard has touched the map.
	mapCursor int
	// expanded lists the namespaces whose stages the overview shows.
	expanded map[string]bool
	// sidebarCollapsed tracks namespaces folded in the workspace list.
	sidebarCollapsed map[string]bool
	// home shows the overview even though a workspace is highlighted.
	home bool

	// tokens maps a namespace to when its runner's Google token expires.
	tokens   map[string]time.Time
	tokensAt time.Time
	renewing bool
	// commits caches what changed in each workspace's revision range.
	commits map[string]*gitlog.Log
	// diffs caches code diffs; diffFile is the file shown, or all of them.
	diffs    map[string]*diffState
	diffFile string
	// activity is what each applying workspace's runner has reported.
	activity map[string]plan.Activity
	// failureText is the last error shown for each held failure.
	failureText map[string]string
	// heads is the commit behind each applied revision shown in Activity.
	heads      map[string]gitlog.Commit
	activityAt time.Time
	// info describes each environment's cluster and Floor for the header.
	info map[string]string
}

type tab int

const (
	tabChanges tab = iota
	tabDetails
	tabDependencies
	// tabDiff sits between Details and Dependencies in the tab bar.
	tabDiff
)

// New returns a model that talks to api for the named environment.
func New(api API, environment string) Model {
	return Model{api: api, environment: environment, loading: &atomic.Bool{}, pendingOnly: true, plans: map[string]planState{}, marked: map[string]bool{}, failures: map[string]string{}, expanded: map[string]bool{}, mapCursor: -1}
}

// WithInfo sets the short description of each environment shown in the header.
func (m Model) WithInfo(info map[string]string) Model {
	m.info = info

	return m
}

// tokenReader is implemented by backends that can tell when the runner's
// Google token expires.
type tokenReader interface {
	TokenExpiry(ctx context.Context, namespace string) (time.Time, error)
}

// refreshTokens looks up token expiry per namespace, at most every 30s.
func (m *Model) refreshTokens() tea.Cmd {
	reader, ok := m.api.(tokenReader)
	if !ok || len(m.workspaces) == 0 || time.Since(m.tokensAt) < 30*time.Second {
		return nil
	}

	m.tokensAt = time.Now()

	seen := map[string]bool{}

	var namespaces []string

	for _, w := range m.workspaces {
		if !seen[w.Namespace] {
			seen[w.Namespace] = true
			namespaces = append(namespaces, w.Namespace)
		}
	}

	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()

		expiry := map[string]time.Time{}

		for _, ns := range namespaces {
			if t, err := reader.TokenExpiry(ctx, ns); err == nil {
				expiry[ns] = t
			}
		}

		return tokenMsg{expiry: expiry}
	}
}

// tokenRenewer is implemented by backends that can renew the runner's
// Google token in a namespace.
type tokenRenewer interface {
	RenewToken(ctx context.Context, namespace string) error
}

// expiringNamespaces lists namespaces whose runner token has under 15 minutes left.
func (m Model) expiringNamespaces() []string {
	var out []string

	for ns, t := range m.tokens {
		if time.Until(t) < 15*time.Minute {
			out = append(out, ns)
		}
	}

	sort.Strings(out)

	return out
}

// canRenew reports that a token is expiring and the backend can renew it.
func (m Model) canRenew() bool {
	_, ok := m.api.(tokenRenewer)

	return ok && !m.renewing && len(m.expiringNamespaces()) > 0
}

// renewTokens renews every expiring runner token, one namespace at a time.
func (m *Model) renewTokens() tea.Cmd {
	renewer, ok := m.api.(tokenRenewer)
	namespaces := m.expiringNamespaces()

	if !ok || m.renewing || len(namespaces) == 0 {
		return nil
	}

	m.renewing, m.err = true, nil

	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()

		for _, ns := range namespaces {
			if err := renewer.RenewToken(ctx, ns); err != nil {
				return renewedMsg{namespaces: namespaces, err: fmt.Errorf("%s: %w", ns, err)}
			}
		}

		return renewedMsg{namespaces: namespaces}
	}
}

// activityReader is implemented by backends that can read a running apply.
type activityReader interface {
	ApplyActivity(ctx context.Context, namespace, name string) (plan.Activity, error)
}

// loadActivity reads the runner output of the selected workspace while it
// is applying, at most every 2s.
func (m *Model) loadActivity() tea.Cmd {
	reader, ok := m.api.(activityReader)
	ws, sel := m.selected()

	if !ok || !sel || ws.Phase != "Progressing" || !ws.Approved || time.Since(m.activityAt) < 2*time.Second {
		return nil
	}

	m.activityAt = time.Now()

	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		act, err := reader.ApplyActivity(ctx, ws.Namespace, objectName(ws))
		if err != nil {
			return nil
		}

		return activityMsg{ref: ws.Ref(), act: act}
	}
}

// WithEnvironments enables switching between the named environments;
// connect builds the API for the chosen one.
func (m Model) WithEnvironments(names []string, connect func(name string) (API, error)) Model {
	m.environments, m.connect = names, connect

	return m
}

func (m Model) switchable() bool { return len(m.environments) > 1 && m.connect != nil }

// openEnvMenu shows the environment dropdown with the current one highlighted.
func (m *Model) openEnvMenu() {
	m.envMenu = true

	for i, name := range m.environments {
		if name == m.environment {
			m.envCursor = i
		}
	}
}

// switchEnvironment connects to name and starts over with its workspaces.
func (m Model) switchEnvironment(name string) (tea.Model, tea.Cmd) {
	m.envMenu = false

	if name == m.environment {
		return m, nil
	}

	api, err := m.connect(name)
	if err != nil {
		m.err = fmt.Errorf("connecting to %s: %w", name, err)

		return m, nil
	}

	m.api, m.environment, m.loading = api, name, &atomic.Bool{}
	m.workspaces, m.plans, m.marked = nil, map[string]planState{}, map[string]bool{}
	m.sidebarCollapsed = nil
	m.tokens, m.tokensAt, m.home = nil, time.Time{}, false
	m.cursor, m.scroll, m.open, m.expandAll = 0, 0, 0, false
	m.outcome, m.batch, m.err, m.status = outcome{}, batch{}, nil, ""

	return m, m.load()
}

// envKey handles keys while the environment dropdown is open.
func (m Model) envKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "up":
		m.envCursor = max(m.envCursor-1, 0)
	case "down":
		m.envCursor = min(m.envCursor+1, len(m.environments)-1)
	case "enter":
		return m.switchEnvironment(m.environments[m.envCursor])
	case "esc", "E":
		m.envMenu = false
	case "ctrl+c":
		return m, tea.Quit
	}

	return m, nil
}

// Init loads workspaces and schedules refreshes.
func (m Model) Init() tea.Cmd {
	return tea.Batch(m.load(), tick())
}

// watch polls faster than the normal refresh while an approval is applying.
func watch() tea.Cmd {
	return tea.Tick(watchInterval, func(time.Time) tea.Msg { return watchMsg{} })
}

func tick() tea.Cmd {
	return tea.Tick(refreshInterval, func(time.Time) tea.Msg { return tickMsg{} })
}

// load asks Floor for the workspaces. Only one request runs at a time, so a
// slow Floor is never flooded by the ticker, the watcher and manual refreshes.
func (m Model) load() tea.Cmd {
	return func() tea.Msg {
		if !m.loading.CompareAndSwap(false, true) {
			return nil
		}

		defer m.loading.Store(false)

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		ws, err := m.api.ListWorkspaces(ctx)

		return loadedMsg{workspaces: ws, err: err}
	}
}

// loadPlan reads the selected workspace's pending plan once per plan ID.
func (m *Model) loadPlan() tea.Cmd {
	ws, ok := m.selected()
	if !ok {
		return nil
	}

	return tea.Batch(m.loadPlanFor(ws), m.loadCommits(ws))
}

type diffState struct {
	lines []string
	more  int
	err   error
}

func diffKey(ws floorclient.Workspace, file string) string { return commitKey(ws) + "|" + file }

// diffReader is implemented by backends that can show a code diff.
type diffReader interface {
	CommitDiff(ctx context.Context, from, to, path, file string) ([]string, int, error)
}

// openDiff switches to the diff of file (or every file) and loads it once.
// hasDiff reports that the selected workspace has commits to show a diff for.
func (m Model) hasDiff() bool {
	ws, ok := m.selected()
	if !ok {
		return false
	}

	l := m.commits[commitKey(ws)]

	return l != nil && len(l.Commits) > 0
}

// nextTab cycles Changes, Details, Diff (when there are commits), Dependencies.
func (m *Model) nextTab() tea.Cmd {
	order := []tab{tabChanges, tabDetails}
	if m.hasDiff() {
		order = append(order, tabDiff)
	}

	order = append(order, tabDependencies)

	next := order[0]

	for i, t := range order {
		if t == m.tab {
			next = order[(i+1)%len(order)]
		}
	}

	m.scroll, m.open = 0, 0

	if next == tabDiff {
		return m.openDiff("")
	}

	m.tab = next

	return nil
}

func (m *Model) openDiff(file string) tea.Cmd {
	ws, ok := m.selected()
	reader, can := m.api.(diffReader)
	from, to := revisions(ws)

	if !ok || !can || to == "" {
		return nil
	}

	m.tab, m.diffFile, m.scroll, m.open = tabDiff, file, 0, 0
	key := diffKey(ws, file)

	if _, seen := m.diffs[key]; seen {
		return nil
	}

	if m.diffs == nil {
		m.diffs = map[string]*diffState{}
	}

	m.diffs[key] = &diffState{}

	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()

		lines, more, err := reader.CommitDiff(ctx, from, to, ws.Path, file)

		return diffMsg{key: key, lines: lines, more: more, err: err}
	}
}

// commitReader is implemented by backends that can describe the commits
// behind a revision.
type commitReader interface {
	CommitLog(ctx context.Context, from, to, path string) (gitlog.Log, error)
}

// revisions returns the range of commits an apply moves ws across: from the
// applied revision to the pending one, or just the applied commit.
func revisions(ws floorclient.Workspace) (from, to string) {
	applied := ""
	if ws.LastAppliedRevision != "" {
		applied = floorclient.ShortRevision(ws.LastAppliedRevision)
	}

	if ws.PendingPlan != "" {
		return applied, ws.ShortPlan()
	}

	return "", applied
}

func commitKey(ws floorclient.Workspace) string {
	from, to := revisions(ws)

	return from + ".." + to + "|" + ws.Path
}

// loadCommits reads the commits behind ws once per revision range.
func (m *Model) loadCommits(ws floorclient.Workspace) tea.Cmd {
	reader, ok := m.api.(commitReader)
	from, to := revisions(ws)
	key := commitKey(ws)

	if _, seen := m.commits[key]; !ok || to == "" || seen {
		return nil
	}

	if m.commits == nil {
		m.commits = map[string]*gitlog.Log{}
	}

	m.commits[key] = nil

	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		l, err := reader.CommitLog(ctx, from, to, ws.Path)

		return commitsMsg{key: key, log: l, err: err}
	}
}

// preloadPlans reads every waiting plan once so Activity can later say what
// each apply changed.
func (m *Model) preloadPlans() tea.Cmd {
	var cmds []tea.Cmd

	for _, w := range m.workspaces {
		if cmd := m.loadPlanFor(w); cmd != nil {
			cmds = append(cmds, cmd)
		}
	}

	return tea.Batch(cmds...)
}

// loadHeads reads the commit behind each applied revision listed in Activity.
func (m *Model) loadHeads() tea.Cmd {
	reader, ok := m.api.(commitReader)
	if !ok {
		return nil
	}

	if m.heads == nil {
		m.heads = map[string]gitlog.Commit{}
	}

	var cmds []tea.Cmd

	shas := map[string]bool{}

	for _, w := range m.recentWorkspaces() {
		shas[floorclient.ShortRevision(w.LastAppliedRevision)] = true
	}

	for _, w := range m.workspaces {
		if w.PendingPlan != "" {
			shas[w.ShortPlan()] = true
		}
	}

	for sha := range shas {
		if _, seen := m.heads[sha]; sha == "" || seen {
			continue
		}

		m.heads[sha] = gitlog.Commit{}

		cmds = append(cmds, func() tea.Msg {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()

			l, err := reader.CommitLog(ctx, "", sha, "")
			if err != nil || len(l.Commits) == 0 {
				return headMsg{sha: sha}
			}

			return headMsg{sha: sha, commit: l.Commits[0]}
		})
	}

	return tea.Batch(cmds...)
}

func (m *Model) loadPlanFor(ws floorclient.Workspace) tea.Cmd {
	if ws.PendingPlan == "" {
		return nil
	}

	if _, seen := m.plans[planKey(ws)]; seen || m.actedOn(ws) {
		return nil
	}

	m.plans[planKey(ws)] = planState{loading: true}

	api := m.api

	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		p, err := api.ReadPlan(ctx, ws.Namespace, objectName(ws))

		return planMsg{ref: ws.Ref(), id: ws.PendingPlan, plan: p, err: err}
	}
}

// planKey caches plans per workspace: plan IDs come from the source revision,
// so different workspaces can share the same ID.
func planKey(ws floorclient.Workspace) string { return ws.Ref() + "|" + ws.PendingPlan }

// actedOn reports that the user already approved or rejected this exact plan,
// so it is no longer readable and the reviewed copy is shown instead.
func (m Model) actedOn(ws floorclient.Workspace) bool {
	o := m.outcome

	return o.ref == ws.Ref() && o.err == nil && (ws.PendingPlan == "" || ws.PendingPlan == o.planID)
}

// planState is what the pane shows for ws.
func (m Model) planState(ws floorclient.Workspace) planState {
	if m.actedOn(ws) {
		return planState{plan: m.outcome.plan}
	}

	return m.plans[planKey(ws)]
}

func objectName(ws floorclient.Workspace) string {
	return strings.TrimPrefix(ws.Name, ws.Namespace+"/")
}

func (m Model) act(f func(ctx context.Context) (string, error)) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()

		msg, err := f(ctx)

		return actionMsg{message: msg, err: err}
	}
}

// approve re-reads the plan and refuses to approve unless it is exactly the
// plan the user reviewed on screen.
func (m Model) approve(ws floorclient.Workspace, reviewed plan.Plan) tea.Cmd {
	return m.act(func(ctx context.Context) (string, error) {
		current, err := m.api.ReadPlan(ctx, ws.Namespace, objectName(ws))
		if err != nil {
			return "", fmt.Errorf("re-reading plan before approval: %w", err)
		}

		if current.SHA256 != reviewed.SHA256 || current.ID != reviewed.ID {
			return "", errors.New("the plan changed since you reviewed it; nothing was approved")
		}

		return m.api.Approve(ctx, ws.Ref(), reviewed.ID, reviewed.Destroys())
	})
}

// visible returns the workspaces shown, sorted by reference.
func (m Model) visible() []floorclient.Workspace {
	var out []floorclient.Workspace

	for _, w := range m.workspaces {
		if !m.pendingOnly || w.PendingPlan != "" || w.Failed() || w.Ref() == m.outcome.ref {
			out = append(out, w)
		}
	}

	// Workspaces that need you come first, so the list can show them as cards.
	sort.Slice(out, func(i, j int) bool {
		if ni, nj := m.needsYou(out[i]), m.needsYou(out[j]); ni != nj {
			return ni
		}

		return out[i].Ref() < out[j].Ref()
	})

	return out
}

func (m Model) selected() (floorclient.Workspace, bool) {
	v := m.visible()
	if m.home || m.cursor < 0 || m.cursor >= len(v) {
		return floorclient.Workspace{}, false
	}

	return v[m.cursor], true
}

// Update handles input and Floor responses.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tickMsg:
		tokens, act := m.refreshTokens(), m.loadActivity()

		return m, tea.Batch(m.load(), tick(), tokens, act)
	case tokenMsg:
		m.tokens = msg.expiry
	case renewedMsg:
		m.renewing = false
		m.err = msg.err

		if msg.err == nil {
			m.status = "Runner token renewed."
		}

		m.tokensAt = time.Time{}
		tokens := m.refreshTokens()

		return m, tokens
	case diffMsg:
		if m.diffs != nil {
			m.diffs[msg.key] = &diffState{lines: msg.lines, more: msg.more, err: msg.err}
		}
	case commitsMsg:
		if m.commits != nil {
			m.commits[msg.key] = &msg.log
		}
	case activityMsg:
		if m.activity == nil {
			m.activity = map[string]plan.Activity{}
		}

		m.activity[msg.ref] = msg.act
	case loadedMsg:
		m.err = msg.err
		if msg.err == nil {
			m.workspaces = m.holdFailures(msg.workspaces)
			m.pruneMarks()
			m.clamp()

			plan, tokens, act := m.loadPlan(), m.refreshTokens(), m.loadActivity()

			return m, tea.Batch(plan, tokens, act, m.preloadPlans(), m.loadHeads())
		}
	case headMsg:
		m.heads[msg.sha] = msg.commit
	case planMsg:
		m.plans[msg.ref+"|"+msg.id] = planState{plan: msg.plan, err: msg.err}
	case watchMsg:
		if !m.watching() {
			return m, nil
		}

		act := m.loadActivity()

		return m, tea.Batch(m.load(), watch(), act)
	case batchMsg:
		m.mode = modeList
		m.err, m.status = nil, ""
		m.batch.busy = false

		for i, r := range m.batch.results {
			if r.skipped != "" {
				continue
			}

			if err, failed := msg.failed[r.ref]; failed {
				m.batch.results[i].err = err
			} else {
				m.batch.results[i].done = true
			}
		}

		for _, ref := range msg.approved {
			delete(m.marked, ref)
		}

		return m, tea.Batch(m.load(), watch())
	case actionMsg:
		m.mode = modeList

		if m.outcome.ref == "" {
			m.err, m.status = msg.err, msg.message

			return m, m.load()
		}

		m.outcome.busy, m.outcome.err, m.outcome.message = false, msg.err, msg.message
		m.status = ""

		return m, tea.Batch(m.load(), watch())
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tea.MouseMsg:
		return m.mouse(msg)
	case tea.KeyMsg:
		if msg.String() == "M" {
			m.mouseReleased = !m.mouseReleased
			if m.mouseReleased {
				return m, tea.DisableMouse
			}
			return m, tea.EnableMouseCellMotion
		}
		return m.key(msg.String())
	}

	return m, nil
}

func (m *Model) clamp() {
	if n := len(m.visible()); m.cursor >= n {
		m.cursor = max(n-1, 0)
	}
}

func (m Model) key(key string) (tea.Model, tea.Cmd) {
	if m.mode != modeList {
		return m.confirm(key)
	}

	if m.envMenu {
		return m.envKey(key)
	}

	switch key {
	case "E":
		if m.switchable() {
			m.openEnvMenu()
		}
	case "N":
		v := m.visible()
		if m.cursor >= 0 && m.cursor < len(v) {
			m.toggleSidebarNamespace(v[m.cursor].Namespace)
		}
	case "q", "ctrl+c":
		return m, tea.Quit
	case "up":
		if m.overviewShown() {
			return m.moveMap(-1)
		}

		return m.move(-1)
	case "down":
		if m.overviewShown() {
			return m.moveMap(1)
		}

		return m.move(1)
	case "left":
		if m.overviewShown() {
			return m.moveMap(-1)
		}

		return m.key("esc")
	case "right":
		if m.overviewShown() {
			return m.moveMap(1)
		}

		return m.key("tab")
	case "enter":
		if m.overviewShown() {
			return m.openMap()
		}
	case "tab":
		cmd := m.nextTab()

		return m, cmd
	case "esc":
		m.scroll, m.open = 0, 0

		if m.tab == tabDiff {
			m.tab = tabDetails

			return m, nil
		}

		// Leave Details or Dependencies first; a second esc dismisses the outcome banner.
		if m.tab != tabChanges {
			m.tab = tabChanges

			return m, nil
		}

		if m.outcome.ref == "" && !m.batch.active {
			m.goHome()

			return m, nil
		}

		m.outcome = outcome{}
		m.batch.active = false

		m.clamp()
	case "i", "d":
		m.tab = tabDetails
		m.open = 0
	case "e":
		m.expandAll, m.open, m.scroll = !m.expandAll, 0, 0
	case "t":
		m.tab = tabDependencies
		m.scroll, m.open = 0, 0
	case "pgup", "ctrl+u":
		m.scroll = max(m.scroll-5, 0)
	case "pgdown", "ctrl+d":
		m.scroll += 5
	case "[", "]":
		if m.err != nil {
			if m.scrolledError != m.err.Error() {
				m.scrolledError, m.errorScroll = m.err.Error(), 0
			}
			w, h := m.size()
			lines := strings.Split(ansi.Wrap("Error: "+m.err.Error(), w, ""), "\n")
			m.errorScroll = min(m.errorScroll, max(len(lines)-errorRows(h), 0))
			if key == "[" {
				m.errorScroll = max(m.errorScroll-1, 0)
			} else {
				m.errorScroll = min(m.errorScroll+1, max(len(lines)-errorRows(h), 0))
			}
		}
	case "c":
		if !m.overviewShown() {
			cmd := m.openDiff("")

			return m, cmd
		}
	case "T":
		cmd := m.renewTokens()

		return m, cmd
	case "R":
		m.plans = map[string]planState{}

		return m, tea.Batch(m.load())
	case "p":
		m.pendingOnly = !m.pendingOnly
		m.clamp()

		return m, m.loadPlan()
	case " ", "space":
		cmd := m.toggleMark()

		return m, cmd
	case "m":
		cmd := m.markAll()

		return m, cmd
	case "A":
		cmd := m.startBatch()

		return m, cmd
	case "a", "r":
		// With plans ticked, approve means approve the ticked plans.
		if key == "a" && len(m.markedWorkspaces()) > 0 {
			cmd := m.startBatch()

			return m, cmd
		}

		m.startConfirm(key)
	}

	return m, nil
}

func (m Model) move(delta int) (tea.Model, tea.Cmd) {
	v := m.visible()
	order := sidebarOrder(v)
	for pos, index := range order {
		if index == m.cursor {
			m.selectIndex(order[min(max(pos+delta, 0), len(order)-1)])
			return m, m.loadPlan()
		}
	}

	return m, nil
}

func (m *Model) toggleSidebarNamespace(ns string) {
	if m.sidebarCollapsed == nil {
		m.sidebarCollapsed = map[string]bool{}
	}
	m.sidebarCollapsed[ns] = !m.sidebarCollapsed[ns]
}

// selectIndex moves the selection and drops the previous outcome banner,
// unless that outcome is still in flight.
func (m *Model) selectIndex(i int) {
	m.scroll, m.open, m.home = 0, 0, false

	v := m.visible()
	if i < 0 || i >= len(v) {
		return
	}

	delete(m.sidebarCollapsed, v[i].Namespace)
	ref := v[i].Ref()
	if ref != m.outcome.ref && !m.outcome.busy {
		m.outcome = outcome{}
	}

	if !m.batch.busy {
		m.batch.active = false
	}

	for j, w := range m.visible() {
		if w.Ref() == ref {
			m.cursor = j
		}
	}
}

func (m *Model) startConfirm(key string) {
	ws, ok := m.selected()
	if !ok {
		return
	}

	m.status, m.err = "", nil

	if ws.Approved {
		m.status = "Already approved: waiting for Floor to apply it."

		return
	}

	if m.actedOn(ws) && !m.outcome.busy {
		m.status = "Already " + map[string]string{"approve": "approved", "reject": "rejected"}[m.outcome.verb] + ": waiting for Floor."

		return
	}

	if ws.PendingPlan == "" {
		m.status = "Nothing to " + map[string]string{"a": "approve", "r": "reject"}[key] + ": " + ws.Ref() + " has no pending plan."

		return
	}

	if key == "r" {
		m.mode = modeConfirmReject

		return
	}

	state := m.plans[planKey(ws)]

	switch {
	case state.loading:
		m.status = "Still reading the plan; try again in a moment."
	case state.err != nil:
		m.err = fmt.Errorf("approval is disabled until the plan can be reviewed: %w", state.err)
	default:
		m.mode = modeConfirmApprove
	}
}

func (m Model) confirm(key string) (tea.Model, tea.Cmd) {
	if m.mode == modeConfirmBatch {
		if key == "y" {
			return m.approveBatch()
		}

		m.mode = modeList
		m.status = "Cancelled."

		return m, nil
	}

	ws, ok := m.selected()
	state := m.plans[planKey(ws)]

	if !ok {
		m.mode = modeList

		return m, nil
	}

	// A plan that destroys resources needs a deliberate, different key.
	approveKey := "y"
	if state.plan.Destroys() {
		approveKey = "D"
	}

	switch {
	case m.mode == modeConfirmApprove && key == approveKey:
		m.status, m.err = "", nil
		m.outcome = outcome{ref: ws.Ref(), verb: "approve", planID: ws.PendingPlan, plan: state.plan, appliedBefore: ws.LastAppliedRevision, busy: true, started: time.Now()}
		m.mode = modeList

		return m, m.approve(ws, state.plan)
	case m.mode == modeConfirmReject && key == "y":
		m.status, m.err = "", nil
		m.outcome = outcome{ref: ws.Ref(), verb: "reject", planID: ws.PendingPlan, plan: state.plan, appliedBefore: ws.LastAppliedRevision, busy: true, started: time.Now()}
		m.mode = modeList

		return m, m.act(func(ctx context.Context) (string, error) {
			return m.api.Reject(ctx, ws.Ref(), "rejected from factory cli")
		})
	}

	m.mode = modeList
	m.status = "Cancelled."

	return m, nil
}

// runIcon distinguishes planning from applying.
func runIcon(running string) string {
	if running == "applying" {
		return "▶"
	}

	return "◇"
}

func statusDot(w floorclient.Workspace) string {
	switch {
	case w.Running() != "":
		return lipgloss.NewStyle().Foreground(blue).Render(runIcon(w.Running()))
	case w.PendingPlan != "":
		return lipgloss.NewStyle().Foreground(yellow).Render("●")
	default:
		return lipgloss.NewStyle().Foreground(phaseColour(w)).Render("●")
	}
}

func actionSymbol(actions []string) string {
	switch strings.Join(actions, "+") {
	case "create":
		return lipgloss.NewStyle().Foreground(green).Render("+")
	case "delete":
		return errText.Render("-")
	case "update":
		return lipgloss.NewStyle().Foreground(yellow).Render("~")
	default:
		return errText.Render("±")
	}
}

// fullRef is the namespace/name form Floor uses in dependsOn.
func fullRef(w floorclient.Workspace) string {
	return w.Namespace + "/" + strings.TrimPrefix(w.Ref(), w.Namespace+"/")
}

// jumpTo selects the workspace with the given namespace/name reference.
func (m *Model) jumpTo(ref string) bool {
	for _, w := range m.workspaces {
		if fullRef(w) != ref {
			continue
		}

		m.pendingOnly = false

		for i, v := range m.visible() {
			if v.Ref() == w.Ref() {
				m.selectIndex(i)

				return true
			}
		}
	}

	return false
}

// markable reports whether a workspace can be ticked for batch approval.
func markable(ws floorclient.Workspace) bool { return ws.PendingPlan != "" && !ws.Approved }

// holdFailures keeps a failed workspace showing as failed while the controller
// retries it, so the failure does not vanish on the next refresh. It clears
// once the workspace settles into any other phase.
func (m *Model) holdFailures(ws []floorclient.Workspace) []floorclient.Workspace {
	if m.failures == nil {
		m.failures = map[string]string{}
	}

	if m.failureText == nil {
		m.failureText = map[string]string{}
	}

	seen := map[string]bool{}

	for i, w := range ws {
		ref := w.Ref()
		seen[ref] = true

		switch {
		case w.Failed():
			m.failures[ref] = w.Phase
			m.failureText[ref] = w.Message
		case w.Phase == "Progressing" && w.PendingPlan == "" && m.failures[ref] != "":
			ws[i].Phase = m.failures[ref]
			ws[i].Message = m.failureText[ref]
		default:
			delete(m.failures, ref)
			delete(m.failureText, ref)
		}
	}

	for ref := range m.failures {
		if !seen[ref] {
			delete(m.failures, ref)
			delete(m.failureText, ref)
		}
	}

	return ws
}

func (m *Model) pruneMarks() {
	for ref := range m.marked {
		keep := false

		for _, w := range m.workspaces {
			if w.Ref() == ref && markable(w) {
				keep = true
			}
		}

		if !keep {
			delete(m.marked, ref)
		}
	}
}

// markedWorkspaces lists the ticked workspaces in display order.
func (m Model) markedWorkspaces() []floorclient.Workspace {
	var out []floorclient.Workspace

	for _, w := range m.visible() {
		if m.marked[w.Ref()] && markable(w) {
			out = append(out, w)
		}
	}

	return out
}

func (m *Model) mark(ws floorclient.Workspace) tea.Cmd {
	if !markable(ws) {
		m.status = ws.Ref() + " has no pending plan to select."

		return nil
	}

	m.status, m.err = "", nil

	if m.marked[ws.Ref()] {
		delete(m.marked, ws.Ref())

		return nil
	}

	m.marked[ws.Ref()] = true

	return m.loadPlanFor(ws)
}

func (m *Model) toggleMark() tea.Cmd {
	ws, ok := m.selected()
	if !ok {
		return nil
	}

	return m.mark(ws)
}

// markAll ticks every pending plan, or clears the ticks when all are set.
func (m *Model) markAll() tea.Cmd {
	var pending []floorclient.Workspace

	for _, w := range m.visible() {
		if markable(w) {
			pending = append(pending, w)
		}
	}

	if len(pending) == len(m.markedWorkspaces()) {
		m.marked = map[string]bool{}

		return nil
	}

	var cmds []tea.Cmd

	for _, w := range pending {
		m.marked[w.Ref()] = true
		cmds = append(cmds, m.loadPlanFor(w))
	}

	return tea.Batch(cmds...)
}

// batchPlans splits the ticked workspaces into plans that can be approved
// together and those that delete resources, which need their own approval.
func (m Model) batchPlans() (ok, destroying []floorclient.Workspace) {
	for _, w := range m.markedWorkspaces() {
		if m.plans[planKey(w)].plan.Destroys() {
			destroying = append(destroying, w)
		} else {
			ok = append(ok, w)
		}
	}

	return ok, destroying
}

func (m *Model) startBatch() tea.Cmd {
	m.status, m.err = "", nil

	marked := m.markedWorkspaces()
	if len(marked) == 0 {
		m.status = "Select plans with space (or m for all) first."

		return nil
	}

	var (
		cmds    []tea.Cmd
		waiting bool
	)

	for _, w := range marked {
		state, seen := m.plans[planKey(w)]

		switch {
		case state.err != nil:
			m.err = fmt.Errorf("approval is disabled until %s can be reviewed: %w", w.Ref(), state.err)

			return nil
		case !seen:
			cmds = append(cmds, m.loadPlanFor(w))

			waiting = true
		case state.loading:
			waiting = true
		}
	}

	if waiting {
		m.status = "Still reading the plans; try again in a moment."

		return tea.Batch(cmds...)
	}

	if ok, _ := m.batchPlans(); len(ok) == 0 {
		m.status = "Every selected plan deletes resources; approve those one at a time."

		return nil
	}

	m.mode = modeConfirmBatch

	return nil
}

// approveBatch approves the plans shown in the review, one at a time, each
// only if it is still exactly the plan that was read.
func (m Model) approveBatch() (tea.Model, tea.Cmd) {
	targets, destroying := m.batchPlans()
	reviewed := map[string]plan.Plan{}
	m.batch = batch{active: true, busy: true, started: time.Now()}

	for _, w := range targets {
		reviewed[w.Ref()] = m.plans[planKey(w)].plan
		m.batch.results = append(m.batch.results, batchResult{ref: w.Ref(), appliedBefore: w.LastAppliedRevision})
	}

	for _, w := range destroying {
		m.batch.results = append(m.batch.results, batchResult{ref: w.Ref(), skipped: "deletes resources; approve it on its own"})
	}

	api := m.api
	m.mode = modeList
	m.err, m.status = nil, ""

	return m, func() tea.Msg {
		out := batchMsg{failed: map[string]error{}}

		for _, w := range targets {
			ref, want := w.Ref(), reviewed[w.Ref()]

			err := func() error {
				ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
				defer cancel()

				current, err := api.ReadPlan(ctx, w.Namespace, objectName(w))
				if err != nil {
					return fmt.Errorf("re-reading plan before approval: %w", err)
				}

				if current.SHA256 != want.SHA256 || current.ID != want.ID {
					return errors.New("the plan changed since you reviewed it; nothing was approved")
				}

				_, err = api.Approve(ctx, ref, want.ID, false)

				return err
			}()

			if err != nil {
				out.failed[ref] = err

				continue
			}

			out.approved = append(out.approved, ref)
		}

		return out
	}
}

// watching reports whether an approval is still applying and worth polling fast.
func (m Model) watching() bool {
	if m.outcome.ref != "" && !m.outcomeDone() {
		return true
	}

	return m.batch.active && !m.batchDone()
}

// batchDone reports that every approved plan in the batch has finished or failed.
func (m Model) batchDone() bool {
	if m.batch.busy {
		return false
	}

	// Stop polling quickly if the applies never show up.
	if time.Since(m.batch.started) > 15*time.Minute {
		return true
	}

	for _, r := range m.batch.results {
		if r.skipped != "" || r.err != nil {
			continue
		}

		for _, w := range m.workspaces {
			if w.Ref() != r.ref {
				continue
			}

			if !w.Failed() && !applied(w, r.appliedBefore) {
				return false
			}
		}
	}

	return true
}

// applied reports that a workspace finished applying since the revision before.
func applied(w floorclient.Workspace, before string) bool {
	return w.PendingPlan == "" && w.Phase != "Progressing" && w.LastAppliedRevision != before
}

// batchSummary totals the changes of every plan in the batch.
func (m Model) batchSummary(targets []floorclient.Workspace) string {
	var all plan.Plan

	for _, w := range targets {
		all.Changes = append(all.Changes, m.plans[planKey(w)].plan.Changes...)
	}

	return all.Summary()
}
