// Package plan reads a workspace's pending plan from the cluster so it can
// be reviewed before approval. It mirrors bootstrap/seed/review.sh: the
// readable plan Secret must belong to the Terraform object and match the
// pending plan ID.
package plan

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"regexp"
	"sort"
	"strings"
	"time"
)

// Change is one planned resource change.
type Change struct {
	Address string
	Actions []string
	Attrs   []Attr
	// Output marks a change to a root output rather than to a resource.
	Output bool
}

// Attr is one changed attribute. Sensitive values are never stored.
type Attr struct {
	Name   string
	Before string
	After  string
	// HasBefore and HasAfter tell an absent value from an empty one.
	HasBefore, HasAfter bool
}

// Plan is the reviewed content of a pending plan.
type Plan struct {
	ID       string
	Revision string
	SHA256   string
	Changes  []Change
}

// Destroys reports whether any change deletes or replaces a resource.
func (p Plan) Destroys() bool {
	for _, c := range p.Changes {
		for _, a := range c.Actions {
			if a == "delete" && !c.Output {
				return true
			}
		}
	}

	return false
}

// Summary counts the changes by action, e.g. "3 create, 1 update".
func (p Plan) Summary() string {
	counts := map[string]int{}
	outputs := 0

	for _, c := range p.Changes {
		if c.Output {
			outputs++

			continue
		}

		counts[strings.Join(c.Actions, "+")]++
	}

	keys := make([]string, 0, len(counts))
	for k := range counts {
		keys = append(keys, k)
	}

	sort.Strings(keys)

	parts := make([]string, 0, len(keys))
	for _, k := range keys {
		parts = append(parts, fmt.Sprintf("%d %s", counts[k], k))
	}

	if outputs > 0 {
		parts = append(parts, fmt.Sprintf("%d output %s", outputs, map[bool]string{true: "change", false: "changes"}[outputs == 1]))
	}

	if len(parts) == 0 {
		return "no changes"
	}

	return strings.Join(parts, ", ")
}

// Runner runs a command and returns its stdout.
type Runner func(ctx context.Context, name string, args ...string) ([]byte, error)

// Reader reads plans through kubectl against one kube context.
type Reader struct {
	Context string
	Run     Runner
}

// NewReader returns a Reader that shells out to kubectl.
func NewReader(kubeContext string) *Reader {
	return &Reader{Context: kubeContext, Run: execRunner}
}

func execRunner(ctx context.Context, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)

	var stderr bytes.Buffer

	cmd.Stderr = &stderr

	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("%s: %w: %s", name, err, strings.TrimSpace(stderr.String()))
	}

	return out, nil
}

type terraformObject struct {
	Metadata struct {
		UID        string `json:"uid"`
		Generation int64  `json:"generation"`
	} `json:"metadata"`
	Spec struct {
		Workspace string `json:"workspace"`
	} `json:"spec"`
	Status struct {
		Plan struct {
			Pending string `json:"pending"`
		} `json:"plan"`
		LastPlannedRevision   string `json:"lastPlannedRevision"`
		LastPlannedGeneration int64  `json:"lastPlannedGeneration"`
	} `json:"status"`
}

type secretObject struct {
	Metadata struct {
		Annotations     map[string]string `json:"annotations"`
		OwnerReferences []struct {
			Kind string `json:"kind"`
			UID  string `json:"uid"`
		} `json:"ownerReferences"`
	} `json:"metadata"`
	Data map[string]string `json:"data"`
}

// Read returns the pending plan of the Terraform object name in namespace.
// It fails if the object has no current pending plan, or if the readable
// plan does not belong to it.
func (r *Reader) Read(ctx context.Context, namespace, name string) (Plan, error) {
	obj, err := r.terraform(ctx, namespace, name)
	if err != nil {
		return Plan{}, err
	}

	pending := obj.Status.Plan.Pending
	if pending == "" || obj.Status.LastPlannedGeneration != obj.Metadata.Generation {
		return Plan{}, errors.New("no current pending plan")
	}

	raw, err := r.kubectl(ctx, namespace, "get", "secret", "tfplan-"+obj.Spec.Workspace+"-"+name+".json", "-o", "json")
	if err != nil {
		return Plan{}, err
	}

	var secret secretObject
	if err := json.Unmarshal(raw, &secret); err != nil {
		return Plan{}, err
	}

	if secret.Metadata.Annotations["savedPlan"] != pending {
		return Plan{}, errors.New("readable plan does not match the pending plan")
	}

	owned := false

	for _, o := range secret.Metadata.OwnerReferences {
		owned = owned || (o.Kind == "Terraform" && o.UID == obj.Metadata.UID)
	}

	if !owned {
		return Plan{}, errors.New("readable plan is not owned by this Terraform object")
	}

	body, err := decode(secret.Data["tfplan"])
	if err != nil {
		return Plan{}, err
	}

	// A plan that changed while it was being read must not be reviewed.
	again, err := r.terraform(ctx, namespace, name)
	if err != nil {
		return Plan{}, err
	}

	if again.Status.Plan.Pending != pending {
		return Plan{}, errors.New("pending plan changed while reading it; try again")
	}

	return parse(pending, obj.Status.LastPlannedRevision, body)
}

