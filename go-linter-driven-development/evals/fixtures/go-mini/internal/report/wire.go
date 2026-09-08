package report

import "io"

// Announce writes the catalog event for name to w, if the catalog knows the
// device.
func Announce(w io.Writer, catalog *Catalog, name string) {
	sink := NewSink(w)
	rep := NewReporter(sink, nil, nil)
	if d := catalog.Find(name); d != nil {
		rep.Record(d.Event())
	}
}
