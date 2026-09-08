package grade

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

// ErrNoVerdict is returned when the judge's reply has no final VERDICT line.
var ErrNoVerdict = errors.New("grade: judge reply has no `VERDICT: PASS|FAIL` line")

// ErrEmptyModel is returned when a Judge is built without a model.
var ErrEmptyModel = errors.New("grade: judge model is required")

// Verdict is one judge reply.
type Verdict struct {
	Passed  bool
	Reply   string
	CostUSD float64
}

// Judge runs `claude -p --model <judge> --output-format json --tools ""` with
// the prompt on stdin. Single vote — plugin-eval uses 2-of-3.
type Judge struct {
	model string
}

// NewJudge validates and builds a Judge.
func NewJudge(model string) (Judge, error) {
	model = strings.TrimSpace(model)
	if model == "" {
		return Judge{}, ErrEmptyModel
	}
	return Judge{model: model}, nil
}

// Model returns the judge model id.
func (j Judge) Model() string { return j.model }

type judgeResult struct {
	Result       string  `json:"result"`
	TotalCostUSD float64 `json:"total_cost_usd"`
	IsError      bool    `json:"is_error"`
	Subtype      string  `json:"subtype"`
}

// Ask sends the prompt to the judge model and parses the final VERDICT line.
func (j Judge) Ask(ctx context.Context, prompt string) (Verdict, error) {
	if j.model == "" {
		return Verdict{}, ErrEmptyModel
	}
	cmd := exec.CommandContext(ctx, "claude",
		"-p", "--model", j.model, "--output-format", "json",
		"--max-turns", "1", "--tools", "", "--no-session-persistence")
	cmd.Stdin = strings.NewReader(prompt)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return Verdict{}, fmt.Errorf("judge claude -p: %w: %s", err, clip(stderr.String()))
	}
	var res judgeResult
	if err := json.Unmarshal(bytes.TrimSpace(out), &res); err != nil {
		return Verdict{}, fmt.Errorf("judge output is not a result object: %w: %s", err, clip(string(out)))
	}
	if res.IsError {
		return Verdict{}, fmt.Errorf("judge run failed (%s): %s", res.Subtype, clip(res.Result))
	}
	passed, err := ParseVerdict(res.Result)
	if err != nil {
		return Verdict{}, err
	}
	return Verdict{Passed: passed, Reply: res.Result, CostUSD: res.TotalCostUSD}, nil
}

// ParseVerdict finds the last `VERDICT: PASS|FAIL` line of a reply
// (case-insensitive, tolerant of surrounding markdown emphasis).
func ParseVerdict(reply string) (bool, error) {
	re := regexp.MustCompile(`(?i)^\W*VERDICT\W*(PASS|FAIL)\W*$`)
	lines := strings.Split(reply, "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		m := re.FindStringSubmatch(strings.TrimSpace(lines[i]))
		if m != nil {
			return strings.EqualFold(m[1], "PASS"), nil
		}
	}
	return false, ErrNoVerdict
}