func (r *Reader) terraform(ctx context.Context, namespace, name string) (terraformObject, error) {
	var obj terraformObject

	raw, err := r.kubectl(ctx, namespace, "get", "terraform", name, "-o", "json")
	if err != nil {
		return obj, err
	}

	return obj, json.Unmarshal(raw, &obj)
}

func (r *Reader) kubectl(ctx context.Context, namespace string, args ...string) ([]byte, error) {
	full := append([]string{"--context=" + r.Context, "--namespace=" + namespace}, args...)

	return r.Run(ctx, "kubectl", full...)
}

// tokenLifetime is how long the runner's Google access token stays valid.
const tokenLifetime = time.Hour

// TokenExpiry estimates when the runner's Google access token in namespace
// expires, from when bootstrap/seed/prepare.sh last wrote the Secret.
func (r *Reader) TokenExpiry(ctx context.Context, namespace string) (time.Time, error) {
	out, err := r.kubectl(ctx, namespace, "get", "secret", "floor-bootstrap-auth",
		"--output=jsonpath={.metadata.managedFields[?(@.manager==\"environment-bootstrap\")].time}")
	if err != nil {
		return time.Time{}, err
	}

	var latest time.Time

	for _, f := range strings.Fields(string(out)) {
		if t, err := time.Parse(time.RFC3339, f); err == nil && t.After(latest) {
			latest = t
		}
	}

	if latest.IsZero() {
		return time.Time{}, errors.New("no token refresh recorded")
	}

	return latest.Add(tokenLifetime), nil
}

func decode(encoded string) ([]byte, error) {
	compressed, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, fmt.Errorf("decoding plan: %w", err)
	}

	zr, err := gzip.NewReader(bytes.NewReader(compressed))
	if err != nil {
		return nil, fmt.Errorf("decompressing plan: %w", err)
	}
	defer func() { _ = zr.Close() }()

	return io.ReadAll(zr)
}

func parse(id, revision string, body []byte) (Plan, error) {
	var doc struct {
		ResourceChanges []struct {
			Address string `json:"address"`
			Change  struct {
				Actions         []string `json:"actions"`
				Before          any      `json:"before"`
				After           any      `json:"after"`
				AfterUnknown    any      `json:"after_unknown"`
				BeforeSensitive any      `json:"before_sensitive"`
				AfterSensitive  any      `json:"after_sensitive"`
			} `json:"change"`
		} `json:"resource_changes"`
		OutputChanges map[string]struct {
			Actions         []string `json:"actions"`
			Before          any      `json:"before"`
			After           any      `json:"after"`
			AfterUnknown    any      `json:"after_unknown"`
			BeforeSensitive any      `json:"before_sensitive"`
			AfterSensitive  any      `json:"after_sensitive"`
		} `json:"output_changes"`
	}

	if err := json.Unmarshal(body, &doc); err != nil {
		return Plan{}, fmt.Errorf("parsing plan: %w", err)
	}

	sum := sha256.Sum256(body)
	p := Plan{ID: id, Revision: revision, SHA256: hex.EncodeToString(sum[:])}

	for _, c := range doc.ResourceChanges {
		if len(c.Change.Actions) == 1 && c.Change.Actions[0] == "no-op" {
			continue
		}

		p.Changes = append(p.Changes, Change{
			Address: c.Address,
			Actions: c.Change.Actions,
			Attrs:   diff(c.Change.Before, c.Change.After, c.Change.AfterUnknown, c.Change.BeforeSensitive, c.Change.AfterSensitive),
		})
	}

	// Output changes still make the plan non-empty and must be applied to
	// reach the state, so they are reviewed like any other change.
	names := make([]string, 0, len(doc.OutputChanges))
	for n := range doc.OutputChanges {
		names = append(names, n)
	}

	sort.Strings(names)

	for _, n := range names {
		c := doc.OutputChanges[n]
		if len(c.Actions) == 1 && c.Actions[0] == "no-op" {
			continue
		}

		attrs := diff(c.Before, c.After, c.AfterUnknown, c.BeforeSensitive, c.AfterSensitive)
		for i := range attrs {
			if attrs[i].Name == "" {
				attrs[i].Name = "value"
			}
		}

		p.Changes = append(p.Changes, Change{Address: "output." + n, Actions: c.Actions, Attrs: attrs, Output: true})
	}

	return p, nil
}

