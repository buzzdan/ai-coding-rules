**In Go:** `DiscardSink()` composing `io.Discard`, a clock that is `time.Now`;
`NewReporter(nil)` must not compile or must not exist. An option keeps its `Option`
signature, so `WithSink(nil)` compiles; it records the error and the constructor
returns `errors.Join` of what the options recorded.
