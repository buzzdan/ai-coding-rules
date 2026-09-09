// Package gen ties the generator to one repository checkout: it finds core/
// and lang/<lang>/, renders each binding, and either writes the plugin
// directory or reports how the committed one differs from the rendering.
package gen

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/binding"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/check"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/profile"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/render"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/residue"
)

const (
	coreDir    = "core"
	langDir    = "lang"
	coreReadme = "core/README.md"
)

// Repo is a checkout of this repository, addressed by its root.
type Repo struct {
	root string
}

// Open validates that root holds a lang/ directory; a path without one is not
// a checkout the generator can work on.
func Open(root string) (Repo, error) {
	info, err := os.Stat(filepath.Join(root, langDir))
	if err != nil {
		return Repo{}, fmt.Errorf("open %s: %w", root, err)
	}
	if !info.IsDir() {
		return Repo{}, errors.New("open: lang is not a directory")
	}
	return Repo{root: root}, nil
}

// Langs lists every binding directory under lang/, sorted.
func (r Repo) Langs() ([]string, error) {
	entries, err := os.ReadDir(filepath.Join(r.root, langDir))
	if err != nil {
		return nil, fmt.Errorf("langs: %w", err)
	}
	var langs []string
	for _, e := range entries {
		if e.IsDir() {
			langs = append(langs, e.Name())
		}
	}
	sort.Strings(langs)
	return langs, nil
}

// Render compiles core/ with one binding and returns the tree together with
// the binding's profile, which names the output directory.
func (r Repo) Render(lang string) (render.Tree, profile.Profile, error) {
	b, err := binding.Load(os.DirFS(filepath.Join(r.root, langDir, lang)))
	if err != nil {
		return nil, profile.Profile{}, err
	}
	tree, err := render.Render(os.DirFS(filepath.Join(r.root, coreDir)), b)
	if err != nil {
		return nil, profile.Profile{}, err
	}
	return tree, b.Profile(), nil
}

// Generate renders one binding and writes it over its plugin directory.
func (r Repo) Generate(lang string) error {
	tree, p, err := r.Render(lang)
	if err != nil {
		return err
	}
	return check.Write(tree, filepath.Join(r.root, p.Plugin), p.Ignored)
}

// Check renders every binding and compares each with its committed plugin
// directory, writing findings to w. It returns the number of differences.
func (r Repo) Check(w io.Writer) (int, error) {
	langs, err := r.Langs()
	if err != nil {
		return 0, err
	}
	total := 0
	for _, lang := range langs {
		n, err := r.checkOne(w, lang)
		if err != nil {
			return total, err
		}
		total += n
	}
	return total, nil
}

func (r Repo) checkOne(w io.Writer, lang string) (int, error) {
	tree, p, err := r.Render(lang)
	if err != nil {
		return 0, err
	}
	dir := filepath.Join(r.root, p.Plugin)
	diffs, err := check.Compare(tree, dir, p.Ignored)
	if err != nil {
		return 0, err
	}
	if len(diffs) > 0 {
		fmt.Fprintf(w, "%s: %d difference(s) between the rendering and %s/\n", lang, len(diffs), p.Plugin)
		check.Report(w, diffs, tree, dir)
	}
	return len(diffs), nil
}

// LintCore scans core/ for language residue and writes the report to w. With
// write set, the Residue section of core/README.md is rewritten from the
// report. It returns the number of hard hits, which must be zero.
func (r Repo) LintCore(w io.Writer, write bool) (int, error) {
	report, err := residue.Scan(os.DirFS(filepath.Join(r.root, coreDir)))
	if err != nil {
		return 0, err
	}
	fmt.Fprintln(w, strings.TrimSuffix(report.Markdown(), "\n"))
	if write {
		if err := residue.WriteReadme(filepath.Join(r.root, coreReadme), report); err != nil {
			return len(report.Hard), err
		}
	}
	return len(report.Hard), nil
}
