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
	"testing/fstest"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/profile"
)

const (
	profileFile    = "profile.yaml"
	overridesDir   = "overrides"
	passthroughDir = "passthrough"
)

// Binding reads a language directory. Every path it accepts is relative to
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

// Overrides returns the tree of whole-file replacements for core templates,
// keyed by the core path they replace. A binding without an overrides
// directory yields an empty tree.
func (b Binding) Overrides() (fs.FS, error) {
	return b.optionalDir(overridesDir)
}

// Passthrough returns the tree of files copied into the plugin unchanged. A
// binding without a passthrough directory yields an empty tree.
func (b Binding) Passthrough() (fs.FS, error) {
	return b.optionalDir(passthroughDir)
}

func (b Binding) optionalDir(name string) (fs.FS, error) {
	info, err := fs.Stat(b.fsys, name)
	if errors.Is(err, fs.ErrNotExist) {
		return fstest.MapFS{}, nil // an empty tree that walks cleanly
	}
	if err != nil {
		return nil, fmt.Errorf("%s: %w", name, err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("%s: not a directory", name)
	}
	sub, err := fs.Sub(b.fsys, name)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", name, err)
	}
	return sub, nil
}
