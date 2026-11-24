package plan

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"
)

func encode(t *testing.T, body string) string {
	t.Helper()

	var buf bytes.Buffer

	zw := gzip.NewWriter(&buf)
	if _, err := zw.Write([]byte(body)); err != nil {
		t.Fatal(err)
	}

	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}

	return base64.StdEncoding.EncodeToString(buf.Bytes())
}

func fakeRunner(t *testing.T, pending, savedPlan, ownerUID, body string) Runner {
	t.Helper()

	return func(_ context.Context, _ string, args ...string) ([]byte, error) {
		if strings.Contains(strings.Join(args, " "), "get terraform") {
			return []byte(`{"metadata":{"uid":"u1","generation":2},"spec":{"workspace":"ws"},` +
				`"status":{"plan":{"pending":"` + pending + `"},"lastPlannedRevision":"main@sha1:abc","lastPlannedGeneration":2}}`), nil
		}

		secret := map[string]any{
			"metadata": map[string]any{
				"annotations":     map[string]string{"savedPlan": savedPlan},
				"ownerReferences": []map[string]string{{"kind": "Terraform", "uid": ownerUID}},
			},
			"data": map[string]string{"tfplan": encode(t, body)},
		}

		return json.Marshal(secret)
	}
}

const planBody = `{"resource_changes":[
 {"address":"a.b","change":{"actions":["create"]}},
 {"address":"a.c","change":{"actions":["no-op"]}},
 {"address":"a.d","change":{"actions":["delete","create"]}}]}`

func TestReadParsesChanges(t *testing.T) {
	r := &Reader{Context: "docker-desktop", Run: fakeRunner(t, "plan-1", "plan-1", "u1", planBody)}

	p, err := r.Read(context.Background(), "ns", "obj")
	if err != nil {
		t.Fatal(err)
	}

	if len(p.Changes) != 2 || !p.Destroys() || p.Summary() != "1 create, 1 delete+create" || len(p.SHA256) != 64 {
		t.Fatalf("plan = %+v summary=%q", p, p.Summary())
	}
}

func TestReadRejectsMismatchedPlan(t *testing.T) {
	cases := map[string]Runner{
		"plan id":    fakeRunner(t, "plan-1", "plan-2", "u1", planBody),
		"owner":      fakeRunner(t, "plan-1", "plan-1", "other", planBody),
		"no pending": fakeRunner(t, "", "", "u1", planBody),
	}

	for name, run := range cases {
		if _, err := (&Reader{Run: run}).Read(context.Background(), "ns", "obj"); err == nil {
			t.Errorf("%s: expected error", name)
		}
	}
}

func TestParseAttributeDiffMasksSecrets(t *testing.T) {
	body := `{"resource_changes":[{"address":"x.y","change":{"actions":["update"],
	"before":{"name":"a","password":"old","tags":{"env":"dev"},"same":1},
	"after":{"name":"b","password":"new","tags":{"env":"dev","team":"f"},"same":1,"id":null},
	"after_unknown":{"id":true},
	"before_sensitive":{"password":true},"after_sensitive":{"password":true}}}]}`

	p, err := parse("id", "rev", []byte(body))
	if err != nil {
		t.Fatal(err)
	}

	got := map[string]Attr{}
	for _, a := range p.Changes[0].Attrs {
		got[a.Name] = a
	}

	if _, ok := got["same"]; ok {
		t.Error("unchanged attributes must not be listed")
	}

	if a := got["name"]; a.Before != `"a"` || a.After != `"b"` {
		t.Errorf("name = %+v", a)
	}

	if a := got["tags.team"]; a.HasBefore || a.After != `"f"` {
		t.Errorf("tags.team = %+v", a)
	}

	if a := got["id"]; a.After != maskUnknown {
		t.Errorf("id = %+v", a)
	}

	if _, ok := got["password"]; ok {
		t.Error("an unchanged sensitive mask hides the value, so it must not show as a change")
	}
}

func TestApplyActivityTracksRunningAndFinished(t *testing.T) {
	log := `{"level":"info","msg":"running apply"}
module.a["x"].random_id.this: Creating...
module.a["x"].random_id.this: Creation complete after 0s [id=1]
module.a["x"].google_container_cluster.this: Creating...
module.a["x"].google_container_cluster.this: Still creating... [1m10s elapsed]
`
	r := &Reader{Context: "c", Run: func(context.Context, string, ...string) ([]byte, error) { return []byte(log), nil }}

	act, err := r.ApplyActivity(context.Background(), "ns", "name")
	if err != nil {
		t.Fatal(err)
	}

	if len(act.Steps) != 2 || !act.Steps[0].Done || act.Steps[1].Done || act.Steps[1].Elapsed != "1m10s" {
		t.Fatalf("steps = %+v", act.Steps)
	}
}

func TestParseIncludesOutputChanges(t *testing.T) {
	body := `{"resource_changes":[],"output_changes":{
		"runtime_networks":{"actions":["update"],"before":{"a":{"x":1}},"after":{"a":{"x":1,"repo":"r"}}},
		"token":{"actions":["create"],"before":null,"after_sensitive":true,"after_unknown":false},
		"same":{"actions":["no-op"],"before":1,"after":1}}}`

	p, err := parse("id", "rev", []byte(body))
	if err != nil {
		t.Fatal(err)
	}

	if len(p.Changes) != 2 || !p.Changes[0].Output || p.Changes[0].Address != "output.runtime_networks" {
		t.Fatalf("changes = %+v", p.Changes)
	}

	if got := p.Changes[0].Attrs; len(got) != 1 || got[0].Name != "a.repo" {
		t.Fatalf("attrs = %+v", got)
	}

	if p.Summary() != "2 output changes" || p.Destroys() {
		t.Fatalf("summary = %q", p.Summary())
	}
}
