package tui

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"

	"github.com/osinfra-io/factory/cli/internal/floorclient"
	"github.com/osinfra-io/factory/cli/internal/plan"
)

const (
	headerH  = 3
	cardH    = 6
	paneGap  = 2
	minWidth = 60
	minRows  = 16
	tabsRow  = 3
	// chromeRows are the right pane lines above the tab content.
	chromeRows = 5
)

var (
	hintKey = lipgloss.NewStyle().Bold(true).Foreground(accent)
	tabOn   = lipgloss.NewStyle().Bold(true).Foreground(accent)
	tabOff  = lipgloss.NewStyle().Foreground(muted)
)

// hit is a clickable region; key is a key press or a card:/tab: command.
type hit struct {
	x0, x1, y0, y1 int
	key            string
}

func (h hit) contains(x, y int) bool { return x >= h.x0 && x < h.x1 && y >= h.y0 && y < h.y1 }

type seg struct {
	text string
	key  string
}

// segments renders clickable pieces on one row starting at column x, and
// reports where each landed.
func segments(segs []seg, x, y, gap int) (string, []hit) {
	var (
		parts []string
		hits  []hit
	)

	for _, s := range segs {
		w := lipgloss.Width(s.text)

		if s.key != "" {
			hits = append(hits, hit{x0: x, x1: x + w, y0: y, y1: y + 1, key: s.key})
		}

		parts = append(parts, s.text)
		x += w + gap
	}

	return strings.Join(parts, strings.Repeat(" ", gap)), hits
}

func trunc(s string, w int) string { return ansi.Truncate(s, max(w, 1), "…") }

// truncLeft keeps the end of s, where workspace references differ.
func truncLeft(s string, w int) string {
	w = max(w, 2)
	if lipgloss.Width(s) <= w {
		return s
	}

	return ansi.TruncateLeft(s, lipgloss.Width(s)-(w-1), "…")
}

func actionLabel(actions []string) string {
	switch strings.Join(actions, "+") {
	case "delete+create", "create+delete":
		return "replace"
	default:
		return strings.Join(actions, "+")
	}
}

func (m Model) size() (int, int) {
	w, h := m.width, m.height
	if w == 0 {
		w = 100
	}

	if h == 0 {
		h = 30
	}

	return max(w, minWidth), max(h, minRows)
}

func (m Model) leftWidth(w int) int { return min(max(w/3, 34), 44) }

// View renders the header, workspace cards, detail pane and footer.
func (m Model) View() string {
	v, _ := m.frame()

	return v
}

// frame lays out the screen and the clickable regions on it.
func (m Model) frame() (string, []hit) {
	w, h := m.size()
	foot, footHits := m.footer(w, h)
	bodyH := h - headerH - lipgloss.Height(foot)
	leftW := m.leftWidth(w)
	rightW := w - leftW - paneGap

	cards, cardHits := m.cards(leftW, bodyH)
	right, rightHits := m.pane(leftW+paneGap, rightW, bodyH)

	body := lipgloss.JoinHorizontal(lipgloss.Top,
		lipgloss.NewStyle().Width(leftW).Height(bodyH).MaxHeight(bodyH).Render(cards),
		strings.Repeat(" ", paneGap),
		lipgloss.NewStyle().Width(rightW).Height(bodyH).MaxHeight(bodyH).Render(right),
	)

	head, headHits := m.header(w)
	out := lipgloss.JoinVertical(lipgloss.Left, head, body, foot)

	hits := make([]hit, 0, len(cardHits)+len(rightHits)+len(footHits)+len(headHits))
	for _, hit := range append(cardHits, rightHits...) {
		if hit.y0 >= headerH && hit.y1 <= headerH+bodyH {
			hits = append(hits, hit)
		}
	}
	hits = append(hits, footHits...)

	if m.envMenu {
		var menuHits []hit

		out, menuHits = m.overlayEnvMenu(out, w)
		hits = append(hits, menuHits...)
	}

	return out, append(hits, headHits...)
}

// envLabel is the environment name, with a dropdown arrow when switchable.
func (m Model) envLabel() string {
	if m.switchable() {
		return m.environment + " ▾"
	}

	return m.environment
}

func (m Model) header(w int) (string, []hit) {
	left := hintKey.Render("🏭 Factory")
	if alert := m.tokenAlert(); alert != "" {
		left += "   " + alert
	}

	label := m.envLabel()
	right := dim.Render(label)
	var hits []hit

	if m.switchable() {
		rw := lipgloss.Width(label)
		x := w - 2 - rw
		hits = append(hits, hit{x0: x - 1, x1: w, y0: 0, y1: headerH, key: "envmenu"})
		right = hintKey.Render(label)
	}

	// Optional details only appear when the terminal is wide enough for them.
	if info := m.info[m.environment]; info != "" {
		withInfo := dim.Render(info+"  ·  ") + right
		if lipgloss.Width(left)+lipgloss.Width(withInfo)+6 <= w-4 {
			right = withInfo
		}
	}

	if lipgloss.Width(left)+lipgloss.Width(right)+2 > w-4 {
		left = hintKey.Render("🏭 Factory")
	}

	pad := max(w-4-lipgloss.Width(left)-lipgloss.Width(right), 1)

	return panel.Width(w - 2).Render(left + strings.Repeat(" ", pad) + right), hits
}

// overlayEnvMenu draws the dropdown over the body, right-aligned under the
// header, and returns a click region for each environment.
func (m Model) overlayEnvMenu(out string, w int) (string, []hit) {
	inner := 0
	for _, name := range m.environments {
		inner = max(inner, lipgloss.Width(name))
	}

	inner = max(inner, lipgloss.Width(m.envLabel())-2)

	rows := make([]string, len(m.environments))
	for i, name := range m.environments {
		cell := " " + name + strings.Repeat(" ", inner-lipgloss.Width(name)) + " "

		switch {
		case i == m.envCursor:
			cell = lipgloss.NewStyle().Foreground(accent).Bold(true).Render(cell)
		case name == m.environment:
			cell = lipgloss.NewStyle().Foreground(green).Render(cell)
		}

		rows[i] = cell
	}

	box := strings.Split(lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(border).Render(strings.Join(rows, "\n")), "\n")
	x := w - lipgloss.Width(box[0])
	lines := strings.Split(out, "\n")

	var hits []hit

	for i, b := range box {
		y := headerH + i
		if y >= len(lines) {
			break
		}

		lines[y] = ansi.Truncate(lines[y], x, "") + b

		if i > 0 && i <= len(m.environments) {
			hits = append(hits, hit{x0: x, x1: w, y0: y, y1: y + 1, key: "env:" + m.environments[i-1]})
		}
	}

	return strings.Join(lines, "\n"), hits
}

func (m Model) cards(leftW, bodyH int) (string, []hit) {
	v := m.visible()
	inner := leftW - 4

	if len(v) == 0 {
		msg := "No plans are waiting for approval."
		hint := fmt.Sprintf("Press p (or click) to see all %d workspaces.", len(m.workspaces))
		key := "p"

		if len(m.workspaces) == 0 {
			hint = "No workspaces loaded yet. Press R to refresh."
			key = "R"
		}

		if !m.pendingOnly {
			msg, hint = "No workspaces found.", "Press R to refresh."
			key = "R"
		}

		box := panel.Width(leftW - 2).Height(cardH - 2).Render(dim.Render(trunc(msg, inner)) + "\n" + dim.Render(trunc(hint, inner)))

		return box, []hit{{x0: 0, x1: leftW, y0: headerH, y1: headerH + cardH, key: key}}
	}

	return m.list(v, leftW, bodyH)
}

