package tui

import (
	"fmt"
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/osinfra-io/factory/cli/internal/floorclient"
)

const recentApprovals = 5

// overview is the landing view when nothing is selected: environment health,
// what needs attention, the dependency map and recent approvals.
func (m Model) overview(x, cw, bodyH int) (string, []hit) {
	if len(m.workspaces) == 0 {
		return dim.Render("Waiting for Floor..."), nil
	}

	var (
		lines []string
		hits  []hit
	)

	add := func(s ...string) { lines = append(lines, s...) }

	add(m.healthLine(), m.progressBar(len(m.workspaces), m.applied(m.workspaces), 24)+dim.Render(" applied"), "")

	if n := m.awaiting(); n > 0 {
		label := lipgloss.NewStyle().Bold(true).Foreground(yellow).Render(fmt.Sprintf("● %d awaiting your approval", n))
		hits = append(hits, hit{x0: x, x1: x + lipgloss.Width(label), y0: headerH + len(lines), y1: headerH + len(lines) + 1, key: "p"})
		add(label+dim.Render("  press p or click"), "")
	}

	if attention, keys := m.attention(cw); len(attention) > 0 {
		add(bold.Render("Needs attention"))

		for i, l := range attention {
			if keys[i] != "" {
				hits = append(hits, hit{x0: x, x1: x + cw, y0: headerH + len(lines), y1: headerH + len(lines) + 1, key: keys[i]})
			}

			add(l)
		}

		add("")
	}

	if now, keys := m.inFlight(cw); len(now) > 0 {
		add(bold.Render("Now"))

		for i, l := range now {
			hits = append(hits, hit{x0: x, x1: x + cw, y0: headerH + len(lines), y1: headerH + len(lines) + 1, key: keys[i]})
			add(l)
		}

		add("")
	}

	if blocked := m.blocked(cw); len(blocked) > 0 {
		add(bold.Render("Waiting on"))
		add(blocked...)
		add("")
	}

	add(bold.Render("Namespaces") + dim.Render("  enter or click to expand"))

	mapLines, mapHits, refs := m.layerMap(x, headerH+len(lines), cw)
	add(mapLines...)

	hits = append(hits, mapHits...)

	if recent, keys := m.recent(cw); len(recent) > 0 {
		add("", bold.Render("Activity"))

		for i, l := range recent {
			hits = append(hits, hit{x0: x, x1: x + cw, y0: headerH + len(lines), y1: headerH + len(lines) + 1, key: keys[i]})
			add(l)
		}
	}

	// Scroll by the user's offset, but keep the highlighted box on screen.
	top := min(max(m.scroll, 0), max(len(lines)-bodyH, 0))

	if m.mapCursor >= 0 && m.mapCursor < len(refs) {
		for _, h := range hits {
			if h.key != refKey(refs[m.mapCursor]) {
				continue
			}

			first, last := h.y0-headerH, h.y1-headerH
			if first < top {
				top = first
			} else if last > top+bodyH {
				top = last - bodyH
			}
		}
	}

	end := min(top+bodyH, len(lines))
	visible := lines[top:end]

	shown := hits[:0]

	for _, h := range hits {
		h.y0, h.y1 = h.y0-top, h.y1-top
		if h.y0 >= headerH && h.y1 <= headerH+len(visible) {
			shown = append(shown, h)
		}
	}

	return strings.Join(visible, "\n"), shown
}

// healthLine counts workspaces by state, worst first.
func (m Model) healthLine() string {
	var failed, waiting, approval, healthy, running int

	for _, w := range m.workspaces {
		switch {
		case w.Failed():
			failed++
		case w.PendingPlan != "" && !w.Approved:
			approval++
		case w.Running() != "":
			running++
		case w.PendingPlan != "":
		case w.Waiting():
			waiting++
		default:
			healthy++
		}
	}

	parts := []string{bold.Render(fmt.Sprintf("%d workspaces", len(m.workspaces)))}

	count := func(n int, label string, c lipgloss.Color) {
		if n > 0 {
			parts = append(parts, lipgloss.NewStyle().Foreground(c).Render(fmt.Sprintf("%d %s", n, label)))
		}
	}

	count(healthy, "healthy", green)
	count(running, "running", blue)
	count(waiting, "waiting", yellow)
	count(approval, "awaiting approval", yellow)
	count(failed, "failed", red)

	return strings.Join(parts, dim.Render(" · "))
}

