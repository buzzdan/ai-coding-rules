package report_test

import (
	"bytes"
	"testing"
	"time"

	"example.com/go-mini/internal/report"
)

func fixedClock() time.Time {
	return time.Date(2024, time.March, 1, 12, 0, 0, 0, time.UTC)
}

func TestReporter_RecordStampsWithClock(t *testing.T) {
	var buf bytes.Buffer
	rep := report.NewReporter(report.NewSink(&buf), fixedClock, &report.Options{FlushEvery: time.Minute})

	rep.Record(report.Event{Kind: "boot", Subject: "dev-1"})

	want := "2024-03-01T12:00:00Z boot dev-1\n"
	if got := buf.String(); got != want {
		t.Fatalf("recorded %q, want %q", got, want)
	}
	if rep.FlushEvery() != time.Minute {
		t.Fatalf("flush every %s, want 1m", rep.FlushEvery())
	}
}

func TestReporter_DefaultsWhenUnset(t *testing.T) {
	var buf bytes.Buffer
	rep := report.NewReporter(report.NewSink(&buf), nil, nil)

	rep.Record(report.Event{Kind: "boot", Subject: "dev-1"})

	if buf.Len() == 0 {
		t.Fatal("nothing recorded with default clock and options")
	}
	if rep.FlushEvery() != 0 {
		t.Fatalf("flush every %s, want 0", rep.FlushEvery())
	}
}

func TestReporter_WithoutSinkDropsEvents(t *testing.T) {
	rep := report.NewReporter(nil, fixedClock, nil)

	rep.Record(report.Event{Kind: "boot", Subject: "dev-1"}) // must not panic

	if rep.Sink != nil {
		t.Fatalf("sink %+v, want none", rep.Sink)
	}
}

func TestEvent_At(t *testing.T) {
	ev := report.Event{Kind: "boot"}.At(fixedClock())
	if !ev.Time().Equal(fixedClock()) {
		t.Fatalf("event time %s, want %s", ev.Time(), fixedClock())
	}
}

func TestCatalog_FindKnownDevice(t *testing.T) {
	cat := report.NewCatalog([]report.Device{{Name: "dev-1", Model: "m1"}, {Name: "dev-2", Model: "m2"}})

	d := cat.Find("dev-2")
	if d == nil {
		t.Fatal("dev-2 not found")
	}
	if d.Model != "m2" {
		t.Fatalf("model %q, want m2", d.Model)
	}
}

func TestCatalog_FindUnknownDevice(t *testing.T) {
	cat := report.NewCatalog([]report.Device{{Name: "dev-1", Model: "m1"}})

	if d := cat.Find("dev-9"); d != nil {
		t.Fatalf("found %+v for unknown name", *d)
	}
}

func TestAnnounce_WritesKnownDevice(t *testing.T) {
	var buf bytes.Buffer
	cat := report.NewCatalog([]report.Device{{Name: "dev-1", Model: "m1"}})

	report.Announce(&buf, cat, "dev-1")
	report.Announce(&buf, cat, "dev-9")

	if !bytes.HasSuffix(buf.Bytes(), []byte(" catalog dev-1/m1\n")) {
		t.Fatalf("announced %q", buf.String())
	}
	if bytes.Count(buf.Bytes(), []byte("\n")) != 1 {
		t.Fatalf("expected one line, got %q", buf.String())
	}
}
