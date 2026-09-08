package grade

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// ErrBadGlob is returned for an empty or absolute file_exists path.
var ErrBadGlob = errors.New("grade: file_exists path must be a non-empty relative glob")

// countMatchingLines implements `target: files`: the number of lines matching
// re across every regular file under root, skipping .git.
func countMatchingLines(root string, re *regexp.Regexp) (int, error) {
	total := 0
	walk := func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return fmt.Errorf("walk %s: %w", path, err)
		}
		if d.IsDir() {
			return skipGit(d)
		}
		if !d.Type().IsRegular() {
			return nil
		}
		n, ferr := countLinesInFile(path, re)
		total += n
		return ferr
	}
	if err := filepath.WalkDir(root, walk); err != nil {
		return 0, fmt.Errorf("files target: %w", err)
	}
	return total, nil
}

func skipGit(d fs.DirEntry) error {
	if d.Name() == ".git" {
		return filepath.SkipDir
	}
	return nil
}

func countLinesInFile(path string, re *regexp.Regexp) (int, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, fmt.Errorf("open %s: %w", path, err)
	}
	defer func() { _ = f.Close() }() // read-only handle; nothing to report on close
	n := 0
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 16*1024*1024)
	for sc.Scan() {
		if re.MatchString(sc.Text()) {
			n++
		}
	}
	if err := sc.Err(); err != nil {
		return n, fmt.Errorf("read %s: %w", path, err)
	}
	return n, nil
}

// FileExists asserts that a glob (relative to the scaffold dir) matches at
// least one path. filepath.Glob semantics: no `**`.
type FileExists struct {
	name    string
	pattern string
}

// NewFileExists validates and builds a FileExists grader.
func NewFileExists(name, pattern string) (FileExists, error) {
	if strings.TrimSpace(name) == "" {
		return FileExists{}, ErrEmptyName
	}
	pattern = strings.TrimSpace(pattern)
	if pattern == "" || filepath.IsAbs(pattern) {
		return FileExists{}, fmt.Errorf("grader %s: %w: %q", name, ErrBadGlob, pattern)
	}
	if _, err := filepath.Match(pattern, ""); err != nil {
		return FileExists{}, fmt.Errorf("grader %s: %w: %w", name, ErrBadGlob, err)
	}
	return FileExists{name: name, pattern: pattern}, nil
}

// Name implements Grader.
func (g FileExists) Name() string { return g.name }

// Type implements Grader.
func (g FileExists) Type() string { return "file_exists" }

// NeedsScaffold implements ScaffoldReader.
func (g FileExists) NeedsScaffold() bool { return true }

// Grade implements Grader.
func (g FileExists) Grade(_ context.Context, s Subject) Outcome {
	matches, err := filepath.Glob(filepath.Join(s.Dir, g.pattern))
	if err != nil {
		return failf(g.name, g.Type(), "glob %s: %v", g.pattern, err)
	}
	if len(matches) == 0 {
		return failf(g.name, g.Type(), "no file matches %s", g.pattern)
	}
	rel := make([]string, 0, len(matches))
	for _, m := range matches {
		r, rerr := filepath.Rel(s.Dir, m)
		if rerr != nil {
			r = m
		}
		rel = append(rel, r)
	}
	return verdict(g.name, g.Type(), true, clip(fmt.Sprintf("%d match(es): %s", len(rel), strings.Join(rel, ", "))))
}