// attention lists failed workspaces with the first line of their error.
func (m Model) attention(cw int) ([]string, []string) {
	var out, keys []string

	for _, w := range m.sorted() {
		if !w.Failed() {
			continue
		}

		out = append(out, lipgloss.NewStyle().Foreground(red).Render("✗ ")+fullRef(w)+dim.Render(" · "+w.PhaseText()))
		keys = append(keys, "dep:"+fullRef(w))

		if p := firstProblem(w); p != "" {
			out = append(out, "  "+dim.Render(trunc(p, cw-2)))
			keys = append(keys, "dep:"+fullRef(w))
		}
	}

	return out, keys
}

// awaiting counts plans waiting for a human decision.
func (m Model) awaiting() int {
	n := 0

	for _, w := range m.workspaces {
		if w.PendingPlan != "" && !w.Approved {
			n++
		}
	}

	return n
}

// tokenNote describes how long a namespace's runner token has left.
func (m Model) tokenNote(ns string) string {
	exp, ok := m.tokens[ns]
	if !ok {
		return ""
	}

	left := time.Until(exp)

	switch {
	case left <= 0:
		return "  " + lipgloss.NewStyle().Foreground(red).Render("token expired · bash bootstrap/seed/prepare.sh")
	case left < 15*time.Minute:
		return "  " + lipgloss.NewStyle().Foreground(yellow).Render(fmt.Sprintf("token ~%dm left", int(left.Minutes())+1))
	default:
		return "  " + dim.Render(fmt.Sprintf("token ~%dm left", int(left.Minutes())+1))
	}
}

// tokenAlert is the header warning for the soonest expiring token, if any
// is expired or nearly so.
func (m Model) tokenAlert() string {
	if m.renewing {
		return lipgloss.NewStyle().Foreground(yellow).Render("◐ Renewing the runner token…")
	}

	var soonest time.Duration

	found := false

	for _, t := range m.tokens {
		if left := time.Until(t); !found || left < soonest {
			soonest, found = left, true
		}
	}

	switch {
	case !found || soonest >= 15*time.Minute:
		return ""
	case soonest <= 0:
		return lipgloss.NewStyle().Bold(true).Foreground(red).Render("▲ Google token expired")
	default:
		return lipgloss.NewStyle().Foreground(yellow).Render(fmt.Sprintf("▲ Google token expires in ~%dm", int(soonest.Minutes())+1))
	}
}

// layerMap lists each namespace's workspaces as numbered stages, in the order
// they apply. refs lists every workspace in cursor order.
func (m Model) layerMap(x, y, cw int) ([]string, []hit, []string) {
	depth := map[string]int{}
	byRef := map[string]floorclient.Workspace{}

	for _, w := range m.workspaces {
		byRef[fullRef(w)] = w
	}

	var level func(ref string, seen map[string]bool) int

	level = func(ref string, seen map[string]bool) int {
		if d, ok := depth[ref]; ok {
			return d
		}

		if seen[ref] {
			return 0
		}

		seen[ref] = true

		d := 0

		for _, dep := range byRef[ref].DependsOn {
			if _, ok := byRef[dep]; ok {
				d = max(d, level(dep, seen)+1)
			}
		}

		depth[ref] = d

		return d
	}

	groups := map[string][]floorclient.Workspace{}

	var namespaces []string

	for _, w := range m.sorted() {
		level(fullRef(w), map[string]bool{})

		if _, ok := groups[w.Namespace]; !ok {
			namespaces = append(namespaces, w.Namespace)
		}

		groups[w.Namespace] = append(groups[w.Namespace], w)
	}

	var (
		lines []string
		hits  []hit
		refs  []string
	)

	for _, ns := range namespaces {
		ws := groups[ns]
		sort.SliceStable(ws, func(i, j int) bool { return depth[fullRef(ws[i])] < depth[fullRef(ws[j])] })

		open := m.expanded[ns]

		refs = append(refs, "ns:"+ns)

		row := m.namespaceRow(ns, ws, depth, open, len(refs)-1 == m.mapCursor, cw)
		hits = append(hits, hit{x0: x, x1: x + cw, y0: y + len(lines), y1: y + len(lines) + 1, key: "ns:" + ns})
		lines = append(lines, row)

		if !open {
			continue
		}

		pending, hidden := m.unfinished(ws)
		for _, w := range pending {
			refs = append(refs, fullRef(w))

			line := "    " + m.workspaceRow(w, len(refs)-1 == m.mapCursor)
			hits = append(hits, hit{x0: x, x1: x + cw, y0: y + len(lines), y1: y + len(lines) + 1, key: "dep:" + fullRef(w)})
			lines = append(lines, trunc(line, cw))

			if details := m.pendingDetails(w); details != "" {
				hits = append(hits, hit{x0: x, x1: x + cw, y0: y + len(lines), y1: y + len(lines) + 1, key: "dep:" + fullRef(w)})
				lines = append(lines, "      "+dim.Render(trunc(details, cw-6)))
			}
		}

		if hidden > 0 {
			lines = append(lines, "    "+dim.Render(fmt.Sprintf("✓ %d applied", hidden)))
		}

		lines = append(lines, "")
	}

	return lines, hits, refs
}

