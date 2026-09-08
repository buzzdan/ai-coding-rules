package grade

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// ErrBadScript is returned when a postcheck script is missing or not a file.
var ErrBadScript = errors.New("grade: postcheck script must be an existing executable file")

// Postcheck runs the case's script inside the kept scaffold dir with
// EVAL_DIR/EVAL_OUT set; exit 0 passes. Its stdout is saved as postcheck.txt.
type Postcheck struct {
	script string
}

// NewPostcheck validates the absolute script path and builds the grader.
func NewPostcheck(script string) (Postcheck, error) {
	script = strings.TrimSpace(script)
	if !filepath.IsAbs(script) {
		return Postcheck{}, fmt.Errorf("%w: %q is not absolute", ErrBadScript, script)
	}
	info, err := os.Stat(script)
	if err != nil {
		return Postcheck{}, fmt.Errorf("%w: %w", ErrBadScript, err)
	}
	if !info.Mode().IsRegular() || info.Mode().Perm()&0o111 == 0 {
		return Postcheck{}, fmt.Errorf("%w: %q", ErrBadScript, script)
	}
	return Postcheck{script: script}, nil
}

// Name implements Grader.
func (g Postcheck) Name() string { return "postcheck" }

// Type implements Grader.
func (g Postcheck) Type() string { return "postcheck" }

// NeedsScaffold implements ScaffoldReader.
func (g Postcheck) NeedsScaffold() bool { return true }

// Grade implements Grader.
func (g Postcheck) Grade(ctx context.Context, s Subject) Outcome {
	cmd := exec.CommandContext(ctx, g.script)
	cmd.Dir = s.Dir
	cmd.Env = append(os.Environ(), "EVAL_DIR="+s.Dir, "EVAL_OUT="+s.OutDir)
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	runErr := cmd.Run()
	if s.OutDir != "" {
		_ = os.WriteFile(filepath.Join(s.OutDir, "postcheck.txt"), stdout.Bytes(), 0o644) // best-effort artifact; findings are also in Detail
	}
	if runErr != nil {
		return failf(g.Name(), g.Type(), "%v\n%s", runErr, clip(strings.TrimSpace(stdout.String()+"\n"+stderr.String())))
	}
	return verdict(g.Name(), g.Type(), true, clip(strings.TrimSpace(stdout.String())))
}
