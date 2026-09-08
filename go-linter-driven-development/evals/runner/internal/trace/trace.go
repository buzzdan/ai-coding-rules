// Package trace parses the `claude -p --output-format stream-json --verbose`
// event stream into the few facts the graders need: the ordered tool calls,
// the final assistant message, and the cost/duration/turn counters from the
// terminal `result` event.
//
// Event shapes (recorded in testdata/trace-smoke.jsonl):
//
//	{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{...}}]}}
//	{"type":"assistant","message":{"content":[{"type":"text","text":"DONE"}]}}
//	{"type":"user","message":{"content":[{"type":"tool_result","content":"..."}]}}
//	{"type":"result","subtype":"success","result":"DONE","total_cost_usd":0.06,"duration_ms":4466,"num_turns":2,"is_error":false}
//
// Everything else (system, stream_event, rate_limit_event, ...) is skipped.
package trace

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
)

// ToolCall is one tool_use block from an assistant message. Input is the
// compact JSON encoding of the tool's input object, so graders can regex over
// e.g. `"file_path":"services/x.go"`.
type ToolCall struct {
	Name  string `json:"name"`
	Input string `json:"input"`
}

// Trace is the parsed event stream of one headless claude run.
type Trace struct {
	toolCalls   []ToolCall
	lastText    string
	results     []string // one final text per result event
	complete    bool
	isError     bool
	subtype     string
	costUSD     float64
	durationMS  int64
	numTurns    int
	segments    int
	raw         string
	eventsCount int
}

type envelope struct {
	Type         string          `json:"type"`
	Subtype      string          `json:"subtype"`
	Message      json.RawMessage `json:"message"`
	Result       string          `json:"result"`
	TotalCostUSD float64         `json:"total_cost_usd"`
	DurationMS   int64           `json:"duration_ms"`
	NumTurns     int             `json:"num_turns"`
	IsError      bool            `json:"is_error"`
}

type assistantMessage struct {
	Content []contentBlock `json:"content"`
}

type contentBlock struct {
	Type  string          `json:"type"`
	Name  string          `json:"name"`
	Text  string          `json:"text"`
	Input json.RawMessage `json:"input"`
}

// ParseFile reads and parses a stream-json trace from disk.
func ParseFile(path string) (Trace, error) {
	f, err := os.Open(path)
	if err != nil {
		return Trace{}, fmt.Errorf("trace: open %s: %w", path, err)
	}
	defer func() { _ = f.Close() }() // read-only handle; nothing to report on close
	return Parse(f)
}

// Parse reads a stream-json trace. A trace without a terminal `result` event
// (timeout, crash) still parses; Complete reports false for it.
func Parse(r io.Reader) (Trace, error) {
	var raw bytes.Buffer
	tr := Trace{}
	reader := bufio.NewReader(io.TeeReader(r, &raw))
	for lineNo := 1; ; lineNo++ {
		line, err := reader.ReadBytes('\n')
		if len(bytes.TrimSpace(line)) > 0 {
			if perr := tr.consume(line); perr != nil {
				return Trace{}, fmt.Errorf("trace: line %d: %w", lineNo, perr)
			}
		}
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return Trace{}, fmt.Errorf("trace: read: %w", err)
		}
	}
	tr.raw = raw.String()
	return tr, nil
}

func (t *Trace) consume(line []byte) error {
	var ev envelope
	if err := json.Unmarshal(line, &ev); err != nil {
		return fmt.Errorf("decode event: %w", err)
	}
	t.eventsCount++
	switch ev.Type {
	case "assistant":
		return t.consumeAssistant(ev.Message)
	case "result":
		t.consumeResult(ev)
	}
	return nil
}

func (t *Trace) consumeAssistant(message json.RawMessage) error {
	var msg assistantMessage
	if err := json.Unmarshal(message, &msg); err != nil {
		return fmt.Errorf("decode assistant message: %w", err)
	}
	for _, block := range msg.Content {
		switch block.Type {
		case "tool_use":
			t.toolCalls = append(t.toolCalls, ToolCall{Name: block.Name, Input: compact(block.Input)})
		case "text":
			if strings.TrimSpace(block.Text) != "" {
				t.lastText = block.Text
			}
		}
	}
	return nil
}

// consumeResult folds one result event in. A session that schedules its own
// wakeups emits one result event per segment: total_cost_usd is cumulative
// across them, while duration_ms and num_turns are per segment and are summed.
// The last segment's subtype and error flag stand for the run.
func (t *Trace) consumeResult(ev envelope) {
	t.complete = true
	t.segments++
	t.results = append(t.results, ev.Result)
	t.subtype = ev.Subtype
	t.isError = ev.IsError
	t.costUSD = ev.TotalCostUSD
	t.durationMS += ev.DurationMS
	t.numTurns += ev.NumTurns
}

func compact(input json.RawMessage) string {
	if len(input) == 0 {
		return "{}"
	}
	var buf bytes.Buffer
	if err := json.Compact(&buf, input); err != nil {
		return string(input)
	}
	return buf.String()
}

// ToolCalls returns the tool_use blocks in the order the assistant issued them.
func (t Trace) ToolCalls() []ToolCall {
	out := make([]ToolCall, len(t.toolCalls))
	copy(out, t.toolCalls)
	return out
}

// LastMessage is what the agent said as its final message. With one result
// event that is its `result` text; when the agent scheduled wakeups and the
// session ran several segments, it is every segment's final text joined, in
// order, since a user would have seen each one as an assistant message and
// the report may sit in any of them. Falls back to the last non-empty
// assistant text block when no result event exists.
func (t Trace) LastMessage() string {
	finals := make([]string, 0, len(t.results))
	for _, r := range t.results {
		if strings.TrimSpace(r) != "" {
			finals = append(finals, r)
		}
	}
	if len(finals) > 0 {
		return strings.Join(finals, "\n\n")
	}
	return t.lastText
}

// Complete reports whether a terminal result event was seen.
func (t Trace) Complete() bool { return t.complete }

// IsError reports the result event's is_error flag.
func (t Trace) IsError() bool { return t.isError }

// Subtype is the result event's subtype (success, error_max_turns, ...).
func (t Trace) Subtype() string { return t.subtype }

// CostUSD is total_cost_usd from the result event.
func (t Trace) CostUSD() float64 { return t.costUSD }

// DurationMS is duration_ms from the result event.
func (t Trace) DurationMS() int64 { return t.durationMS }

// NumTurns is num_turns summed over every result event.
func (t Trace) NumTurns() int { return t.numTurns }

// Segments is the number of result events seen: 1 for a plain run, more when
// the agent scheduled wakeups and the session resumed itself.
func (t Trace) Segments() int { return t.segments }

// Events is the number of JSON events that were parsed.
func (t Trace) Events() int { return t.eventsCount }

// Raw is the full JSONL text, for `target: trace` regex graders.
func (t Trace) Raw() string { return t.raw }