// shortName drops the environment suffix shared by a namespace's workspaces.
func shortName(w floorclient.Workspace) string {
	name := strings.TrimPrefix(w.Ref(), w.Namespace+"/")

	if env, ok := strings.CutPrefix(w.Namespace, "bootstrap-"); ok {
		if short, ok := strings.CutSuffix(name, "-"+env); ok {
			return short
		}
	}

	return name
}

// unfinished lists the workspaces that still have something to do or decide,
// failures first, and counts the rest.
func (m Model) unfinished(ws []floorclient.Workspace) ([]floorclient.Workspace, int) {
	rank := func(w floorclient.Workspace) int {
		switch {
		case w.Failed():
			return 0
		case w.PendingPlan != "" && !w.Approved:
			return 1
		case w.Running() != "":
			return 2
		default:
			return 3
		}
	}

	var out []floorclient.Workspace

	for _, w := range ws {
		if !settled(w) {
			out = append(out, w)
		}
	}

	sort.SliceStable(out, func(i, j int) bool {
		if ri, rj := rank(out[i]), rank(out[j]); ri != rj {
			return ri < rj
		}

		return fullRef(out[i]) < fullRef(out[j])
	})

	return out, len(ws) - len(out)
}

// pendingDetails says who approved a plan, what it changes and which commit it
// came from, for plans that are waiting or being applied.
func (m Model) pendingDetails(w floorclient.Workspace) string {
	if w.PendingPlan == "" {
		return ""
	}

	var parts []string

	if w.Approved && w.ApprovedBy != "" {
		parts = append(parts, "approved by "+w.ApprovedBy)
	}

	if p, ok := m.plans[planKey(w)]; ok && p.err == nil && !p.loading {
		if len(p.plan.Changes) == 0 {
			parts = append(parts, "no changes")
		} else {
			parts = append(parts, p.plan.Summary())
		}
	}

	if c, ok := m.heads[w.ShortPlan()]; ok && c.Hash != "" {
		parts = append(parts, c.Hash+" "+c.Subject+" ("+c.Author+")")
	}

	return strings.Join(parts, " · ")
}

// workspaceRow is one unfinished workspace with what it is doing.
func (m Model) workspaceRow(w floorclient.Workspace, cursor bool) string {
	name := shortName(w)
	if cursor {
		name = lipgloss.NewStyle().Bold(true).Foreground(accent).Render(name)
	}

	note := w.Status()

	switch {
	case w.Running() != "":
		note = w.Running()
	case w.PendingPlan != "":
		note = "awaiting approval"
	case w.Phase == "DependencyNotReady":
		note = "waiting on " + m.blockerName(w)
	}

	return statusDot(w) + " " + name + dim.Render(" · "+strings.ToLower(note))
}

