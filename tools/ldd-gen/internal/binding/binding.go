// Package binding is one language's view of the generator inputs under
// lang/<lang>/: the profile, the snippet files core templates splice in with
// {{include "..."}}, whole-file overrides of core templates, and the files
// copied through to the plugin untouched.
package binding

import (
	"errors"
	"fmt"
	"io/fs"
	"strings"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/profile"
)

const (
	profileFile    = "profile.yaml"
	overridesDir   = "overrides"
	passthroughDir = "passthrough"
)

// Binding reads a language directory. Every path it hands out is relative to
// that directory, so the same binding works from a checkout or a test FS.
type Binding struct {
	fsys    fs.FS
	profile profile.Profile
}

// Load parses profile.yaml at the root of fsys. The profile is required; a
// language directory without one is not a binding.
func Load(fsys fs.FS) (Binding, error) {
	data, err := fs.ReadFile(fsys, profileFile)
	if err != nil {
		return Binding{}, fmt.Errorf("binding: %w", err)
	}
	p, err := profile.Parse(data)
	if err != nil {
		return Binding{}, err
	}
	return Binding{fsys: fsys, profile: p}, nil
}

// Profile returns the parsed profile.yaml.
func (b Binding) Profile() profile.Profile { return b.profile }

// Include returns the body of a snippet file with exactly one trailing newline
// removed. The template around the include owns the surrounding blank lines,
// which is what lets a rendered file match the original byte for byte.
func (b Binding) Include(name string) (string, error) {
	data, err := fs.ReadFile(b.fsys, name)
	if err != nil {
		return "", fmt.Errorf("include %q: %w", name, err)
	}
	return strings.TrimSuffix(string(data), "\n"), nil
}

// Override returns the binding's replacement for a core template, when one
// exists under overrides/<corePath>. The second result is false when core's
// own file should be used.
func (b Binding) Override(corePath string) ([]byte, bool, error) {
	data, err := fs.ReadFile(b.fsys, overridesDir+"/"+corePath)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("override %q: %w", corePath, err)
	}
	return data, true, nil
}

// Passthrough returns the tree of files copied verbatim into the plugin. A
// binding without a passthrough directory yields an empty tree.
func (b Binding) Passthrough() (fs.FS, error) {
	info, err := fs.Stat(b.fsys, passthroughDir)
	if errors.Is(err, fs.ErrNotExist) {
		return emptyFS{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("passthrough: %w", err)
	}
	if !info.IsDir() {
		return nil, errors.New("passthrough: not a directory")
	}
	sub, err := fs.Sub(b.fsys, passthroughDir)
	if err != nil {
		return nil, fmt.Errorf("passthrough: %w", err)
	}
	return sub, nil
}

// emptyFS is a file system with nothing in it, so callers can walk a binding
// that has no passthrough directory without a special case.
type emptyFS struct{}

func (emptyFS) Open(name string) (fs.File, error) {
	return nil, &fs.PathError{Op: "open", Path: name, Err: fs.ErrNotExist}
}