// needsYou reports that a workspace is awaiting approval or failed, which is
// when its full card with actions is worth the space. Applying is only progress.
func (m Model) needsYou(w floorclient.Workspace) bool {
	return w.PendingPlan != "" || w.Failed() || w.Ref() == m.outcome.ref
}

func sidebarOrder(v []floorclient.Workspace) []int {
	order := make([]int, len(v))
	for i := range v {
		order[i] = i
	}
	sort.SliceStable(order, func(i, j int) bool {
		return v[order[i]].Namespace < v[order[j]].Namespace
	})
	return order
}

// list groups workspace cards and compact rows under namespace headings.
func (m Model) list(v []floorclient.Workspace, leftW, bodyH int) (string, []hit) {
	type block struct {
		index     int
		namespace string
		h         int
	}

	var blocks []block
	var lastNamespace string
	for pos, i := range sidebarOrder(v) {
		ns := v[i].Namespace
		if pos == 0 || ns != lastNamespace {
			blocks = append(blocks, block{index: -1, namespace: ns, h: 1})
			lastNamespace = ns
		}
		if m.sidebarCollapsed[ns] {
			continue
		}
		h := 1
		if m.needsYou(v[i]) {
			h = cardH
		}
		blocks = append(blocks, block{index: i, h: h})
	}

	cursorBlock := 0
	for bi, b := range blocks {
		if b.index == m.cursor || (b.index < 0 && m.cursor < len(v) && b.namespace == v[m.cursor].Namespace) {
			cursorBlock = bi
		}
	}

	start, used := 0, 0
	for bi := cursorBlock; bi >= 0; bi-- {
		if used+blocks[bi].h > bodyH {
			break
		}

		used += blocks[bi].h
		start = bi
	}

	sticky := ""
	if blocks[start].index >= 0 {
		ns := v[blocks[start].index].Namespace
		for start < cursorBlock && used+1 > bodyH {
			used -= blocks[start].h
			start++
		}
		if blocks[start].index >= 0 && used+1 <= bodyH {
			sticky = ns
		}
	}

	var (
		out  []string
		hits []hit
		top  = headerH
	)
	addNamespace := func(ns string) {
		arrow := "▾ "
		if m.sidebarCollapsed[ns] {
			arrow = "▸ "
		}
		out = append(out, dim.Render(arrow)+bold.Render(trunc(ns, leftW-2)))
		hits = append(hits, hit{x0: 0, x1: leftW, y0: top, y1: top + 1, key: "sidebar-ns:" + ns})
		top++
	}
	if sticky != "" {
		addNamespace(sticky)
	}

	for _, b := range blocks[start:] {
		if top+b.h > headerH+bodyH {
			break
		}

		switch {
		case b.index < 0:
			addNamespace(b.namespace)
			continue
		case m.needsYou(v[b.index]):
			c, h := m.card(v[b.index], b.index, leftW-2, top)
			out = append(out, lipgloss.NewStyle().PaddingLeft(2).Render(c))
			for i := range h {
				h[i].x0 += 2
				h[i].x1 += 2
			}
			hits = append(hits, h...)
		default:
			c, h := m.row(v[b.index], b.index, leftW, top)
			out = append(out, c)
			hits = append(hits, h)
		}

		top += b.h
	}

	return strings.Join(out, "\n"), hits
}

// row is the one-line form of a workspace that needs nothing from you.
func (m Model) row(w floorclient.Workspace, i, leftW, top int) (string, hit) {
	name := truncLeft(strings.TrimPrefix(w.Ref(), w.Namespace+"/"), leftW-7)

	line := "    " + statusDot(w) + " " + name
	if i == m.cursor && !m.home {
		accented := lipgloss.NewStyle().Bold(true).Foreground(accent)
		line = "  " + accented.Render("› ") + statusDot(w) + " " + accented.Render(name)
	}

	return line, hit{x0: 0, x1: leftW, y0: top, y1: top + 1, key: fmt.Sprintf("card:%d", i)}
}

// card is the boxed form of a workspace that needs you, with its actions
// when selected.
func (m Model) card(w floorclient.Workspace, i, leftW, top int) (string, []hit) {
	selected := i == m.cursor && !m.home
	hits := []hit{{x0: 0, x1: leftW, y0: top, y1: top + cardH, key: fmt.Sprintf("card:%d", i)}}
	actions := ""

	if selected {
		var ah []hit

		list := []seg{
			{shortcut("approve", green), "a"},
			{shortcut("reject", red), "r"},
			{shortcut("details", blue), "d"},
		}
		if w.PendingPlan == "" || w.Approved {
			list = list[2:]
		}

		actions, ah = segments(list, 2, top+1+3, 3)
		hits = append(hits, ah...)
	}

	if markable(w) {
		hits = append(hits, hit{x0: 0, x1: 6, y0: top + 1, y1: top + 2, key: fmt.Sprintf("mark:%d", i)})
	}

	return card(w, selected, m.marked[w.Ref()], leftW, actions), hits
}

func card(ws floorclient.Workspace, selected, marked bool, leftW int, actions string) string {
	inner := leftW - 4

	status := ws.Status()
	line := statusText(ws).Render(status)

	if ws.PendingPlan != "" {
		line += dim.Render(" · " + trunc(ws.ShortPlan(), inner-len(status)-3))
	}

	colour := border
	if selected {
		colour = accent
	}

	dot := statusDot(ws)

	switch {
	case marked:
		dot = lipgloss.NewStyle().Foreground(green).Render("◉")
	}

	lines := []string{
		dot + " " + bold.Render(truncLeft(strings.TrimPrefix(ws.Ref(), ws.Namespace+"/"), inner-2)),
		dim.Render(strings.Repeat("─", inner)),
		line,
		actions,
	}

	return panel.BorderForeground(colour).Width(leftW - 2).Render(strings.Join(lines, "\n"))
}

func statusText(ws floorclient.Workspace) lipgloss.Style {
	switch {
	case ws.PendingPlan != "" && ws.Approved:
		return lipgloss.NewStyle().Bold(true).Foreground(blue)
	case ws.PendingPlan != "":
		return lipgloss.NewStyle().Bold(true).Foreground(yellow)
	default:
		return lipgloss.NewStyle().Foreground(phaseColour(ws))
	}
}

// phaseColour maps a workspace phase to green (healthy), amber (waiting)
// or red (failed). Waiting is yellow so it never matches the
// amber used for the selection.
func phaseColour(w floorclient.Workspace) lipgloss.Color {
	phase := strings.ToLower(w.Phase)

	switch {
	case w.Waiting(), w.Phase == "DriftDetected":
		return yellow
	case strings.Contains(phase, "fail"), strings.Contains(phase, "error"):
		return red
	default:
		return green
	}
}

// rowsAvailable is how many change rows fit in the pane.
func rowsAvailable(bodyH int, destroys bool) int {
	n := bodyH - chromeRows - 3 - 2
	if destroys {
		n -= 2
	}

	return max(n, 1)
}

