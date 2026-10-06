  **The TypeScript shape.** A do-nothing object is stateless, so it can be a real
  default value: `const NULL_SINK: Sink = { write() {} }` at module level, the
  options property optional (`sink?: Sink`) and filled by a destructuring default,
  the field typed `Sink`, never `Sink | undefined`. `tsc` then rejects
  `new Reporter({ sink: null })` before it runs, and a caller that spells
  `sink: undefined` gets the default and R2 Q6's finding. A parameter typed
  `sink: Sink | undefined` with `this.sink = sink ?? NULL_SINK` inside the constructor
  keeps `undefined` legal and merely moves the check; it is allowed only when the
  default is genuinely expensive to build, and even then the field is typed without
  `undefined` and no method guards it.

  ```typescript
  // ❌ optional sink kept undefined-able; every method re-asks the question
  class Reporter {
    constructor(private readonly sink?: Sink) {}

    record(ev: UiEvent): void {
      if (this.sink !== undefined) {
        this.sink.write(ev, Date.now())
      }
    }
  }

  // ✅ absence is a named value; no argument is ever undefined
  export const NULL_SINK: Sink = { write() {} } // a real Sink whose write() discards
  export const SYSTEM_CLOCK: Clock = { now: () => Date.now() }

  interface ReporterOptions {
    readonly sink?: Sink
    readonly clock?: Clock
  }

  class Reporter {
    private readonly sink: Sink
    private readonly clock: Clock

    constructor({ sink = NULL_SINK, clock = SYSTEM_CLOCK }: ReporterOptions = {}) {
      this.sink = sink
      this.clock = clock
    }

    record(ev: UiEvent): void {
      this.sink.write(ev, this.clock.now()) // no guard anywhere
    }
  }
  // production: new Reporter({ sink: new HttpSink(apiClient) }); tests: new Reporter({ clock: fixedClock(t0) })
  ```
