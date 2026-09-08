// Package report writes fleet events to an operator-visible sink.
package report

import (
	"fmt"
	"io"
	"time"
)

// Reporter is a reporter.
type Reporter struct {
	Sink  *Sink            // exported, might be nil — "optional"
	Clock func() time.Time // nil means "use time.Now"

	flushEvery time.Duration
}

// Options are the reporter options.
type Options struct {
	FlushEvery time.Duration
}

// Event is a reported event.
type Event struct {
	Kind    string
	Subject string

	at time.Time
}

// At returns the event stamped with t.
func (e Event) At(t time.Time) Event {
	e.at = t
	return e
}

// Time returns when the event was recorded.
func (e Event) Time() time.Time {
	return e.at
}

// Sink is where events are written.
type Sink struct {
	w io.Writer
}

// NewSink creates a new Sink.
func NewSink(w io.Writer) *Sink {
	return &Sink{w: w}
}

// Write writes the event.
func (s *Sink) Write(ev Event) {
	_, _ = fmt.Fprintf(s.w, "%s %s %s\n", ev.at.UTC().Format(time.RFC3339), ev.Kind, ev.Subject)
}

// NewReporter creates a new Reporter. Callers pass nil for "no options" and
// "default clock".
func NewReporter(sink *Sink, clock func() time.Time, opts *Options) *Reporter {
	if opts == nil {
		opts = &Options{}
	}
	if clock == nil {
		clock = time.Now
	}
	return &Reporter{Sink: sink, Clock: clock, flushEvery: opts.FlushEvery}
}

// Record records the event.
func (r *Reporter) Record(ev Event) {
	if r.Sink == nil { // forget this once → panic
		return
	}
	if r.Clock == nil {
		r.Clock = time.Now
	}
	r.Sink.Write(ev.At(r.Clock()))
}

// FlushEvery returns how often the sink is flushed.
func (r *Reporter) FlushEvery() time.Duration {
	return r.flushEvery
}