func (m Model) pane(x, w, bodyH int) (string, []hit) {
	ws, ok := m.selected()
	cw := w - 2

	if !ok {
		return m.overview(x, cw, bodyH)
	}

	if m.mode == modeConfirmBatch {
		return m.batchReview(cw), nil
	}

	if m.batch.active {
		return m.batchProgress(cw), nil
	}

	state := m.planState(ws)

	changes := len(state.plan.Changes)
	banner, _ := m.banner()
	if banner == "" {
		banner = m.summaryLine(ws, state)
	}

	tabSegs := []seg{
		{tabLabel(m.tab == tabChanges, fmt.Sprintf("Changes (%d)", changes)), "tab:changes"},
		{tabLabel(m.tab == tabDetails, "Details"), "tab:details"},
		{tabLabel(m.tab == tabDependencies, "Dependencies"), "tab:dependencies"},
	}
	if m.tab == tabDiff || m.hasDiff() {
		diff := seg{tabLabel(m.tab == tabDiff, "Diff"), "tab:diff"}
		tabSegs = append(tabSegs[:2:2], append([]seg{diff}, tabSegs[2:]...)...)
	}

	tabs, hits := segments(tabSegs, x+1, headerH+tabsRow, 4)

	lines := []string{
		statusDot(ws) + " " + bold.Render(truncLeft(ws.Ref(), cw-2)),
		trunc(banner, cw),
		"",
		tabs,
		dim.Render(strings.Repeat("─", cw)),
	}

	switch m.tab {
	case tabDetails:
		body, h := m.details(ws, state, x+1, cw)
		lines = append(lines, body...)
		hits = append(hits, h...)
	case tabDiff:
		lines = append(lines, m.diffLines(ws, cw, bodyH)...)
	case tabDependencies:
		body, h := m.dependencies(ws, x+1, cw)
		lines = append(lines, body...)
		hits = append(hits, h...)
	default:
		body, h := m.changes(ws, state, x+1, cw, bodyH)
		lines = append(lines, body...)
		hits = append(hits, h...)
	}

	for i, l := range lines {
		lines[i] = " " + l
	}

	return strings.Join(lines, "\n"), hits
}

func tabLabel(active bool, label string) string {
	if active {
		return tabOn.Render(label)
	}

	return tabOff.Render(label)
}

var (
	errReason   = regexp.MustCompile(`"reason":\s*"([^"]+)"`)
	errResource = regexp.MustCompile(`with\s+(\S+?),\s+on\s+(\S+) line (\d+)`)
)

var (
	errSnippet  = regexp.MustCompile(`^\d+:`)
	errProvider = regexp.MustCompile(`provider\["([^"]+)"\]`)
	errApplying = regexp.MustCompile(`applying changes to (\S+?),`)
)

// errDetail is the explanation tofu prints after the error summary, resource
// location and source snippet, as one entry per paragraph.
func errDetail(msg string) []string {
	var (
		paras   []string
		current []string
		inError bool
	)

	flush := func() {
		if len(current) > 0 {
			paras = append(paras, tidy(strings.Join(current, " ")))
			current = nil
		}
	}

	for _, l := range strings.Split(msg, "\n") {
		l = strings.TrimSpace(l)

		switch {
		case strings.HasPrefix(l, "Error:"):
			inError, paras, current = true, nil, nil
		case !inError || l == "":
			flush()
		case strings.HasPrefix(l, "with ") || strings.HasPrefix(l, "on ") || errSnippet.MatchString(l):
			flush()
		default:
			current = append(current, l)
		}
	}

	flush()

	return paras
}

// tidy removes the escaping tofu leaves in provider addresses.
func tidy(s string) string {
	s = strings.ReplaceAll(s, `\"`, `"`)

	return errProvider.ReplaceAllString(s, "$1")
}

// problemLines explains a failed workspace as a short summary pulled from the
// controller's message: the error, the resource and the machine reason, with
// a pointer for the one failure that has a known fix.
func problemLines(ws floorclient.Workspace, cw int) []string {
	lines := []string{errText.Render("✗ " + ws.PhaseText()), ""}

	row := func(label, value string) {
		if len(lines) > 2 {
			lines = append(lines, "")
		}

		wrapped := wrap(value, max(cw-14, 20))
		for i, l := range wrapped {
			prefix := strings.Repeat(" ", 13)
			if i == 0 {
				prefix = dim.Render(fmt.Sprintf("%-13s", label))
			}

			lines = append(lines, prefix+" "+l)
		}
	}

	msg := ws.Message

	var summary string

	for _, l := range strings.Split(msg, "\n") {
		if l = strings.TrimSpace(l); strings.HasPrefix(l, "Error:") {
			summary = strings.TrimSpace(strings.TrimPrefix(l, "Error:"))

			break
		}
	}

	if summary == "" {
		for _, l := range strings.Split(msg, "\n") {
			if l = strings.TrimSpace(l); l != "" {
				summary = l

				break
			}
		}
	}

	if summary == "" {
		summary = "Floor has no further detail from the controller."
	}

	row("Error", summary)

	if m := errResource.FindStringSubmatch(msg); m != nil {
		row("Resource", m[1]+" · "+m[2]+" line "+m[3])
	} else if m := errApplying.FindStringSubmatch(msg); m != nil {
		row("Resource", m[1])
	}

	for i, paragraph := range errDetail(msg) {
		label := ""
		if i == 0 {
			label = "Why"
		}

		row(label, paragraph)
	}

	if m := errReason.FindStringSubmatch(msg); m != nil {
		row("Reason", m[1])
	}

	if strings.Contains(msg, "cannot re-use a name that is still in use") {
		row("Likely cause", "A Helm release with this name is already installed in the cluster, usually left by an earlier run.")
		row("Fix", "Uninstall or import that release, then replan.")
	}

	if strings.Contains(msg, "401") || strings.Contains(msg, "invalid authentication credentials") {
		row("Likely cause", "The runner's short-lived Google credential expired.")
		row("Fix", "bash bootstrap/seed/prepare.sh")
	}

	return lines
}

// wrap splits text on spaces into lines of at most width characters.
func wrap(text string, width int) []string {
	var (
		lines []string
		line  string
	)

	for _, word := range strings.Fields(text) {
		if line != "" && len(line)+1+len(word) > width {
			lines = append(lines, line)
			line = ""
		}

		if line != "" {
			line += " "
		}

		line += word
	}

	return append(lines, line)
}

