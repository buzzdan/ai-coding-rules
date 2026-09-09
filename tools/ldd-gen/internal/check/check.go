// Package check compares a rendered plugin tree with the directory committed
// in git and writes the tree back to disk. The committed directory is the
// generator's characterization test: any byte it would change is a finding.
package check

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/render"
)

// Kind says how a committed path disagrees with the rendered tree.
type Kind string

// The four ways a committed file can disagree with its rendering.
const (
	Missing     Kind = "missing"      // rendered, not on disk
	Extra       Kind = "extra"        // on disk, not rendered, not ignored
	Changed     Kind = "changed"      // bytes differ
	ExecChanged Kind = "exec-changed" // same bytes, different executable bit
)

// Difference is one path where the committed directory and the rendered tree
// disagree.
type Difference struct {
	Path string
	Kind Kind
}

// Ignore reports output paths the generator does not own, such as eval cases a
// run copies into the plugin directory.
type Ignore func(rel string) bool

// Compare lists every difference between the rendered tree and dir, sorted by
// path. An empty result means the directory is exactly what the generator
// would produce.
func Compare(want render.Tree, dir string, ignore Ignore) ([]Difference, error) {
	have, err := readDir(dir, orIgnored(want, ignore))
	if err != nil {
		return nil, err
	}
	var diffs []Difference
	for path, w := range want {
		h, ok := have[path]
		if !ok {
			diffs = append(diffs, Difference{Path: path, Kind: Missing})
			continue
		}
		if kind, differs := compareFile(w, h); differs {
			diffs = append(diffs, Difference{Path: path, Kind: kind})
		}
	}
	for path := range have {
		if _, ok := want[path]; !ok {
			diffs = append(diffs, Difference{Path: path, Kind: Extra})
		}
	}
	sort.Slice(diffs, func(i, j int) bool { return diffs[i].Path < diffs[j].Path })
	return diffs, nil
}

// orIgnored narrows an ignore rule to paths the tree does not produce: a file
// the generator owns is always compared, even inside an ignored directory.
func orIgnored(tree render.Tree, ignore Ignore) Ignore {
	return func(rel string) bool {
		_, owned := tree[rel]
		return !owned && ignore(rel)
	}
}

func compareFile(want, have render.File) (Kind, bool) {
	if !bytes.Equal(want.Data, have.Data) {
		return Changed, true
	}
	if want.Exec != have.Exec {
		return ExecChanged, true
	}
	return "", false
}

// Write replaces dir with the rendered tree: every file the generator owns is
// written, every other file that is not ignored is removed, and directories
// left empty are dropped. Ignored files are never touched.
func Write(tree render.Tree, dir string, ignore Ignore) error {
	have, err := readDir(dir, orIgnored(tree, ignore))
	if err != nil {
		return err
	}
	for path := range have {
		if _, keep := tree[path]; !keep {
			if err := os.Remove(filepath.Join(dir, path)); err != nil {
				return fmt.Errorf("remove: %w", err)
			}
		}
	}
	for path, f := range tree {
		if err := writeFile(filepath.Join(dir, path), f); err != nil {
			return err
		}
	}
	return removeEmptyDirs(dir)
}

func writeFile(path string, f render.File) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("mkdir: %w", err)
	}
	mode := os.FileMode(0o644)
	if f.Exec {
		mode = 0o755
	}
	if err := os.WriteFile(path, f.Data, mode); err != nil {
		return fmt.Errorf("write: %w", err)
	}
	// WriteFile only applies mode to new files; existing ones keep theirs.
	if err := os.Chmod(path, mode); err != nil {
		return fmt.Errorf("chmod: %w", err)
	}
	return nil
}

func removeEmptyDirs(dir string) error {
	var dirs []string
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err == nil && d.IsDir() && path != dir {
			dirs = append(dirs, path)
		}
		return err
	})
	if err != nil {
		return fmt.Errorf("walk: %w", err)
	}
	// Deepest first, so a directory whose only child was empty goes too.
	sort.Sort(sort.Reverse(sort.StringSlice(dirs)))
	for _, d := range dirs {
		if err := os.Remove(d); err != nil && !isNotEmpty(err) {
			return fmt.Errorf("rmdir: %w", err)
		}
	}
	return nil
}

func isNotEmpty(err error) bool {
	var pathErr *fs.PathError
	return errors.As(err, &pathErr) && pathErr.Err.Error() == "directory not empty"
}

// readDir loads the committed directory as a tree, skipping paths the caller
// does not care about. A missing directory reads as empty so the first
// generation can create it.
func readDir(dir string, skip Ignore) (render.Tree, error) {
	tree := render.Tree{}
	fsys := os.DirFS(dir)
	err := fs.WalkDir(fsys, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if path == "." && errors.Is(err, fs.ErrNotExist) {
				return fs.SkipAll
			}
			return err
		}
		if d.IsDir() || skip(path) {
			return nil
		}
		f, err := readFile(fsys, path)
		if err != nil {
			return err
		}
		tree[path] = f
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", dir, err)
	}
	return tree, nil
}

func readFile(fsys fs.FS, path string) (render.File, error) {
	data, err := fs.ReadFile(fsys, path)
	if err != nil {
		return render.File{}, fmt.Errorf("read: %w", err)
	}
	info, err := fs.Stat(fsys, path)
	if err != nil {
		return render.File{}, fmt.Errorf("stat: %w", err)
	}
	return render.File{Data: data, Exec: info.Mode()&0o111 != 0}, nil
}

// Report prints one line per difference and, for changed files, a unified
// diff from the committed file to the rendering when diff(1) is available.
func Report(w io.Writer, diffs []Difference, want render.Tree, dir string) {
	for _, d := range diffs {
		fmt.Fprintf(w, "%-13s %s\n", d.Kind, d.Path)
		if d.Kind == Changed {
			unifiedDiff(w, filepath.Join(dir, d.Path), want[d.Path].Data)
		}
	}
}

func unifiedDiff(w io.Writer, committed string, rendered []byte) {
	tmp, err := os.CreateTemp("", "ldd-gen-*")
	if err != nil {
		return
	}
	defer removeTemp(tmp.Name())
	if _, err := tmp.Write(rendered); err != nil {
		return
	}
	if err := tmp.Close(); err != nil {
		return
	}
	cmd := exec.Command("diff", "-u", committed, tmp.Name())
	cmd.Stdout = w
	_ = cmd.Run() // exit 1 means "files differ", which is the point
}

// removeTemp drops the scratch file; the diff is already printed, so a failed
// cleanup has nothing left to affect.
func removeTemp(path string) { _ = os.Remove(path) }
