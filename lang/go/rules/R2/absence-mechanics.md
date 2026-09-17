  **The Go shape.** `io.Discard` is the standard library's Null Object: a real
  `io.Writer` whose `Write` reports every byte written, so `log.New(io.Discard, ...)`
  never branches on a missing destination. `if sink == nil { sink = DiscardSink() }`
  inside the constructor keeps `NewReporter(nil)` legal and merely moves the nil-check.
  An option keeps the `Option` signature — no error return, or every call site
  becomes a chore — so `WithSink(nil)` is a call that compiles. It must not become a
  value that works: the option validates its argument and records the failure on the
  value under construction, and the constructor returns `errors.Join` of everything
  recorded after applying the options.

  ```go
  // ❌ optional sink kept nil-able; every method re-asks the question
  func (r *Reporter) Record(e Event) {
      if r.sink != nil { r.sink.Write(e) }
  }

  // ✅ absence is a named value; no argument is ever nil
  func DiscardSink() *Sink { return NewSink(io.Discard) }

  func WithSink(s *Sink) Option {
      return func(r *Reporter) {
          if s == nil {
              r.errs = append(r.errs, errors.New("reporter: WithSink(nil)"))
              return
          }
          r.sink = s
      }
  }

  func NewReporter(opts ...Option) (*Reporter, error) {
      r := &Reporter{sink: DiscardSink(), clock: time.Now}
      for _, o := range opts { o(r) }
      if err := errors.Join(r.errs...); err != nil { return nil, err }
      return r, nil
  }
  // production: NewReporter(WithSink(sink)); tests: NewReporter(WithClock(fixed))
  ```