// frontierOf is the first dependency level with unfinished work, or -1.
func frontierOf(ws []floorclient.Workspace, depth map[string]int) int {
	frontier := -1

	for _, w := range ws {
		if d := depth[fullRef(w)]; !settled(w) && (frontier < 0 || d < frontier) {
			frontier = d
		}
	}

	return frontier
}

// refKey is the click target for a cursor entry.
func refKey(ref string) string {
	if strings.HasPrefix(ref, "ns:") {
		return ref
	}

	return "dep:" + ref
}

// applied counts workspaces with nothing left to do or decide.
func (m Model) applied(ws []floorclient.Workspace) int {
	n := 0

	for _, w := range ws {
		if settled(w) {
			n++
		}
	}

	return n
}

// progressBar draws done of total as a fixed-width bar.
func (m Model) progressBar(total, done, width int) string {
	if total == 0 {
		return ""
	}

	filled := done * width / total
	if done > 0 && filled == 0 {
		filled = 1
	}

	colour := green
	if done < total {
		colour = accent
	}

	return lipgloss.NewStyle().Foreground(colour).Render(strings.Repeat("█", filled)) +
		dim.Render(strings.Repeat("░", width-filled)) +
		dim.Render(fmt.Sprintf(" %d/%d", done, total))
}

// namespaceRow summarises one namespace on a single line.
func (m Model) namespaceRow(ns string, ws []floorclient.Workspace, depth map[string]int, open, cursor bool, cw int) string {
	var approval, failed, waiting, applying int

	for _, w := range ws {
		switch {
		case w.Failed():
			failed++
		case w.PendingPlan != "" && !w.Approved:
			approval++
		case w.Running() != "":
			applying++
		case w.Waiting():
			waiting++
		}
	}

	arrow := "▸ "
	if open {
		arrow = "▾ "
	}

	name := bold.Render(ns)
	if cursor {
		name = lipgloss.NewStyle().Bold(true).Foreground(accent).Render(ns)
	}

	done := m.applied(ws)
	parts := []string{m.progressBar(len(ws), done, 10)}

	if f := frontierOf(ws, depth); f >= 0 {
		last := 0
		for _, w := range ws {
			last = max(last, depth[fullRef(w)])
		}

		parts = append(parts, dim.Render(fmt.Sprintf("stage %d of %d", f+1, last+1)))
	}

	count := func(n int, label string, c lipgloss.Color) {
		if n > 0 {
			parts = append(parts, lipgloss.NewStyle().Foreground(c).Render(fmt.Sprintf("%d %s", n, label)))
		}
	}

	count(failed, "failed", red)
	count(approval, "awaiting approval", yellow)
	count(applying, "running", blue)
	count(waiting, "waiting", yellow)

	return trunc(dim.Render(arrow)+name+"  "+strings.Join(parts, dim.Render(" · "))+m.tokenNote(ns), cw)
}

// inFlight lists what the controller is planning or applying right now, with
// how long approved applies have run.
func (m Model) inFlight(cw int) ([]string, []string) {
	var out, keys []string

	for _, w := range m.sorted() {
		running := w.Running()
		if running == "" {
			continue
		}

		line := lipgloss.NewStyle().Foreground(blue).Render(runIcon(running)+" ") + fullRef(w)

		note := " · " + running
		if t, err := time.Parse(time.RFC3339, w.ApprovedAt); err == nil && w.PendingPlan != "" {
			note += " · " + elapsed(time.Since(t))
		}

		out = append(out, trunc(line+dim.Render(note), cw))
		keys = append(keys, "dep:"+fullRef(w))

		if d := m.runningDetail(w); d != "" {
			out = append(out, trunc("  "+dim.Render(d), cw))
			keys = append(keys, "dep:"+fullRef(w))
		}
	}

	return out, keys
}

// runningDetail names the resources a running workspace is changing, taken
// from its cached plan.
func (m Model) runningDetail(w floorclient.Workspace) string {
	p, ok := m.plans[planKey(w)]
	if !ok || p.err != nil || p.loading {
		return ""
	}

	var names []string

	for _, c := range p.plan.Changes {
		if !c.Output {
			names = append(names, shortAddress(c.Address))
		}
	}

	if len(names) == 0 {
		return ""
	}

	shown := names
	if len(shown) > 3 {
		shown = shown[:3]
	}

	d := p.plan.Summary() + " · " + strings.Join(shown, ", ")
	if len(names) > len(shown) {
		d += fmt.Sprintf(" and %d more", len(names)-len(shown))
	}

	return d
}

