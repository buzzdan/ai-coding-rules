package runner

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"example.com/ldd-eval/internal/trace"
)

const (
	filePerm       = 0o644
	killGrace      = 5 * time.Second
	scaffoldBudget = 5 * time.Minute
)

// ErrIncompleteTrace is returned when claude exited without a result event.
var ErrIncompleteTrace = errors.New("runner: trace has no result event")

// scaffold runs `<script> <dest>` and saves its combined output as
// <outDir>/scaffold.txt.
func scaffold(ctx context.Context, script, dest, outDir string) error {
	ctx, cancel := context.WithTimeout(ctx, scaffoldBudget)
	defer cancel()
	cmd := exec.CommandContext(ctx, script, dest)
	cmd.Dir = filepath.Dir(script)
	out, err := cmd.CombinedOutput()
	_ = os.WriteFile(filepath.Join(outDir, "scaffold.txt"), out, filePerm) // diagnostic artifact; failure is reported via err below
	if err != nil {
		return fmt.Errorf("scaffold %s: %w: %s", script, err, tail(out))
	}
	return nil
}

// agentSpec is one headless claude invocation.
type agentSpec struct {
	Prompt             string
	PluginDir          string
	Model              string
	MaxTurns           int
	Timeout            time.Duration
	AppendSystemPrompt string
	AllowedTools       []string
	WorkDir            string
	OutDir             string
}

// args renders the exact `claude -p` command line from the runner contract.
func (s agentSpec) args() []string {
	args := []string{
		"-p", s.Prompt,
		"--plugin-dir", s.PluginDir,
		"--output-format", "stream-json",
		"--verbose",
		"--model", s.Model,
		"--permission-mode", "bypassPermissions",
		"--max-turns", strconv.Itoa(s.MaxTurns),
		"--no-session-persistence",
	}
	if s.AppendSystemPrompt != "" {
		args = append(args, "--append-system-prompt", s.AppendSystemPrompt)
	}
	if len(s.AllowedTools) > 0 {
		args = append(args, "--allowedTools", strings.Join(s.AllowedTools, ","))
	}
	return args
}

// runAgent executes claude inside WorkDir, streaming stdout to
// <OutDir>/trace.jsonl and stderr to <OutDir>/stderr.txt, then parses the
// trace. IS_SANDBOX=1 is set because bypassPermissions is refused for root
// without it.
func runAgent(ctx context.Context, spec agentSpec) (trace.Trace, error) {
	ctx, cancel := context.WithTimeout(ctx, spec.Timeout)
	defer cancel()
	tracePath := filepath.Join(spec.OutDir, "trace.jsonl")
	traceFile, err := os.Create(tracePath)
	if err != nil {
		return trace.Trace{}, fmt.Errorf("runner: create trace: %w", err)
	}
	var stderr bytes.Buffer
	cmd := exec.CommandContext(ctx, "claude", spec.args()...)
	cmd.Dir = spec.WorkDir
	cmd.Env = append(os.Environ(), "IS_SANDBOX=1")
	cmd.Stdout, cmd.Stderr = traceFile, &stderr
	cmd.WaitDelay = killGrace
	// claude spawns tool subprocesses; on timeout kill its whole process group
	// so a lingering child cannot hold the stderr pipe open until WaitDelay.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	runErr := cmd.Run()
	_ = traceFile.Close()                                                                // flushed by the kernel on close; parse below reopens it
	_ = os.WriteFile(filepath.Join(spec.OutDir, "stderr.txt"), stderr.Bytes(), filePerm) // diagnostic artifact
	return parseAgentTrace(ctx, tracePath, runErr, stderr.Bytes())
}

func parseAgentTrace(ctx context.Context, tracePath string, runErr error, stderr []byte) (trace.Trace, error) {
	tr, perr := trace.ParseFile(tracePath)
	switch {
	case errors.Is(ctx.Err(), context.DeadlineExceeded):
		return trace.Trace{}, fmt.Errorf("runner: claude timed out: %w", ctx.Err())
	case perr != nil:
		return trace.Trace{}, fmt.Errorf("runner: %w", perr)
	case !tr.Complete():
		return trace.Trace{}, fmt.Errorf("%w (exit: %v): %s", ErrIncompleteTrace, runErr, tail(stderr))
	}
	return tr, nil
}

func tail(b []byte) string {
	const keep = 800
	s := strings.TrimSpace(string(b))
	if len(s) > keep {
		return "…" + s[len(s)-keep:]
	}
	return s
}
