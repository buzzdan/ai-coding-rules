# R2 — Self-Validating Types

## Principle

A type validates its own invariants in its constructor — the only way to obtain a
value — and every method thereafter trusts the receiver. Validation ownership never
sits upstream: a type that relies on callers to have validated for it is not
self-validating, whatever its fields look like.

## Why

Constructor validation makes invalid values unrepresentable. Without it, every method
must defend against bad state, forgetting one check is a latent panic, and the
defensive noise buries the actual logic. With it, nil-checks, emptiness checks, and
range checks vanish from the entire downstream call graph — the payoff compounds with
every method and every caller. Errors also surface at the boundary where the bad data
entered, carrying context, instead of deep in an unrelated call stack.

## Canonical example

{{include "rules/R2/canonical-example.md"}}

## Design guidance

- **Constructors are the only entry.** `ParseX(raw) (X, error)` for values built from
  unstructured input, `NewX(deps) (X, error)` for composed objects (constructors may
  carry other names — any public function returning the type qualifies). Fields stay
  private: a struct-literal or zero-value path around the constructor is a hole in
  the type.

- **Validation ownership.** A type never relies on upstream validation. "The handler
  already checked it" is not an invariant — handlers change, new call sites appear,
  and the type outlives both. A comment reading "caller must ensure X" is the
  signature of a type that does not own itself: move that sentence into the
  constructor as code.

  ```go
  // ❌ relies on callers to validate
  type Config struct {
      Host string // every caller must remember: if host == "" ...
      Port int
  }

  // ✅ owns its own validation
  func NewConfig(host string, port int) (Config, error) {
      if host == "" { return Config{}, errors.New("host required") }
      if port <= 0 || port > 65535 { return Config{}, errors.New("invalid port") }
      return Config{host: host, port: port}, nil
  }
  ```

- **Trust composed values.** Once you hold a `Port`, it is valid — never re-check it
  downstream, and never re-validate it in a composing constructor. Each type owns
  exactly its own invariants:

  ```go
  // ❌ re-validates what Host already guarantees
  func NewAddress(host Host, port Port) (Address, error) {
      if host == "" { return Address{}, errors.New("host required") } // Host owns this
      return Address{host: host, port: port}, nil
  }

  // ✅ trusts composed self-validating types — nothing left to check, no error to return
  func NewAddress(host Host, port Port) Address {
      return Address{host: host, port: port}
  }
  ```

- **Nil is not a value.** Never return nil for non-error values — return an error
  instead. Error positions are exempt: `nil, err` and `val, nil` are fine because the
  real value is the other one. Never pass nil into a function; then functions do not
  check parameters for nil.

- **No defensive coding.** Check arguments in the constructor so that methods contain
  zero nil/emptiness checks on their own fields. A method validating its receiver is
  validation in the wrong place.

## Fix pattern

- **Add validating constructor**: make fields private, add `NewX`/`ParseX` returning
  `(X, error)`, migrate every literal-construction site through it.
- **Hoist method checks into the constructor**: collect the field checks scattered
  across methods, run them once at construction, delete them from the methods.
- **Delete re-validation of composed types**: if every parameter is itself
  self-validating and there is nothing left to check, the constructor loses its
  `error` return entirely.
- **Replace nil returns**: `(X, error)` for failures, `(X, bool)` for absence — see
  the sentinel move in `R1-primitive-obsession.md`.
- Forward design of new types: @code-designing. The primitive extraction that usually
  precedes this rule: `R1-primitive-obsession.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.
{{include "rules/R2/falsifying-questions.md"}}