// dependencies renders what the workspace waits on and what waits on it as
// two trees. Each node is clickable and jumps to that workspace.
func (m Model) dependencies(ws floorclient.Workspace, x, cw int) ([]string, []hit) {
	byRef := map[string]floorclient.Workspace{}
	dependents := map[string][]string{}

	for _, w := range m.workspaces {
		byRef[fullRef(w)] = w

		for _, d := range w.DependsOn {
			dependents[d] = append(dependents[d], fullRef(w))
		}
	}

	var (
		lines []string
		hits  []hit
	)

	node := func(ref, prefix string) {
		w, found := byRef[ref]
		label := ref

		if !found {
			lines = append(lines, prefix+dim.Render("? "+label+" · not listed by Floor"))

			return
		}

		phase := dim.Render(" · ") + lipgloss.NewStyle().Foreground(phaseColour(w)).Render(w.PhaseText())

		y := headerH + chromeRows + len(lines)
		hits = append(hits, hit{x0: x, x1: x + cw, y0: y, y1: y + 1, key: "dep:" + ref})
		lines = append(lines, prefix+statusDot(w)+" "+label+phase)
	}

	var walk func(ref string, next func(string) []string, depth int, seen map[string]bool)

	walk = func(ref string, next func(string) []string, depth int, seen map[string]bool) {
		for _, child := range next(ref) {
			node(child, strings.Repeat("  ", depth)+dim.Render("└ "))

			if !seen[child] {
				seen[child] = true
				walk(child, next, depth+1, seen)
			}
		}
	}

	self := fullRef(ws)
	upstream := func(ref string) []string { return byRef[ref].DependsOn }
	downstream := func(ref string) []string { return dependents[ref] }

	lines = append(lines, bold.Render("Depends on"), statusDot(ws)+" "+self)

	if len(ws.DependsOn) == 0 {
		lines = append(lines, dim.Render("└ nothing; this workspace has no dependencies"))
	}

	walk(self, upstream, 0, map[string]bool{self: true})

	lines = append(lines, "", bold.Render("Required by"), statusDot(ws)+" "+self)

	if len(dependents[self]) == 0 {
		lines = append(lines, dim.Render("└ nothing depends on this workspace"))
	}

	walk(self, downstream, 0, map[string]bool{self: true})

	lines = append(lines, "", dim.Render("click a workspace to jump to it · esc to go back"))

	return lines, hits
}

// batchReview lists what a batch approval will start, plan by plan.
func (m Model) batchReview(cw int) string {
	ok, destroying := m.batchPlans()
	lines := []string{bold.Render(fmt.Sprintf("Approve %d plans", len(ok))), dim.Render(m.batchSummary(ok) + " in total"), ""}

	for _, w := range ok {
		p := m.plans[planKey(w)].plan

		lines = append(lines, " "+lipgloss.NewStyle().Foreground(green).Render("◉")+" "+bold.Render(trunc(w.Ref(), cw-4)))
		lines = append(lines, "     "+dim.Render(p.Summary()+" · plan "+w.ShortPlan()))
	}

	if len(destroying) > 0 {
		lines = append(lines, "", errText.Render("Not included: these plans delete resources. Approve them one at a time."))

		for _, w := range destroying {
			lines = append(lines, "   "+dim.Render(trunc(w.Ref(), cw-4)))
		}
	}

	lines = append(lines, "", dim.Render("Each plan is re-read and checked against what you reviewed before it is approved."))

	return strings.Join(lines, "\n")
}

// batchProgress shows one line per plan of the last batch approval, kept live
// from Floor so it follows each apply to the end.
func (m Model) batchProgress(cw int) string {
	ok := lipgloss.NewStyle().Foreground(green)
	wait := lipgloss.NewStyle().Foreground(yellow)
	work := lipgloss.NewStyle().Foreground(blue)

	var (
		lines    []string
		approved int
		failed   int
	)

	for _, r := range m.batch.results {
		name := bold.Render(trunc(r.ref, cw-4))

		switch {
		case r.skipped != "":
			lines = append(lines, "", dim.Render("○ ")+name, "    "+dim.Render("Not included: "+r.skipped+"."))
		case r.err != nil:
			failed++

			lines = append(lines, "", errText.Render("✗ ")+name)
			for _, l := range wrap(r.err.Error(), max(cw-6, 20)) {
				lines = append(lines, "    "+errText.Render(l))
			}
		case !r.done:
			lines = append(lines, "", work.Render("◐ ")+name, "    "+dim.Render("Approving…"))
		default:
			approved++

			lines = append(lines, "")
			lines = append(lines, m.batchRow(r, name, ok, wait, work, cw)...)
		}
	}

	title := fmt.Sprintf("Approving %d plans…", len(m.batch.results))

	if !m.batch.busy {
		title = fmt.Sprintf("Approved %d of %d plans", approved, len(m.batch.results))
		if failed > 0 {
			title += fmt.Sprintf(" · %d failed", failed)
		}
	}

	lines = append([]string{bold.Render(title)}, lines...)

	return strings.Join(append(lines, "", dim.Render("Floor applies each plan as its dependencies are ready. Select a plan to see its detail; esc closes this list.")), "\n")
}

// batchRow is the live status of one approved plan in a batch.
func (m Model) batchRow(r batchResult, name string, ok, wait, work lipgloss.Style, cw int) []string {
	for _, w := range m.workspaces {
		if w.Ref() != r.ref {
			continue
		}

		switch {
		case w.Failed():
			lines := []string{errText.Render("✗ ") + name, "    " + errText.Render(w.PhaseText())}
			for _, l := range wrap(firstProblem(w), max(cw-6, 20)) {
				lines = append(lines, "    "+dim.Render(l))
			}

			return lines
		case applied(w, r.appliedBefore):
			return []string{ok.Render("✓ ") + name, "    " + ok.Render("Applied")}
		case len(m.blockers(w)) > 0:
			var refs []string
			for _, b := range m.blockers(w) {
				refs = append(refs, fullRef(b))
			}

			return []string{wait.Render("◐ ") + name, "    " + dim.Render("Approved · waiting on "+strings.Join(refs, ", "))}
		default:
			return []string{work.Render("◐ ") + name, "    " + dim.Render("Approved · "+w.PhaseText())}
		}
	}

	return []string{work.Render("◐ ") + name, "    " + dim.Render("Approved")}
}

// summaryLine is the one-line status under the workspace title.
func (m Model) summaryLine(ws floorclient.Workspace, state planState) string {
	line := statusText(ws).Render(ws.Status())

	if n := len(state.plan.Changes); n > 0 {
		line += dim.Render(fmt.Sprintf(" · %d changes", n))

		if state.plan.Destroys() {
			line += errText.Render(" · deletes resources")
		} else {
			line += dim.Render(" · no deletes")
		}
	}

	return line
}

// blockers returns the workspaces at the root of an unhealthy dependency
// chain: not healthy themselves and not waiting on anything else.
func (m Model) blockers(ws floorclient.Workspace) []floorclient.Workspace {
	var (
		out  []floorclient.Workspace
		seen = map[string]bool{}
		walk func(floorclient.Workspace)
	)

	walk = func(w floorclient.Workspace) {
		for _, ref := range w.DependsOn {
			if seen[ref] {
				continue
			}

			seen[ref] = true

			for _, d := range m.workspaces {
				if fullRef(d) != ref || phaseColour(d) == green {
					continue
				}

				before := len(out)

				walk(d)

				if len(out) == before {
					out = append(out, d)
				}
			}
		}
	}

	walk(ws)

	return out
}