// elapsed formats a duration coarsely for display.
func elapsed(d time.Duration) string {
	d = max(d, 0).Round(time.Second)

	if d < time.Minute {
		return fmt.Sprintf("%ds", int(d.Seconds()))
	}

	if d < time.Hour {
		return fmt.Sprintf("%dm %02ds", int(d.Minutes()), int(d.Seconds())%60)
	}

	return fmt.Sprintf("%dh %02dm", int(d.Hours()), int(d.Minutes())%60)
}

// blocked groups workspaces that are waiting on a dependency by the workspace
// at the root of the chain, which is what has to move before they can.
func (m Model) blocked(cw int) []string {
	byRef := map[string]floorclient.Workspace{}
	for _, w := range m.workspaces {
		byRef[fullRef(w)] = w
	}

	waiting := func(w floorclient.Workspace) bool {
		return w.Phase == "DependencyNotReady" && w.PendingPlan == "" && !w.Failed()
	}

	var root func(w floorclient.Workspace, seen map[string]bool) floorclient.Workspace

	root = func(w floorclient.Workspace, seen map[string]bool) floorclient.Workspace {
		seen[fullRef(w)] = true

		for _, d := range w.DependsOn {
			dep, ok := byRef[d]
			if !ok || seen[d] || settled(dep) {
				continue
			}

			if waiting(dep) {
				return root(dep, seen)
			}

			return dep
		}

		return w
	}

	counts := map[string]int{}
	roots := map[string]floorclient.Workspace{}

	var order []string

	for _, w := range m.sorted() {
		if !waiting(w) {
			continue
		}

		r := root(w, map[string]bool{})
		if fullRef(r) == fullRef(w) {
			continue
		}

		key := fullRef(r)
		if counts[key] == 0 {
			order = append(order, key)
			roots[key] = r
		}

		counts[key]++
	}

	sort.SliceStable(order, func(i, j int) bool { return counts[order[i]] > counts[order[j]] })

	const shown = 5

	var out []string

	for _, key := range order[:min(len(order), shown)] {
		r := roots[key]

		state := strings.ToLower(r.Status())

		switch {
		case r.PendingPlan != "" && r.Approved:
			state = "applying"
		case r.PendingPlan != "":
			state = "awaiting approval"
		}

		label := "workspaces"
		if counts[key] == 1 {
			label = "workspace"
		}

		out = append(out, trunc(lipgloss.NewStyle().Foreground(yellow).Render("◌ ")+fmt.Sprintf("%d %s waiting on ", counts[key], label)+bold.Render(shortName(r))+dim.Render(" · "+state), cw))
	}

	if len(order) > shown {
		out = append(out, dim.Render(fmt.Sprintf("  and %d more", len(order)-shown)))
	}

	return out
}

// settled reports that a workspace has nothing left to do or decide.
func settled(w floorclient.Workspace) bool {
	return !w.Failed() && w.PendingPlan == "" && !w.Waiting() && w.Running() == ""
}

// recentWorkspaces lists the latest approvals, newest first, leaving out
// plans that are still applying.
func (m Model) recentWorkspaces() []floorclient.Workspace {
	var approved []floorclient.Workspace

	for _, w := range m.workspaces {
		if w.ApprovedAt != "" && (w.PendingPlan == "" || w.Failed()) {
			approved = append(approved, w)
		}
	}

	sort.Slice(approved, func(i, j int) bool { return approved[i].ApprovedAt > approved[j].ApprovedAt })

	return approved[:min(len(approved), recentApprovals)]
}

