// Package render compiles core templates plus one language binding into the
// plugin tree: every output path with its bytes and executable bit. The tree
// is produced in memory so the same rendering can be written to disk or
// compared against a committed directory.
package render

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"text/template"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/binding"
)

// coreReadme documents the core directory itself and is never rendered into a
// plugin; every other file under core/ is a template.
const coreReadme = "README.md"

// File is one rendered plugin file. Exec mirrors the source file's executable
// bit so hooks and gate scripts stay runnable after generation.
type File struct {
	Data []byte
	Exec bool
}

// Tree maps plugin-relative output paths to their rendered files.
type Tree map[string]File

// Render templates every core file through the binding, then adds the
// binding's passthrough files. An output path claimed twice is an error, so a
// passthrough copy can never silently shadow a rendered template.
func Render(core fs.FS, b binding.Binding) (Tree, error) {
	r := renderer{binding: b, tree: Tree{}}
	if err := walkFiles(core, r.renderCore); err != nil {
		return nil, err
	}
	pt, err := b.Passthrough()
	if err != nil {
		return nil, err
	}
	if err := walkFiles(pt, r.copyPassthrough); err != nil {
		return nil, err
	}
	return r.tree, nil
}

type renderer struct {
	binding binding.Binding
	tree    Tree
}

func (r *renderer) renderCore(fsys fs.FS, path string) error {
	if path == coreReadme {
		return nil
	}
	src, err := r.source(fsys, path)
	if err != nil {
		return err
	}
	out, err := r.execute(path, string(src))
	if err != nil {
		return err
	}
	outPath, err := r.execute(path+" (name)", path)
	if err != nil {
		return err
	}
	exec, err := isExecutable(fsys, path)
	if err != nil {
		return err
	}
	return r.add(string(outPath), File{Data: out, Exec: exec})
}

func (r *renderer) source(core fs.FS, path string) ([]byte, error) {
	if data, ok, err := r.binding.Override(path); ok || err != nil {
		return data, err
	}
	data, err := fs.ReadFile(core, path)
	if err != nil {
		return nil, fmt.Errorf("core: %w", err)
	}
	return data, nil
}

func (r *renderer) execute(name, text string) ([]byte, error) {
	funcs := template.FuncMap{"include": r.binding.Include}
	tmpl, err := template.New(name).Funcs(funcs).Option("missingkey=error").Parse(text)
	if err != nil {
		return nil, fmt.Errorf("template %s: %w", name, err)
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, r.binding.Profile().Vars); err != nil {
		return nil, fmt.Errorf("template %s: %w", name, err)
	}
	return buf.Bytes(), nil
}

func (r *renderer) copyPassthrough(fsys fs.FS, path string) error {
	data, err := fs.ReadFile(fsys, path)
	if err != nil {
		return fmt.Errorf("passthrough: %w", err)
	}
	exec, err := isExecutable(fsys, path)
	if err != nil {
		return err
	}
	return r.add(path, File{Data: data, Exec: exec})
}

func (r *renderer) add(path string, f File) error {
	if _, dup := r.tree[path]; dup {
		return fmt.Errorf("output %q is produced by two sources", path)
	}
	r.tree[path] = f
	return nil
}

func isExecutable(fsys fs.FS, path string) (bool, error) {
	info, err := fs.Stat(fsys, path)
	if err != nil {
		return false, fmt.Errorf("stat %s: %w", path, err)
	}
	return info.Mode()&0o111 != 0, nil
}

// walkFiles calls visit for every regular file. A missing root is an empty
// tree, which is what a binding without passthrough or a repo without core
// looks like on day one.
func walkFiles(fsys fs.FS, visit func(fs.FS, string) error) error {
	err := fs.WalkDir(fsys, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if path == "." && errors.Is(err, fs.ErrNotExist) {
				return fs.SkipAll
			}
			return err
		}
		if d.IsDir() {
			return nil
		}
		return visit(fsys, path)
	})
	if err != nil {
		return fmt.Errorf("walk: %w", err)
	}
	return nil
}
