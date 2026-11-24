// Package gitlog describes the commits and files behind a workspace's
// revision, read from a local checkout of the source repository.
package gitlog

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

// Commit is one commit's headline.
type Commit struct {
	Hash    string
	Subject string
	Author  string
	Date    string
}

// File is one file changed by a range of commits.
type File struct {
	Path    string
	Added   string
	Deleted string
}

// Log is a range of commits and the files they changed.
type Log struct {
	Commits []Commit
	Files   []File
	More    int
}

const maxCommits = 8

var revision = regexp.MustCompile(`^[0-9a-f]{4,40}$`)

// Read lists the commits after from up to and including to, and the files
// changed under path. An empty from describes only the commit to.
func Read(ctx context.Context, dir, from, to, path string) (Log, error) {
	if dir == "" {
		return Log{}, errors.New("no local checkout")
	}

	if !revision.MatchString(to) || (from != "" && !revision.MatchString(from)) {
		return Log{}, errors.New("unrecognized revision")
	}

	span := to + "^.." + to
	if from != "" {
		span = from + ".." + to
	}

	pathspec := scope(path)

	out, err := git(ctx, dir, append([]string{"log", "--format=%h%x09%an%x09%as%x09%s", span}, pathspec...)...)
	if err != nil {
		return Log{}, err
	}

	var l Log

	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		f := strings.SplitN(line, "\t", 4)
		if len(f) != 4 {
			continue
		}

		if len(l.Commits) == maxCommits {
			l.More++

			continue
		}

		l.Commits = append(l.Commits, Commit{Hash: f[0], Author: f[1], Date: f[2], Subject: f[3]})
	}

	files, err := git(ctx, dir, append([]string{"diff", "--numstat", span}, pathspec...)...)
	if err != nil {
		return Log{}, err
	}

	for _, line := range strings.Split(strings.TrimSpace(files), "\n") {
		f := strings.Fields(line)
		if len(f) == 3 {
			l.Files = append(l.Files, File{Path: f[2], Added: f[0], Deleted: f[1]})
		}
	}

	return l, nil
}

func scope(path string) []string {
	pathspec := []string{"--"}
	if p := strings.TrimPrefix(strings.TrimSpace(path), "./"); p != "" && p != "." {
		pathspec = append(pathspec, p)
	}

	return pathspec
}

// maxDiffLines bounds how much of a diff is returned.
const maxDiffLines = 400

// Diff returns the unified diff of the range, limited to path, or to the one
// file when file is set. It stops after maxDiffLines and reports how many
// lines were left out.
func Diff(ctx context.Context, dir, from, to, path, file string) (lines []string, more int, err error) {
	if dir == "" {
		return nil, 0, errors.New("no local checkout")
	}

	if !revision.MatchString(to) || (from != "" && !revision.MatchString(from)) {
		return nil, 0, errors.New("unrecognized revision")
	}

	span := to + "^.." + to
	if from != "" {
		span = from + ".." + to
	}

	pathspec := scope(path)
	if file != "" {
		pathspec = []string{"--", file}
	}

	out, err := git(ctx, dir, append([]string{"diff", "--no-color", "--no-ext-diff", span}, pathspec...)...)
	if err != nil {
		return nil, 0, err
	}

	lines = strings.Split(strings.TrimRight(out, "\n"), "\n")
	if len(lines) > maxDiffLines {
		more, lines = len(lines)-maxDiffLines, lines[:maxDiffLines]
	}

	return lines, more, nil
}

func git(ctx context.Context, dir string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", append([]string{"-C", dir}, args...)...)

	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("git %s: %w", args[0], err)
	}

	return string(out), nil
}
