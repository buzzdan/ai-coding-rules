// Package gen ties the generator to one repository checkout: it finds core/
// and lang/<lang>/, renders each binding, and either writes the plugin
// directory or reports how the directory on disk differs from the rendering.
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

// Open validates that root holds both core/ and lang/. Without core/ a
// rendering would be empty and writing it would delete every templated file,
// so a root missing either directory is refused up front.
func Open(root string) (Repo, error) {
	for _, dir := range []string{coreDir, langDir} {
		if err := requireDir(filepath.Join(root, dir)); err != nil {
			return Repo{}, err
		}
	}
	return Repo{root: root}, nil
}

func requireDir(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("open: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("open: %s is not a directory", path)
	}
	return nil
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
	dir := filepath.Join(langDir, lang)
	b, err := binding.Load(os.DirFS(filepath.Join(r.root, dir)))
	if err != nil {
		return nil, profile.Profile{}, fmt.Errorf("%s: %w", dir, err)
	}
	tree, err := render.Render(os.DirFS(filepath.Join(r.root, coreDir)), b)
	if err != nil {
		return nil, profile.Profile{}, fmt.Errorf("%s: %w", dir, err)
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

// Check renders every binding and compares each with its plugin directory,
// writing findings to w. It returns the number of differences. A repository
// with no binding at all is an error, not a pass.
func (r Repo) Check(w io.Writer) (int, error) {
	langs, err := r.Langs()
	if err != nil {
		return 0, err
	}
	if len(langs) == 0 {
		return 0, errors.New("check: no binding under lang/")
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
// report. It returns the number of hard hits; the caller fails the run when
// that is not zero.
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