// recent describes each recent approval on two lines: the outcome and when,
// then who approved it, what the plan changed and the commit behind it.
func (m Model) recent(cw int) ([]string, []string) {
	var out, keys []string

	for _, w := range m.recentWorkspaces() {
		state := lipgloss.NewStyle().Foreground(green).Render("applied")
		if w.Failed() {
			state = lipgloss.NewStyle().Foreground(red).Render("failed")
		}

		who := w.ApprovedBy
		if who == "" {
			who = "unknown"
		}

		details := []string{"approved by " + who}

		if p, ok := m.plans[w.Ref()+"|"+w.ApprovedPlan]; ok && p.err == nil && w.ApprovedPlan != "" {
			if len(p.plan.Changes) == 0 {
				details = append(details, "no changes")
			} else {
				details = append(details, p.plan.Summary())
			}
		}

		if c, ok := m.heads[floorclient.ShortRevision(w.LastAppliedRevision)]; ok && c.Hash != "" {
			details = append(details, c.Hash+" "+c.Subject+" ("+c.Author+")")
		}

		out = append(out,
			trunc(statusDot(w)+" "+fullRef(w)+dim.Render(" · "+approvedAt(w.ApprovedAt)+" · ")+state, cw),
			"  "+dim.Render(trunc(strings.Join(details, " · "), cw-2)),
		)
		keys = append(keys, "dep:"+fullRef(w), "dep:"+fullRef(w))
	}

	return out, keys
}

// overviewShown reports whether the pane is the overview rather than a workspace.
func (m Model) overviewShown() bool {
	_, ok := m.selected()

	return !ok && len(m.workspaces) > 0
}

// moveMap moves the overview's map cursor, wrapping neither end.
func (m Model) moveMap(delta int) (tea.Model, tea.Cmd) {
	_, _, refs := m.layerMap(0, 0, 0)
	m.mapCursor = min(max(m.mapCursor+delta, 0), max(len(refs)-1, 0))

	return m, nil
}

// goHome returns to the overview, leaving the map cursor on the workspace
// that was open.
func (m *Model) goHome() {
	if len(m.workspaces) == 0 || m.home {
		return
	}

	if ws, ok := m.selected(); ok {
		m.expand(ws.Namespace, true)

		_, _, refs := m.layerMap(0, 0, 0)
		for i, r := range refs {
			if r == fullRef(ws) {
				m.mapCursor = i
			}
		}
	}

	m.home = true
}

// expand shows or hides a namespace's stages.
func (m *Model) expand(ns string, open bool) {
	if m.expanded == nil {
		m.expanded = map[string]bool{}
	}

	m.expanded[ns] = open
}

// toggleNamespace expands or folds a namespace and puts the cursor on it.
func (m Model) toggleNamespace(ns string) (tea.Model, tea.Cmd) {
	m.expand(ns, !m.expanded[ns])

	_, _, refs := m.layerMap(0, 0, 0)
	for i, r := range refs {
		if r == "ns:"+ns {
			m.mapCursor = i
		}
	}

	return m, nil
}

// openMap opens the workspace under the map cursor, or toggles a namespace.
func (m Model) openMap() (tea.Model, tea.Cmd) {
	_, _, refs := m.layerMap(0, 0, 0)

	if m.mapCursor >= 0 && m.mapCursor < len(refs) {
		if ns, ok := strings.CutPrefix(refs[m.mapCursor], "ns:"); ok {
			return m.toggleNamespace(ns)
		}
	}

	if m.mapCursor < 0 || m.mapCursor >= len(refs) || !m.jumpTo(refs[m.mapCursor]) {
		return m, nil
	}

	cmd := m.loadPlan()

	return m, cmd
}

// blockerName is the short name of the first dependency that is not ready.
func (m Model) blockerName(w floorclient.Workspace) string {
	for _, d := range w.DependsOn {
		for _, o := range m.workspaces {
			if fullRef(o) == d && (o.Failed() || o.Phase == "Progressing" || o.Waiting() || o.PendingPlan != "") {
				return shortName(o)
			}
		}
	}

	if len(w.DependsOn) > 0 {
		return w.DependsOn[0][strings.LastIndex(w.DependsOn[0], "/")+1:]
	}

	return "dependencies"
}

func (m Model) sorted() []floorclient.Workspace {
	out := append([]floorclient.Workspace(nil), m.workspaces...)
	sort.Slice(out, func(i, j int) bool { return fullRef(out[i]) < fullRef(out[j]) })

	return out
}
