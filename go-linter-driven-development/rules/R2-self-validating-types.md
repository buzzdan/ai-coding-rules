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

Compact excerpt from the Port case (`R1-primitive-obsession.md` has the full
three-stage study — extraction, placement, testing):

```go
// Port cannot exist out of range — the constructor is the only entry.
type Port struct {
    name   string
    number int32
}

func ParsePort(name string, number int32) (Port, error) {
    if number <= 0 || number > 65535 {
        return Port{}, fmt.Errorf("port %q: %d out of range 1-65535", name, number)
    }
    return Port{name: name, number: number}, nil
}
```

Before this type existed, `p.Port > 0 && p.Port <= 65535` was duplicated across two
loops at the use site. After, there is no `IsValid()` and no re-check anywhere: the
concept of a maybe-invalid port is deleted from downstream logic, not relocated.

The same pattern for a composed object — validate dependencies once, then trust:

```go
// ❌ every method defends
type UserService struct {
    Repo Repository // exported, might be nil
}

func (s *UserService) CreateUser(ctx context.Context, u User) error {
    if s.Repo == nil { // repeated in every method; forget one → panic
        return errors.New("repo is nil")
    }
    return s.Repo.Save(ctx, u)
}

// ✅ constructor validates once; methods trust the receiver
type UserService struct {
    repo Repository // private
}

func NewUserService(repo Repository) (*UserService, error) {
    if repo == nil {
        return nil, errors.New("repo is required")
    }
    return &UserService{repo: repo}, nil
}

func (s *UserService) CreateUser(ctx context.Context, u User) error {
    return s.repo.Save(ctx, u) // no checks — an invalid service cannot exist
}
```

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

- **Absence is a value too.** An *optional* collaborator — a logger, a metrics sink,
  an event writer, a clock — is not a nil-able field with a guard in every method.
  The default is a named do-nothing value the constructor supplies, the field is
  never nil, and every `if x.sink != nil` disappears. This is the Null Object of
  `R11-conditional-dispatch.md`; `io.Discard` is the standard library's: a real
  `io.Writer` whose `Write` reports every byte written, so `log.New(io.Discard, ...)`
  never branches on a missing destination. No parameter accepts nil to mean
  "default": `if sink == nil { sink = DiscardSink() }` inside the constructor keeps
  `NewReporter(nil)` legal and merely moves the nil-check — the default lives in an
  option or the caller passes the Null Object by name. Only a *required*
  collaborator (a store, a client the type cannot work without) is rejected in the
  constructor — doing nothing silently there would hide a bug.

  ```go
  // ❌ optional sink kept nil-able; every method re-asks the question
  func (r *Reporter) Record(e Event) {
      if r.sink != nil { r.sink.Write(e) }
  }

  // ✅ absence is a named value; no argument is ever nil
  func DiscardSink() *Sink { return NewSink(io.Discard) }

  func NewReporter(opts ...Option) *Reporter {
      r := &Reporter{sink: DiscardSink(), clock: time.Now}
      for _, o := range opts { o(r) }
      return r
  }
  // production: NewReporter(WithSink(sink)); tests: NewReporter(WithClock(fixed))
  ```

- **No defensive coding.** Check arguments in the constructor so that methods contain
  zero nil/emptiness checks on their own fields. A method validating its receiver is
  validation in the wrong place.

## Fix pattern

- **Add validating constructor**: make fields private, add `NewX`/`ParseX` returning
  `(X, error)`, migrate every literal-construction site through it.
- **Hoist method checks into the constructor**: collect the field checks scattered
  across methods, run them once at construction, delete them from the methods. For a
  *required* collaborator the hoisted check rejects nil; for an *optional* one it is
  the wrong move — use the next one.
- **Introduce Null Object** (`R11-conditional-dispatch.md`): an optional collaborator
  gets a *named* do-nothing value (`DiscardSink()`, a clock defaulting to `time.Now`)
  that the constructor supplies through an option or the caller passes explicitly;
  the field is non-nil by construction, no parameter accepts nil, and every guard in
  the methods is deleted. When the collaborator is a concrete type over an
  `io.Writer`, compose `io.Discard` into it; do not introduce an interface for the
  sake of the no-op (`R6-test-only-interfaces.md`).
- **Delete re-validation of composed types**: if every parameter is itself
  self-validating and there is nothing left to check, the constructor loses its
  `error` return entirely.
- **Replace nil returns**: `(X, error)` for failures, `(X, bool)` for absence — see
  the sentinel move in `R1-primitive-obsession.md`.
- Forward design of new types: @code-designing. The primitive extraction that usually
  precedes this rule: `R1-primitive-obsession.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Can the type exist in an invalid state?**
   Detection: for each new/changed type with invariants,
   `grep -rn '<Type>{' --include='*.go' . | grep -v _test.go` for literal
   construction outside its own file; check whether invariant-bearing fields are
   exported.
   Violation: any literal-construction site or exported invariant-bearing field
   gives callers a path around the constructor.

2. **Do methods re-check what the constructor should guarantee?**
   Detection: `grep -nE 'if [a-z][a-zA-Z]*\.[a-zA-Z]+ == nil|if len\([a-z][a-zA-Z]*\.[a-zA-Z]+\) == 0' <changed files>`
   inside method bodies.
   Violation: a method validating its own receiver's fields — the check belongs in
   the constructor. Decide which fix by asking whether the field is required or
   optional: a required collaborator is rejected in the constructor (Hoist method
   checks); an optional one (logger, sink, clock, metrics) gets a Null Object
   default there instead (Introduce Null Object, R11) — name both moves in the
   finding when the code does not say which the field is.

3. **Does a constructor re-validate a composed self-validating type?**
   Detection: read each `NewX`/`ParseX` in the diff; for every parameter whose type
   has its own constructor, grep the body for checks on that parameter.
   Violation: re-validating a value that could only ever exist valid.

4. **Does the type rely on upstream validation?**
   Detection: `grep -rn 'caller must\|assumes valid\|already validated' --include='*.go' .`;
   also flag exported fields consumed by logic in a package that defines no
   constructor for the type.
   Violation: any invariant enforced — or merely documented — outside the type
   itself.

5. **Does anything return or accept nil as a value?**
   Detection: `grep -nE 'return nil$|return nil, nil' <changed files>` — exempt
   `return nil, err` and `return val, nil`.
   Violation: nil returned for a non-error value, or a function nil-checking a
   parameter instead of the value being guaranteed by construction.

6. **Does any call site pass a nil literal as a non-error argument?**
   Detection: `grep -nE '\(nil[,)]|, nil[,)]' <changed files>` — exempt error
   positions (`return X, nil`), comparisons (`== nil`, `!= nil`), and stdlib
   idioms where nil is the documented sentinel (`http.NewRequest(..., nil)` for
   a bodyless request, marshaling a nil slice/map).
   Violation: nil passed where a value is expected. Q5 catches the return side
   and Q2 catches the callee that defends; this catches the caller when the
   callee does neither and simply panics later. Fix on the callee's side: make
   nil unrepresentable — a concrete non-pointer parameter, a validating
   constructor that rejects nil (see the UserService example above), or, for an
   optional collaborator, a Null Object default so the caller never has a reason
   to pass nil (`NewReporter(sink, nil, nil)` is the smell; R11).