// progressLines shows how far an approved plan has got: approval, its
// dependencies, then the apply, naming whatever is holding it up.
func (m Model) progressLines(ws floorclient.Workspace, cw int) []string {
	ok := lipgloss.NewStyle().Foreground(green)
	wait := lipgloss.NewStyle().Foreground(yellow)
	work := lipgloss.NewStyle().Foreground(blue)

	approved := "✓ Approved"
	if ws.ApprovedBy != "" {
		approved += dim.Render(" · " + ws.ApprovedBy + " · " + approvedAt(ws.ApprovedAt))
	}

	lines := []string{bold.Render("Progress"), "", ok.Render(approved[:len("✓ Approved")]) + approved[len("✓ Approved"):]}
	blocked := m.blockers(ws)

	switch {
	case len(blocked) > 0:
		lines = append(lines, wait.Render("◐ Waiting on dependencies"))

		for _, b := range blocked {
			lines = append(lines, "    "+statusDot(b)+" "+fullRef(b)+dim.Render(" · "+b.PhaseText()))

			if b.Failed() {
				for _, l := range wrap(firstProblem(b), max(cw-8, 20)) {
					lines = append(lines, "      "+dim.Render(l))
				}

				if strings.Contains(b.Message, "401") {
					lines = append(lines, "      "+dim.Render("Fix: bash bootstrap/seed/prepare.sh"))
				}
			}
		}

		lines = append(lines, dim.Render("○ Apply starts automatically once these are ready"))
	case ws.Phase == "TerraformAppliedSucceed":
		lines = append(lines, ok.Render("✓ Dependencies ready"), ok.Render("✓ Applied"))
	case ws.Failed():
		lines = append(lines, ok.Render("✓ Dependencies ready"), errText.Render("✗ "+ws.PhaseText()))

		for _, l := range wrap(firstProblem(ws), max(cw-4, 20)) {
			lines = append(lines, "    "+dim.Render(l))
		}
	default:
		lines = append(lines, ok.Render("✓ Dependencies ready"), work.Render("◐ Applying · "+ws.PhaseText()))
		lines = append(lines, m.activityLines(ws, cw)...)
	}

	return append(lines, "")
}

// activityLines lists what the runner reports for an applying workspace:
// how many resources are done and which are still running.
func (m Model) activityLines(ws floorclient.Workspace, cw int) []string {
	act, ok := m.activity[ws.Ref()]
	if !ok || len(act.Steps) == 0 {
		return nil
	}

	var done int

	var running []plan.Step

	for _, s := range act.Steps {
		if s.Done {
			done++
		} else {
			running = append(running, s)
		}
	}

	lines := []string{dim.Render(fmt.Sprintf("    %d resources finished · %d running", done, len(running)))}

	for _, s := range running {
		elapsed := ""
		if s.Elapsed != "" {
			elapsed = " · " + s.Elapsed
		}

		lines = append(lines, "    "+lipgloss.NewStyle().Foreground(blue).Render("◐ ")+trunc(shortAddress(s.Address), max(cw-24, 20))+dim.Render(" · "+s.Verb+elapsed))
	}

	// Keep the last few finished resources so progress is visible.
	finished := 0

	for i := len(act.Steps) - 1; i >= 0 && finished < 3; i-- {
		if s := act.Steps[i]; s.Done {
			lines = append(lines, "    "+lipgloss.NewStyle().Foreground(green).Render("✓ ")+trunc(shortAddress(s.Address), max(cw-24, 20))+dim.Render(" · "+s.Elapsed))

			finished++
		}
	}

	return lines
}

// shortAddress drops the module path, keeping the resource that is changing.
func shortAddress(addr string) string {
	if i := strings.LastIndex(addr, "]."); i >= 0 {
		return addr[i+2:]
	}

	if i := strings.LastIndex(addr, "."); i >= 0 && strings.HasPrefix(addr, "module.") {
		parts := strings.Split(addr, ".")
		if len(parts) >= 2 {
			return strings.Join(parts[len(parts)-2:], ".")
		}
	}

	return addr
}

// firstProblem is the controller's one-line error summary.
func firstProblem(ws floorclient.Workspace) string {
	for _, l := range strings.Split(ws.Message, "\n") {
		if l = strings.TrimSpace(l); strings.HasPrefix(l, "Error:") {
			problem := strings.TrimSpace(strings.TrimPrefix(l, "Error:"))
			if detail := errDetail(ws.Message); len(detail) > 0 {
				problem += ": " + detail[0]
			}

			return problem
		}
	}

	for _, l := range strings.Split(ws.Message, "\n") {
		if l = strings.TrimSpace(l); l != "" {
			return l
		}
	}

	return ""
}

func (m Model) changes(ws floorclient.Workspace, state planState, x, cw, bodyH int) ([]string, []hit) {
	switch {
	case ws.PendingPlan == "" && ws.Failed():
		return problemLines(ws, cw), nil
	case ws.PendingPlan == "" && state.plan.ID == "":
		return []string{dim.Render("No plan is waiting for approval for this workspace.")}, nil
	case state.loading:
		return []string{dim.Render("Reading plan…")}, nil
	case ws.Approved && len(state.plan.Changes) == 0:
		return m.progressLines(ws, cw), nil
	case state.err != nil:
		return []string{errText.Render(trunc("Plan unavailable: "+state.err.Error(), cw*3))}, nil
	}

	var create, update, del, replace, outputs int

	for _, c := range state.plan.Changes {
		if c.Output {
			outputs++

			continue
		}

		switch strings.Join(c.Actions, "+") {
		case "create":
			create++
		case "update":
			update++
		case "delete":
			del++
		default:
			replace++
		}
	}

	add, change, destroy := create+replace, update, del+replace
	summary := fmt.Sprintf("Plan: %d to add, %d to change, %d to destroy.", add, change, destroy)
	if outputs > 0 {
		summary += fmt.Sprintf(" %d output %s.", outputs, plural(outputs, "change", "changes"))
	}

	summary = bold.Render(summary)

	destroys := state.plan.Destroys()

	var progress []string
	if ws.Approved {
		progress = m.progressLines(ws, cw)
	}

	avail := max(rowsAvailable(bodyH, destroys)-len(progress), 3)

	type row struct {
		text string
		key  string
	}

	var rows []row

	for i, c := range state.plan.Changes {
		marker := "▸"
		expanded := m.expandAll || m.open == i+1
		if expanded {
			marker = "▾"
		}

		address := trunc(c.Address, cw-16)
		if expanded {
			address = bold.Render(address)
		}

		text := fmt.Sprintf("%s %s %-9s %s", dim.Render(marker), actionSymbol(c.Actions), actionLabel(c.Actions), address)

		rows = append(rows, row{text: text, key: fmt.Sprintf("change:%d", i)})

		if !expanded {
			continue
		}

		for _, l := range changeBlock(c, cw-4) {
			rows = append(rows, row{text: "    " + l})
		}
	}

	start := min(m.scroll, max(len(rows)-avail, 0))
	end := min(start+avail, len(rows))

	lines := append(progress, summary, "", dim.Render(fmt.Sprintf("    %-9s %s", "ACTION", "RESOURCE")))

	var hits []hit

	// The scrollbar thumb marks which slice of the rows is on screen.
	thumbStart, thumbEnd := -1, -1
	if len(rows) > avail {
		size := max(avail*avail/len(rows), 1)
		thumbStart = start * (avail - size) / max(len(rows)-avail, 1)
		thumbEnd = thumbStart + size
	}

	for i, r := range rows[start:end] {
		if r.key != "" {
			y := headerH + chromeRows + len(lines)
			hits = append(hits, hit{x0: x, x1: x + cw - 2, y0: y, y1: y + 1, key: r.key})
		}

		text := r.text
		if thumbStart >= 0 {
			bar := dim.Render("│")
			if i >= thumbStart && i < thumbEnd {
				bar = lipgloss.NewStyle().Foreground(accent).Render("┃")
			}

			text = ansi.Truncate(text, cw-2, "") + strings.Repeat(" ", max(cw-2-lipgloss.Width(ansi.Truncate(text, cw-2, "")), 0)) + " " + bar
		}

		lines = append(lines, text)
	}

	for len(lines) < len(progress)+3+avail {
		lines = append(lines, "")
	}

	lines = append(lines, "")

	if len(rows) > avail {
		lines = append(lines, dim.Render(trunc(fmt.Sprintf("lines %d–%d of %d · e expands all · wheel scrolls", start+1, end, len(rows)), cw)))
	} else {
		lines = append(lines, dim.Render("click a resource or press e to expand"))
	}

	if destroys {
		lines = append(lines, "", errText.Render("This plan deletes or replaces resources."))
	}

	return lines, hits
}

