package gitlog

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestReadListsCommitsAndFiles(t *testing.T) {
	dir := t.TempDir()

	run := func(args ...string) string {
		cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null"}, args...)...)

		out, err := cmd.CombinedOutput()
		if err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}

		return strings.TrimSpace(string(out))
	}

	run("init", "-q")

	commit := func(file, subject string) string {
		if err := os.MkdirAll(filepath.Join(dir, filepath.Dir(file)), 0o755); err != nil {
			t.Fatal(err)
		}

		if err := os.WriteFile(filepath.Join(dir, file), []byte("x\n"), 0o600); err != nil {
			t.Fatal(err)
		}

		run("add", ".")
		run("commit", "-q", "-m", subject)

		return run("rev-parse", "--short", "HEAD")
	}

	first := commit("a/one.tofu", "First")
	commit("a/two.tofu", "Second")
	last := commit("b/other.tofu", "Third")

	l, err := Read(context.Background(), dir, first, last, "./a")
	if err != nil {
		t.Fatal(err)
	}

	if len(l.Commits) != 1 || l.Commits[0].Subject != "Second" || len(l.Files) != 1 || l.Files[0].Path != "a/two.tofu" {
		t.Fatalf("log = %+v", l)
	}

	lines, more, err := Diff(context.Background(), dir, first, last, "", "a/two.tofu")
	if err != nil || more != 0 || !strings.Contains(strings.Join(lines, "\n"), "+x") {
		t.Fatalf("diff = %v, %d, %v", lines, more, err)
	}

	if _, err := Read(context.Background(), dir, "", "--output=x", ""); err == nil {
		t.Fatal("unsafe revision accepted")
	}
}
