// Package cli parses the ldd-eval command line and maps runner outcomes to
// exit codes: 0 every case meets the threshold, 1 otherwise, 2 budget
// exceeded, 3 usage or infrastructure error.
package cli

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"

	"example.com/ldd-eval/internal/runner"
)

// Exit codes.
const (
	ExitPass     = 0
	ExitFail     = 1
	ExitBudget   = 2
	ExitUsage    = 3
	usage        = "usage: ldd-eval run [flags] <evals-dir>\n       ldd-eval regrade --out <dir> [flags] <evals-dir>\n"
	flagsPreface = "flags:\n"
)

// ErrOutRequired is returned when regrade is invoked without --out.
var ErrOutRequired = errors.New("cli: regrade requires --out <dir> naming a previous run")

// Run parses args (without the program name) and executes the command.
func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		_, _ = fmt.Fprint(stderr, usage) // usage text; nothing to do on write failure
		return ExitUsage
	}
	switch args[0] {
	case "run":
		opts, err := parseFlags("run", args[1:], stdout, stderr)
		if err != nil {
			return ExitUsage
		}
		return execute(context.Background(), opts, stderr)
	case "regrade":
		opts, err := parseFlags("regrade", args[1:], stdout, stderr)
		if err != nil {
			return ExitUsage
		}
		return regrade(context.Background(), opts, stderr)
	default:
		_, _ = fmt.Fprint(stderr, usage) // usage text; nothing to do on write failure
		return ExitUsage
	}
}

func execute(ctx context.Context, opts runner.Options, stderr io.Writer) int {
	r, err := runner.New(opts)
	if err != nil {
		_, _ = fmt.Fprintln(stderr, "ldd-eval:", err)
		return ExitUsage
	}
	_, _ = fmt.Fprintf(opts.Progress, "ldd-eval: %d case(s) -> %s\n", len(r.Cases()), r.OutDir())
	agg, err := r.Run(ctx)
	switch {
	case errors.Is(err, runner.ErrBudgetExceeded):
		_, _ = fmt.Fprintln(stderr, "ldd-eval:", agg.Aborted)
		return ExitBudget
	case err != nil:
		_, _ = fmt.Fprintln(stderr, "ldd-eval:", err)
		return ExitUsage
	case r.Threshold().Met(agg):
		return ExitPass
	default:
		_, _ = fmt.Fprintf(stderr, "ldd-eval: some cases fell below the pass-rate threshold %.2f\n", r.Threshold().Value())
		return ExitFail
	}
}

// regrade re-applies the current graders to the traces recorded under --out.
func regrade(ctx context.Context, opts runner.Options, stderr io.Writer) int {
	if opts.OutDir == "" {
		_, _ = fmt.Fprintln(stderr, "ldd-eval:", ErrOutRequired)
		return ExitUsage
	}
	r, err := runner.New(opts)
	if err != nil {
		_, _ = fmt.Fprintln(stderr, "ldd-eval:", err)
		return ExitUsage
	}
	_, _ = fmt.Fprintf(opts.Progress, "ldd-eval: regrading %d case(s) under %s\n", len(r.Cases()), r.OutDir())
	agg, err := r.Regrade(ctx)
	switch {
	case err != nil:
		_, _ = fmt.Fprintln(stderr, "ldd-eval:", err)
		return ExitUsage
	case r.Threshold().Met(agg):
		return ExitPass
	default:
		_, _ = fmt.Fprintf(stderr, "ldd-eval: some cases fell below the pass-rate threshold %.2f\n", r.Threshold().Value())
		return ExitFail
	}
}

func parseFlags(cmd string, args []string, stdout, stderr io.Writer) (runner.Options, error) {
	fs := flag.NewFlagSet("ldd-eval "+cmd, flag.ContinueOnError)
	fs.SetOutput(stderr)
	var opts runner.Options
	fs.StringVar(&opts.CaseGlob, "case", "", "only cases whose name matches this glob")
	fs.StringVar(&opts.Tag, "tag", "", "only cases carrying this tag")
	fs.StringVar(&opts.JudgeModel, "judge-model", "claude-haiku-4-5", "model for llm graders")
	fs.StringVar(&opts.PluginDir, "plugin-dir", "", "plugin root passed to claude --plugin-dir (default: parent of <evals-dir>)")
	fs.StringVar(&opts.OutDir, "out", "", "output dir (run: default <evals-dir>/results/<timestamp>; regrade: required, a previous run)")
	fs.Float64Var(&opts.Threshold, "threshold", 1.0, "per-case pass rate required for exit 0")
	if cmd == "run" {
		fs.IntVar(&opts.Runs, "runs", 0, "runs per case (0 = the case's own runs)")
		fs.StringVar(&opts.Model, "model", "", "agent model; overrides the case's model (default: case model, else claude-sonnet-5)")
		fs.BoolVar(&opts.KeepTemp, "keep-temp", false, "keep the scaffold dirs (path recorded in result.json)")
		fs.Float64Var(&opts.MaxCostUSD, "max-cost-usd", 0, "abort with exit 2 once cumulative cost exceeds this (0 = unlimited)")
	}
	fs.Usage = func() {
		_, _ = fmt.Fprint(stderr, usage, flagsPreface) // usage text; nothing to do on write failure
		fs.PrintDefaults()
	}
	if err := fs.Parse(args); err != nil {
		return runner.Options{}, fmt.Errorf("cli: %w", err)
	}
	if fs.NArg() != 1 {
		fs.Usage()
		return runner.Options{}, errors.New("cli: exactly one <evals-dir> is required")
	}
	opts.EvalsDir = fs.Arg(0)
	opts.Progress = stdout
	return opts, nil
}