var addressParts = regexp.MustCompile(`([a-z0-9_]+)\.([A-Za-z0-9_-]+)(?:\[.*\])?$`)

// changeBlock renders one resource change the way `tofu plan` prints it:
// a comment naming the action, then the attributes inside a resource block.
func changeBlock(c plan.Change, cw int) []string {
	kind := strings.Join(c.Actions, "+")

	var (
		colour  lipgloss.Style
		unified string
	)

	switch kind {
	case "create":
		colour, unified = lipgloss.NewStyle().Foreground(green), "+"
	case "delete":
		colour, unified = errText, "-"
	case "update":
		colour, unified = lipgloss.NewStyle().Foreground(yellow), "~"
	default:
		colour, unified = errText, "-/+"
	}

	open := "{"
	if c.Output {
		open = fmt.Sprintf("output %q {", strings.TrimPrefix(c.Address, "output."))
	} else if m := addressParts.FindStringSubmatch(c.Address); m != nil {
		open = fmt.Sprintf("resource %q %q {", m[1], m[2])
	}

	lines := []string{colour.Render(unified) + " " + open}

	var (
		attrs []plan.Attr
		width int
	)

	for _, a := range c.Attrs {
		if a.HasAfter && !a.HasBefore && a.After == "null" && kind == "create" {
			continue
		}

		attrs = append(attrs, a)
		width = max(width, len(a.Name))
	}

	// Like tofu, only the leading symbol is coloured.
	line := func(sign string, st lipgloss.Style, text string) []string {
		var out []string

		for i, l := range strings.Split(ansi.Hardwrap(text, max(cw-6, 8), true), "\n") {
			if i == 0 {
				out = append(out, "    "+st.Render(sign)+" "+l)
			} else {
				out = append(out, "      "+l)
			}
		}

		return out
	}

	for _, a := range attrs {
		name := fmt.Sprintf("%-*s", width, a.Name)

		switch {
		case a.HasBefore && a.HasAfter:
			lines = append(lines, line("~", lipgloss.NewStyle().Foreground(yellow), name+" = "+a.Before+" -> "+a.After)...)
		case a.HasAfter:
			lines = append(lines, line("+", lipgloss.NewStyle().Foreground(green), name+" = "+a.After)...)
		default:
			lines = append(lines, line("-", errText, name+" = "+a.Before)...)
		}
	}

	return append(lines, "  }", dim.Render(strings.Repeat("┈", min(cw, 72))))
}

func (m Model) details(ws floorclient.Workspace, state planState, x, cw int) ([]string, []hit) {
	rows := [][2]string{{"Status", ws.Status()}}

	if ws.Failed() {
		rows = append(rows, [2]string{"Problem", errText.Render(firstProblem(ws))})
	}

	if ws.PendingPlan != "" {
		rows = append(rows, [2]string{"Apply", m.applyReadiness(ws)})
	}

	rows = append(rows, [2]string{"Source", ws.Path}, [2]string{"Branch", ws.SourceBranch})

	rows = append(rows, [2]string{"Revision", revisionChange(ws)})

	if len(state.plan.Changes) > 0 {
		summary := state.plan.Summary()
		if state.plan.Destroys() {
			summary = errText.Render(summary + " · destroys resources")
		}

		rows = append(rows, [2]string{"Changes", summary})
	}

	if ws.ApprovedBy != "" {
		rows = append(rows, [2]string{"Last approval", ws.ApprovedBy + " · " + approvedAt(ws.ApprovedAt)})
	}

	if ws.PullRequest > 0 {
		rows = append(rows, [2]string{"Pull request", fmt.Sprintf("#%d", ws.PullRequest)})
	}

	if ws.Review != "" {
		rows = append(rows, [2]string{"Review", ws.Review})
	}

	if state.plan.SHA256 != "" {
		rows = append(rows, [2]string{"Fingerprint", state.plan.SHA256[:min(len(state.plan.SHA256), 12)] + dim.Render(" · checked again when you approve")})
	}

	if ws.Destroy {
		rows = append(rows, [2]string{"Destroy mode", errText.Render("on")})
	}

	if ws.PlanOnly {
		rows = append(rows, [2]string{"Plan only", "yes, this workspace never applies"})
	}

	lines := make([]string, 0, len(rows))
	for _, r := range rows {
		lines = append(lines, dim.Render(fmt.Sprintf("%-14s", r[0]))+" "+trunc(r[1], cw-15))
	}

	extra, hits := m.commitLines(ws, x, cw, len(lines))

	return append(lines, extra...), hits
}

// commitLines lists the commits and files behind the revision, when the CLI
// runs in a checkout that has them.
func (m Model) commitLines(ws floorclient.Workspace, x, cw, offset int) ([]string, []hit) {
	l := m.commits[commitKey(ws)]
	if l == nil {
		return nil, nil
	}

	if len(l.Commits) == 0 {
		_, to := revisions(ws)

		return []string{"", dim.Render("Commits       " + to + " is not in this checkout, or changed nothing under " + ws.Path)}, nil
	}

	var hits []hit

	title := "Applied commit"
	if ws.PendingPlan != "" {
		title = "Commits to apply"
	}

	lines := []string{"", bold.Render(title)}

	for _, c := range l.Commits {
		lines = append(lines, "  "+lipgloss.NewStyle().Foreground(accent).Render(c.Hash)+" "+trunc(c.Subject, max(cw-10, 20)))
		lines = append(lines, "          "+dim.Render(c.Author+" · "+c.Date))
	}

	if l.More > 0 {
		lines = append(lines, dim.Render(fmt.Sprintf("  … and %d more commits", l.More)))
	}

	if len(l.Files) > 0 {
		lines = append(lines, "", bold.Render(fmt.Sprintf("Files changed (%d)", len(l.Files)))+dim.Render(" · c shows the diff, click a file for just that file"))

		for i, f := range l.Files {
			if i == 12 {
				lines = append(lines, dim.Render(fmt.Sprintf("  … and %d more files", len(l.Files)-i)))

				break
			}

			y := headerH + chromeRows + offset + len(lines)
			hits = append(hits, hit{x0: x, x1: x + cw, y0: y, y1: y + 1, key: "file:" + f.Path})
			lines = append(lines, "  "+trunc(f.Path, max(cw-20, 20))+" "+
				lipgloss.NewStyle().Foreground(green).Render("+"+f.Added)+" "+errText.Render("-"+f.Deleted))
		}
	}

	return lines, hits
}

