package trace_test

import (
	"math"
	"strings"
	"testing"

	"example.com/ldd-eval/internal/trace"
)

const smokeTrace = "../../testdata/trace-smoke.jsonl"

const twoToolsTrace = "../../testdata/trace-two-tools.jsonl"

func TestParseFile_SmokeTrace_ToolCalls(t *testing.T) {
	t.Parallel()
	tr, err := trace.ParseFile(smokeTrace)
	if err != nil {
		t.Fatalf("ParseFile: %v", err)
	}
	calls := tr.ToolCalls()
	if len(calls) != 1 {
		t.Fatalf("ToolCalls() len = %d, want 1: %+v", len(calls), calls)
	}
	if calls[0].Name != "Bash" {
		t.Errorf("ToolCalls()[0].Name = %q, want Bash", calls[0].Name)
	}
	wantInput := `{"command":"ls","description":"List files in current directory"}`
	if calls[0].Input != wantInput {
		t.Errorf("ToolCalls()[0].Input = %s, want %s", calls[0].Input, wantInput)
	}
}

func TestParseFile_SmokeTrace_ResultEvent(t *testing.T) {
	t.Parallel()
	tr, err := trace.ParseFile(smokeTrace)
	if err != nil {
		t.Fatalf("ParseFile: %v", err)
	}
	if !tr.Complete() {
		t.Error("Complete() = false, want true")
	}
	if tr.IsError() {
		t.Error("IsError() = true, want false")
	}
	if tr.Subtype() != "success" {
		t.Errorf("Subtype() = %q, want success", tr.Subtype())
	}
	if tr.LastMessage() != "DONE" {
		t.Errorf("LastMessage() = %q, want DONE", tr.LastMessage())
	}
}

func TestParseFile_SmokeTrace_Counters(t *testing.T) {
	t.Parallel()
	tr, err := trace.ParseFile(smokeTrace)
	if err != nil {
		t.Fatalf("ParseFile: %v", err)
	}
	if math.Abs(tr.CostUSD()-0.0658678) > 1e-9 {
		t.Errorf("CostUSD() = %v, want 0.0658678", tr.CostUSD())
	}
	if tr.DurationMS() != 4466 {
		t.Errorf("DurationMS() = %d, want 4466", tr.DurationMS())
	}
	if tr.NumTurns() != 2 {
		t.Errorf("NumTurns() = %d, want 2", tr.NumTurns())
	}
	if tr.Events() != 44 {
		t.Errorf("Events() = %d, want 44", tr.Events())
	}
	if !strings.Contains(tr.Raw(), `"subtype":"init"`) {
		t.Error("Raw() should contain the init system event")
	}
}

func TestParseFile_TwoToolsTrace_OrderedCalls(t *testing.T) {
	t.Parallel()
	tr, err := trace.ParseFile(twoToolsTrace)
	if err != nil {
		t.Fatalf("ParseFile: %v", err)
	}
	calls := tr.ToolCalls()
	if len(calls) != 3 {
		t.Fatalf("ToolCalls() len = %d, want 3", len(calls))
	}
	wantNames := []string{"Skill", "Bash", "Write"}
	for i, want := range wantNames {
		if calls[i].Name != want {
			t.Errorf("ToolCalls()[%d].Name = %q, want %q", i, calls[i].Name, want)
		}
	}
	if !strings.Contains(calls[2].Input, `"file_path":"hello.go"`) {
		t.Errorf("Write input = %s, want file_path hello.go", calls[2].Input)
	}
}

func TestParse_LastMessageFallsBackToAssistantText(t *testing.T) {
	t.Parallel()
	input := strings.Join([]string{
		`{"type":"system","subtype":"init"}`,
		`{"type":"assistant","message":{"content":[{"type":"text","text":"first"}]}}`,
		`{"type":"assistant","message":{"content":[{"type":"thinking","thinking":"..."}]}}`,
		`{"type":"assistant","message":{"content":[{"type":"text","text":"  "}]}}`,
		`{"type":"assistant","message":{"content":[{"type":"text","text":"final words"}]}}`,
		`{"type":"user","message":{"content":"plain string content is fine"}}`,
		`{"type":"result","subtype":"error_max_turns","result":"","is_error":true,"total_cost_usd":0.5,"num_turns":10}`,
	}, "\n")
	tr, err := trace.Parse(strings.NewReader(input))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if tr.LastMessage() != "final words" {
		t.Errorf("LastMessage() = %q, want %q", tr.LastMessage(), "final words")
	}
	if !tr.IsError() || tr.Subtype() != "error_max_turns" {
		t.Errorf("IsError()/Subtype() = %v/%q, want true/error_max_turns", tr.IsError(), tr.Subtype())
	}
}

func TestParse_IncompleteTraceHasNoResult(t *testing.T) {
	t.Parallel()
	input := `{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"a.go"}}]}}` + "\n"
	tr, err := trace.Parse(strings.NewReader(input))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if tr.Complete() {
		t.Error("Complete() = true, want false")
	}
	if tr.CostUSD() != 0 || tr.NumTurns() != 0 || tr.LastMessage() != "" {
		t.Errorf("incomplete trace should have zero counters, got cost %v turns %d msg %q", tr.CostUSD(), tr.NumTurns(), tr.LastMessage())
	}
	if len(tr.ToolCalls()) != 1 {
		t.Errorf("ToolCalls() len = %d, want 1", len(tr.ToolCalls()))
	}
}

func TestParse_EmptyInput(t *testing.T) {
	t.Parallel()
	tr, err := trace.Parse(strings.NewReader(""))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if tr.Complete() || tr.Events() != 0 {
		t.Errorf("empty trace should be incomplete with 0 events, got complete=%v events=%d", tr.Complete(), tr.Events())
	}
}

func TestParse_ToolUseWithoutInputEncodesEmptyObject(t *testing.T) {
	t.Parallel()
	input := `{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill"}]}}`
	tr, err := trace.Parse(strings.NewReader(input))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if got := tr.ToolCalls()[0].Input; got != "{}" {
		t.Errorf("Input = %q, want {}", got)
	}
}

func TestParse_ToolCallsReturnsCopy(t *testing.T) {
	t.Parallel()
	tr, err := trace.ParseFile(smokeTrace)
	if err != nil {
		t.Fatalf("ParseFile: %v", err)
	}
	calls := tr.ToolCalls()
	calls[0].Name = "mutated"
	if tr.ToolCalls()[0].Name != "Bash" {
		t.Error("ToolCalls() must return a copy, not the internal slice")
	}
}

func TestParse_Error(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name  string
		input string
	}{
		{name: "not json", input: "not json at all\n"},
		{name: "bad assistant message", input: `{"type":"assistant","message":"string not object"}`},
		{name: "bad line after good line", input: `{"type":"system"}` + "\n{broken\n"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if _, err := trace.Parse(strings.NewReader(tc.input)); err == nil {
				t.Fatal("Parse: want error, got nil")
			}
		})
	}
}

func TestParseFile_Error(t *testing.T) {
	t.Parallel()
	if _, err := trace.ParseFile("../../testdata/does-not-exist.jsonl"); err == nil {
		t.Fatal("ParseFile: want error for missing file, got nil")
	}
}
