**In TypeScript:** `const NULL_SINK: Sink = { write() {} }` bound once as a module
constant (an object literal typed as the collaborator — never a class with one no-op
method, R6), and a clock that is `const SYSTEM_CLOCK: Clock = { now: () => new Date() }`
the same way; the parameter is typed `Sink`, never `Sink | undefined`, and the default
is a destructuring default — `constructor({ sink = NULL_SINK }: ReporterOptions)`,
`function useReporter({ sink = NULL_SINK }: Readonly<ReporterOptions>)` — so the
stored field is `Sink`, no method guards it, and the caller never has a reason to pass
`undefined`. In React an optional callback prop (`onOpenEvents?`) is legitimate when
the component means something without it; when every render path guards it, the prop
is required, or takes the Null Object in the same destructuring default.