// diffLines shows the code diff, coloured like a pull request, scrolled by m.scroll.
func (m Model) diffLines(ws floorclient.Workspace, cw, bodyH int) []string {
	d := m.diffs[diffKey(ws, m.diffFile)]

	switch {
	case d == nil || (d.lines == nil && d.err == nil):
		return []string{dim.Render("Reading diff…")}
	case d.err != nil:
		return []string{errText.Render(trunc("Diff unavailable: "+d.err.Error(), cw*2))}
	}

	scope := "all files"
	if m.diffFile != "" {
		scope = m.diffFile
	}

	avail := max(bodyH-chromeRows-4, 3)
	start := min(m.scroll, max(len(d.lines)-avail, 0))
	end := min(start+avail, len(d.lines))
	lines := []string{bold.Render("Diff") + dim.Render(" · "+scope), ""}

	for _, l := range d.lines[start:end] {
		l = strings.ReplaceAll(l, "\t", "    ")

		style := lipgloss.NewStyle()

		switch {
		case strings.HasPrefix(l, "+++"), strings.HasPrefix(l, "---"), strings.HasPrefix(l, "diff "), strings.HasPrefix(l, "index "):
			style = bold
		case strings.HasPrefix(l, "@@"):
			style = lipgloss.NewStyle().Foreground(blue)
		case strings.HasPrefix(l, "+"):
			style = lipgloss.NewStyle().Foreground(green)
		case strings.HasPrefix(l, "-"):
			style = errText
		}

		lines = append(lines, style.Render(trunc(l, cw-1)))
	}

	footer := fmt.Sprintf("lines %d-%d of %d", start+1, end, len(d.lines))
	if d.more > 0 {
		footer += fmt.Sprintf(" · %d more lines not shown", d.more)
	}

	return append(lines, "", dim.Render(footer+" · wheel or ctrl+d/u scrolls · esc back"))
}

// revisionChange shows what an apply would move the workspace from and to.
func revisionChange(ws floorclient.Workspace) string {
	from := "never applied"
	if ws.LastAppliedRevision != "" {
		from = floorclient.ShortRevision(ws.LastAppliedRevision)
	}

	if ws.PendingPlan == "" {
		return from
	}

	return from + " → " + ws.ShortPlan()[:min(len(ws.ShortPlan()), 7)]
}

// applyReadiness says whether the plan could apply as soon as it is approved.
func (m Model) applyReadiness(ws floorclient.Workspace) string {
	var blocking []string

	for _, ref := range ws.DependsOn {
		for _, w := range m.workspaces {
			if fullRef(w) == ref && phaseColour(w) != green {
				blocking = append(blocking, ref)
			}
		}
	}

	switch {
	case len(blocking) > 0:
		return lipgloss.NewStyle().Foreground(yellow).Render("waits on " + strings.Join(blocking, ", "))
	case ws.Approved:
		return lipgloss.NewStyle().Foreground(blue).Render("approved, applying")
	default:
		return lipgloss.NewStyle().Foreground(green).Render("ready once approved")
	}
}

func approvedAt(ts string) string {
	t, err := time.Parse(time.RFC3339, ts)
	if err != nil {
		return ts
	}

	return t.Local().Format("Jan 2 15:04")
}

func errorRows(h int) int { return max(min(h/2, h-headerH-cardH-2), 1) }

func (m Model) footer(w, h int) (string, []hit) {
	ws, _ := m.selected()
	state := m.plans[planKey(ws)]
	y := h - 1

	var message string

	switch {
	case m.mode == modeConfirmApprove:
		message = errText.Render("Approve?") + " This starts a real cloud apply of " + state.plan.Summary() + "."
	case m.mode == modeConfirmBatch:
		ok, _ := m.batchPlans()
		message = errText.Render("Approve?") + fmt.Sprintf(" This starts %d real cloud applies of %s in total.", len(ok), m.batchSummary(ok))
	case m.mode == modeConfirmReject:
		message = bold.Render("Reject") + " plan " + ws.ShortPlan() + "?"
	case m.err != nil:
		lines := strings.Split(ansi.Wrap("Error: "+m.err.Error(), w, ""), "\n")
		available := errorRows(h)
		hint := "M select text"
		if m.mouseReleased {
			hint = "M restore mouse"
		}
		if len(lines) > available {
			start := 0
			if m.scrolledError == m.err.Error() {
				start = min(m.errorScroll, len(lines)-available)
			}
			message = errText.Render(strings.Join(lines[start:start+available], "\n")) +
				"\n" + dim.Render(fmt.Sprintf("Error lines %d-%d of %d · [/] scroll · %s", start+1, start+available, len(lines), hint))
		} else {
			message = errText.Render(strings.Join(lines, "\n")) + "\n" + dim.Render(hint)
		}
	default:
		message = m.status
	}
	if m.mouseReleased && (m.err == nil || m.mode != modeList) {
		message += "\n" + dim.Render("Select text with your terminal · M restore mouse")
	}

	var segs []seg

	switch m.mode {
	case modeConfirmApprove:
		key := "y"
		if state.plan.Destroys() {
			key = "D"
		}

		segs = []seg{{keyPill.Render(key) + " approve", key}, {keyPill.Render("esc") + " cancel", "esc"}}
	case modeConfirmBatch:
		segs = []seg{{keyPill.Render("y") + " approve all", "y"}, {keyPill.Render("esc") + " cancel", "esc"}}
	case modeConfirmReject:
		segs = []seg{{keyPill.Render("y") + " reject", "y"}, {keyPill.Render("esc") + " cancel", "esc"}}
	default:
		hint := func(k, label, key string) seg { return seg{hintKey.Render(k) + " " + dim.Render(label), key} }

		listLabel := "show all"
		if !m.pendingOnly {
			listLabel = "pending only"
		}

		approveAll := hint("a", "approve", "a")
		if n := len(m.markedWorkspaces()); n > 0 {
			approveAll = hint("a", fmt.Sprintf("approve %d selected", n), "a")
		}

		if m.overviewShown() {
			segs = []seg{
				hint("↑/↓", "move", ""),
				hint("N", "fold sidebar", "N"),
				hint("enter", "open", "enter"),
				hint("p", listLabel, "p"),
				hint("R", "refresh", "R"),
				hint("q", "quit", "q"),
			}
			segs = m.withRenew(segs, hint)

			break
		}

		segs = []seg{
			hint("↑/↓", "move", ""),
			hint("N", "fold sidebar", "N"),
			hint("esc", "back", "esc"),
			hint("space", "select", "space"),
			hint("m", "all", "m"),
			approveAll,
			hint("r", "reject", "r"),
			hint("e", "expand", "e"),
			hint("tab", "switch", "tab"),
			hint("p", listLabel, "p"),
			hint("R", "refresh", "R"),
			hint("q", "quit", "q"),
		}
		if l := m.commits[commitKey(ws)]; l != nil && len(l.Commits) > 0 {
			segs = append(segs[:7:7], append([]seg{hint("c", "diff", "c")}, segs[7:]...)...)
		}

		segs = m.withRenew(segs, hint)
	}

	row, hits := segments(segs, 0, y, 3)
	right := dim.Render("refreshes every 10s")
	if lipgloss.Width(row)+lipgloss.Width(right)+1 <= w {
		row += strings.Repeat(" ", w-lipgloss.Width(row)-lipgloss.Width(right)) + right
	} else {
		row = ansi.Truncate(row, w, "")
	}
	visibleHits := hits[:0]
	for _, hit := range hits {
		if hit.x1 <= w {
			visibleHits = append(visibleHits, hit)
		}
	}

	return message + "\n" + row, visibleHits
}