const (
	maskSensitive = "(sensitive)"
	maskUnknown   = "(known after apply)"
)

// diff lists the attributes that differ between before and after, masking
// sensitive and unknown values.
func diff(before, after, unknown, beforeSensitive, afterSensitive any) []Attr {
	b := flatten("", before, beforeSensitive, nil)
	a := flatten("", after, afterSensitive, unknown)

	var names []string
	seen := map[string]bool{}

	for _, m := range []map[string]string{b, a} {
		for k := range m {
			if !seen[k] {
				seen[k] = true
				names = append(names, k)
			}
		}
	}

	sort.Strings(names)

	var attrs []Attr

	for _, n := range names {
		bv, hasB := b[n]
		av, hasA := a[n]

		if hasB && hasA && bv == av {
			continue
		}

		attrs = append(attrs, Attr{Name: n, Before: bv, After: av, HasBefore: hasB, HasAfter: hasA})
	}

	return attrs
}

// flatten turns a JSON value into dotted attribute paths. mask marks
// sensitive nodes (true) and unknown marks values not yet known.
func flatten(prefix string, v, sensitive, unknown any) map[string]string {
	out := map[string]string{}

	walk(out, prefix, v, sensitive, unknown)

	return out
}

func walk(out map[string]string, path string, v, sensitive, unknown any) {
	if t, ok := sensitive.(bool); ok && t {
		out[path] = maskSensitive

		return
	}

	if t, ok := unknown.(bool); ok && t {
		out[path] = maskUnknown

		return
	}

	switch x := v.(type) {
	case map[string]any:
		sm, _ := sensitive.(map[string]any)
		um, _ := unknown.(map[string]any)

		for k, c := range x {
			walk(out, join(path, k), c, sm[k], um[k])
		}

		for k, c := range um {
			if _, ok := x[k]; !ok {
				walk(out, join(path, k), nil, nil, c)
			}
		}
	case []any:
		sl, _ := sensitive.([]any)
		ul, _ := unknown.([]any)

		for i, c := range x {
			walk(out, fmt.Sprintf("%s[%d]", path, i), c, at(sl, i), at(ul, i))
		}

		for i := len(x); i < len(ul); i++ {
			walk(out, fmt.Sprintf("%s[%d]", path, i), nil, nil, ul[i])
		}
	case nil:
		if path != "" {
			out[path] = "null"
		}
	default:
		b, _ := json.Marshal(x)
		out[path] = string(b)
	}
}

func at(s []any, i int) any {
	if i < len(s) {
		return s[i]
	}

	return nil
}

func join(path, key string) string {
	if path == "" {
		return key
	}

	return path + "." + key
}

// Step is one resource operation reported by a running apply.
type Step struct {
	Address string
	Verb    string
	Elapsed string
	Done    bool
}

// Activity is what a running apply has reported so far.
type Activity struct {
	Steps []Step
}

var stepLine = regexp.MustCompile(`^(\S.*?): (Creating|Modifying|Destroying|Refreshing state|Still creating|Still modifying|Still destroying)\.\.\.(?: \[(.+?) elapsed\])?$`)
var doneLine = regexp.MustCompile(`^(\S.*?): (Creation|Modifications|Destruction) complete after (\S+)`)

// ApplyActivity reads the tofu output of the runner pod applying the
// Terraform object name, in the order resources were started.
func (r *Reader) ApplyActivity(ctx context.Context, namespace, name string) (Activity, error) {
	out, err := r.kubectl(ctx, namespace, "logs", name+"-tf-runner", "--tail=2000")
	if err != nil {
		return Activity{}, err
	}

	var (
		act   Activity
		index = map[string]int{}
	)

	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)

		if m := doneLine.FindStringSubmatch(line); m != nil {
			if i, ok := index[m[1]]; ok {
				act.Steps[i].Done, act.Steps[i].Elapsed = true, m[3]
			}

			continue
		}

		m := stepLine.FindStringSubmatch(line)
		if m == nil || m[2] == "Refreshing state" {
			continue
		}

		i, ok := index[m[1]]
		if !ok {
			index[m[1]] = len(act.Steps)
			act.Steps = append(act.Steps, Step{Address: m[1]})
			i = len(act.Steps) - 1
		}

		act.Steps[i].Verb, act.Steps[i].Elapsed = strings.ToLower(strings.TrimPrefix(m[2], "Still ")), m[3]
	}

	return act, nil
}