// mouse routes clicks and the wheel. While a confirmation is open only its
// own buttons respond, so the selection cannot change under it.
func (m Model) mouse(msg tea.MouseMsg) (tea.Model, tea.Cmd) {
	if msg.Action != tea.MouseActionPress {
		return m, nil
	}

	w, _ := m.size()

	switch msg.Button {
	case tea.MouseButtonWheelUp, tea.MouseButtonWheelDown:
		if m.mode != modeList {
			return m, nil
		}

		delta := 1
		if msg.Button == tea.MouseButtonWheelUp {
			delta = -1
		}

		if msg.X < m.leftWidth(w) {
			return m.move(delta)
		}

		m.scroll = max(m.scroll+delta*3, 0)

		return m, nil
	case tea.MouseButtonLeft:
		_, hits := m.frame()

		for i := len(hits) - 1; i >= 0; i-- {
			if !hits[i].contains(msg.X, msg.Y) {
				continue
			}

			return m.click(hits[i].key)
		}
	}

	return m, nil
}

func (m Model) click(key string) (tea.Model, tea.Cmd) {
	if m.mode != modeList {
		if key == "y" || key == "D" || key == "esc" {
			return m.key(key)
		}

		return m, nil
	}

	if name, ok := strings.CutPrefix(key, "env:"); ok {
		return m.switchEnvironment(name)
	}

	if m.envMenu {
		// Any other click closes the dropdown, including the header toggle.
		m.envMenu = false

		return m, nil
	}

	switch {
	case key == "envmenu":
		m.openEnvMenu()

		return m, nil
	case strings.HasPrefix(key, "sidebar-ns:"):
		m.toggleSidebarNamespace(strings.TrimPrefix(key, "sidebar-ns:"))
		return m, nil
	case strings.HasPrefix(key, "card:"):
		var i int

		_, _ = fmt.Sscanf(key, "card:%d", &i)
		m.selectIndex(i)

		return m, m.loadPlan()
	case strings.HasPrefix(key, "mark:"):
		var i int

		_, _ = fmt.Sscanf(key, "mark:%d", &i)

		v := m.visible()
		if i < 0 || i >= len(v) {
			return m, nil
		}

		cmd := m.mark(v[i])

		return m, cmd
	case strings.HasPrefix(key, "change:"):
		var i int

		_, _ = fmt.Sscanf(key, "change:%d", &i)
		if m.expandAll {
			m.expandAll, m.open = false, 0
		} else if m.open == i+1 {
			m.open = 0
		} else {
			m.open = i + 1
		}
	case key == "tab:changes":
		m.tab, m.scroll, m.open = tabChanges, 0, 0
	case key == "tab:details":
		m.tab, m.scroll, m.open = tabDetails, 0, 0
	case key == "tab:diff":
		if m.tab == tabDiff {
			return m, nil
		}

		cmd := m.openDiff("")

		return m, cmd
	case strings.HasPrefix(key, "file:"):
		cmd := m.openDiff(strings.TrimPrefix(key, "file:"))

		return m, cmd
	case key == "tab:dependencies":
		m.tab, m.scroll, m.open = tabDependencies, 0, 0
	case strings.HasPrefix(key, "ns:"):
		return m.toggleNamespace(strings.TrimPrefix(key, "ns:"))
	case strings.HasPrefix(key, "dep:"):
		if m.jumpTo(strings.TrimPrefix(key, "dep:")) {
			return m, m.loadPlan()
		}
	default:
		return m.key(key)
	}

	return m, nil
}

// shortcut renders an action word with its first letter underlined, the key
// that triggers it.
func shortcut(word string, c lipgloss.Color) string {
	st := lipgloss.NewStyle().Bold(true).Foreground(c)

	return st.Underline(true).Render(word[:1]) + st.Render(word[1:])
}

// banner reports the outcome of the last approve or reject for the selected
// workspace, following the apply through Floor's workspace phase.
func (m Model) banner() (string, bool) {
	o := m.outcome

	ws, ok := m.selected()
	if ok && ws.Approved && ws.Ref() != o.ref {
		return lipgloss.NewStyle().Foreground(blue).Render("◐ Approved") + dim.Render(" · waiting to apply · "+ws.PhaseText()), true
	}

	if !ok || o.ref == "" || ws.Ref() != o.ref {
		return "", false
	}

	done := lipgloss.NewStyle().Foreground(green)
	verb := map[string]string{"approve": "Approving", "reject": "Rejecting"}[o.verb]
	past := map[string]string{"approve": "Approved", "reject": "Rejected"}[o.verb]

	switch {
	case o.busy:
		return lipgloss.NewStyle().Foreground(blue).Render("◐ " + verb + "…"), true
	case o.err != nil:
		return errText.Render("✗ " + verb + " failed: " + o.err.Error()), true
	case o.verb == "reject":
		return done.Render("✓ " + past), true
	}

	phase := strings.ToLower(ws.Phase)

	switch {
	case ws.PendingPlan != "" && ws.PendingPlan != o.planID:
		return "", false
	case ws.PendingPlan == o.planID:
		return done.Render("✓ "+past) + dim.Render(" · waiting for Floor to start the apply"), true
	case strings.Contains(phase, "fail") || strings.Contains(phase, "error"):
		return errText.Render("✗ Apply failed · " + ws.PhaseText()), true
	case ws.Phase == "Progressing":
		return lipgloss.NewStyle().Foreground(blue).Render("◐ "+past) + dim.Render(" · applying…"), true
	case ws.LastAppliedRevision != o.appliedBefore:
		return done.Render("✓ Applied") + dim.Render(" · revision "+ws.LastAppliedRevision), true
	default:
		return done.Render("✓ "+past) + dim.Render(" · waiting for the apply"), true
	}
}

// outcomeDone reports that the last action needs no more polling.
func (m Model) outcomeDone() bool {
	o := m.outcome

	if o.busy {
		return false
	}

	// Stop polling quickly if the apply never shows up.
	if time.Since(o.started) > 5*time.Minute {
		return true
	}

	for _, w := range m.workspaces {
		if w.Ref() != o.ref {
			continue
		}

		phase := strings.ToLower(w.Phase)

		switch {
		case o.err != nil || o.verb == "reject":
			return true
		case strings.Contains(phase, "fail") || strings.Contains(phase, "error"):
			return true
		default:
			return w.PendingPlan == "" && w.Phase != "Progressing" && w.LastAppliedRevision != o.appliedBefore
		}
	}

	return true
}

// withRenew adds the token renewal hint when a token is about to expire.
func (m Model) withRenew(segs []seg, hint func(k, label, key string) seg) []seg {
	if !m.canRenew() {
		return segs
	}

	return append(segs[:len(segs)-1:len(segs)-1], hint("T", "renew token", "T"), segs[len(segs)-1])
}

func plural(n int, one, many string) string {
	if n == 1 {
		return one
	}

	return many
}
