# Switch-to-Polymorphism Case: The Ever-Growing Export Switch

Demonstrates: R11, R6 (edges into R3)

Adapted from production code. `../examples/anti-if-dispatch.md` works R11's canonical
disease — a *raw* discriminator (a kind string) inspected at three sites. This case
is the type-switch sibling: a value that is **already polymorphic** (an interface,
dispatched once at construction) gets *un-dispatched* by a type switch that unpacks
its fields. The decision was made when the value was built; the switch asks it again.

Two things make this case worth its own file. First, the *obvious* refactoring
(extract each case body into a helper) is a trap — it shrinks the function but
preserves the disease. Second, the rejection axis here is different from
`anti-if-dispatch.md`'s Move 3: there the skeptic kills an extraction on juiciness
(one site, trivial variance); here the counter is **dependency direction** — a
situation where the dispatch move is physically unavailable and the switch is the
honest answer.

## Before — the hump that grows forever

`Patch` is an interface with one method (`Type()`) and four concrete
implementations, one per export destination. The converter interrogates each
concrete type and shovels its fields into a flat wire request:

```go
func fromUpdateArg(arg UpdateArg) updateExportRequest {
    req := updateExportRequest{Name: arg.Name}
    req.Type = arg.Patch.Type().String()

    switch p := arg.Patch.(type) {
    case SplunkPatch:
        if p.Token != nil {
            s := string(*p.Token)
            req.Token = &s
        }
    case S3Patch:
        req.S3Bucket = p.Bucket
        req.S3Key = p.Key
        req.S3Region = p.Region
        if p.Secret != nil {
            s := string(*p.Secret)
            req.S3Secret = &s
        }
    case KafkaPatch:
        req.KafkaTopic = p.Topic
        req.KafkaUseSASL = p.UseSASL
        req.KafkaSASLUsername = p.Username
        req.KafkaKeyField = p.KeyField
        if p.Mechanism != nil {
            m := p.Mechanism.String()
            req.KafkaSASLMechanism = &m
        }
        if p.Password != nil {
            s := string(*p.Password)
            req.KafkaSASLPassword = &s
        }
    case SyslogPatch:
        if p.Mode != nil {
            m := p.Mode.String()
            req.SyslogMode = &m
        }
        if p.RFC != nil {
            r := p.RFC.String()
            req.SyslogRFC = &r
        }
        if p.Facility != nil {
            f := p.Facility.String()
            req.SyslogFacility = &f
        }
    }

    req.setTLS(arg.TLS.Expand())
    return req
}
```

Three defects, and only one of them is size:

- **The decision is asked twice (R11).** Whoever constructed `UpdateArg` already
  chose `KafkaPatch` — the value is an interface *because* that decision was made.
  The type switch re-asks it. A type switch over an interface the same package owns
  is always a second ask; "decide once at the edge" was violated the moment the
  cases appeared.
- **Ask-and-unpack.** The knowledge of *how a Splunk patch serializes* lives in the
  consumer, not on `SplunkPatch`. Each variant's wire mapping has no owner.
- **Silent growth failure.** Adding a `PubSubPatch` and forgetting this switch
  compiles clean and ships a request carrying only `Name` and `Type` — a runtime
  no-op with no compiler, linter, or test to catch it unless someone remembers to
  write one. (Mixed in, an R3 note: the business flow — identity → payload → TLS —
  is buried under nil-deref-convert plumbing repeated nine times.)

## The tempting wrong fix — extract each case body

The reflexive move is Extract Function per case:

```go
case KafkaPatch:
    fillKafka(&req, p)
case SyslogPatch:
    fillSyslog(&req, p)
```

The function gets shorter and each case reads better — and nothing real changed.
The switch still exists, still grows a case per destination forever, and a
forgotten case is still a silent no-op. This is the ceiling of function
extraction, not the fix.

The falsifying question that breaks the frame: **why are we switching on type and
extracting data at all?** A type switch whose cases all do the same *kind* of work
(map my fields onto that struct) is behavior asking to live on the types. The
cased types already share an interface — the switch is a hand-rolled vtable.

## After — the interface owns the behavior

Add the fill behavior to the interface the concrete types already implement:

```go
// Patch is implemented by each export-destination patch type.
// fillUpdate writes the destination-specific fields onto the wire request;
// shared fields (Name, Type, TLS) belong to the caller.
type Patch interface {
    Type() ExportType
    fillUpdate(req *updateExportRequest)
}
```

The orchestrator collapses to a three-beat story (R3): identity, payload, TLS.

```go
func fromUpdateArg(arg UpdateArg) updateExportRequest {
    req := updateExportRequest{
        Name: arg.Name,
        Type: arg.Patch.Type().String(),
    }
    arg.Patch.fillUpdate(&req)
    req.setTLS(arg.TLS.Expand())
    return req
}
```

Each destination owns its own mapping, in its own file (`splunk.go`, `s3.go`,
`kafka.go`, `syslog.go`):

```go
func (p SplunkPatch) fillUpdate(req *updateExportRequest) {
    req.Token = optSecret(p.Token)
}

func (p S3Patch) fillUpdate(req *updateExportRequest) {
    req.S3Bucket = p.Bucket
    req.S3Key = p.Key
    req.S3Region = p.Region
    req.S3Secret = optSecret(p.Secret)
}

func (p KafkaPatch) fillUpdate(req *updateExportRequest) {
    req.KafkaTopic = p.Topic
    req.KafkaUseSASL = p.UseSASL
    req.KafkaSASLUsername = p.Username
    req.KafkaKeyField = p.KeyField
    req.KafkaSASLMechanism = optStringer(p.Mechanism)
    req.KafkaSASLPassword = optSecret(p.Password)
}

func (p SyslogPatch) fillUpdate(req *updateExportRequest) {
    req.SyslogMode = optStringer(p.Mode)
    req.SyslogRFC = optStringer(p.RFC)
    req.SyslogFacility = optStringer(p.Facility)
}
```

Two tiny helpers kill the repeated nil-deref-convert dance that padded every case:

```go
// optStringer converts an optional enum to its optional wire-string form.
func optStringer[T fmt.Stringer](v *T) *string {
    if v == nil {
        return nil
    }
    s := (*v).String()
    return &s
}

// optSecret unwraps an optional Secret for the wire request.
func optSecret(s *Secret) *string {
    if s == nil {
        return nil
    }
    v := string(*s)
    return &v
}
```

An insert path is the same move: `fillInsert(req *insertExportRequest)` on the same
interface, and `fromInsertArg` becomes the same three-beat story.

## The payoffs

1. **Compile-time enforcement replaces a silent no-op.** A new `PubSubPatch`
   without `fillUpdate` no longer builds. The growth failure mode moved from
   "runtime request missing its payload" to "compiler error at the moment of
   authorship" — the strongest possible catch point. (This is R11's exhaustiveness
   payoff without the `exhaustive` linter: interface satisfaction *is* the
   completeness proof.)
2. **Adding a destination is a new file, not an edit.** `fromUpdateArg` is frozen
   at three beats; the switch version grows a hump per destination forever.
3. **The story survives (R3).** The orchestrator states *what* happens; each
   destination's *how* lives one level down, on the type that owns the data.
4. **The interface is earned, and sealed.** Four production implementations — this
   passes R6's earned-interface test (contrast: an interface whose only second
   implementer is a test double). The unexported method is a bonus: no code outside
   the package can implement `Patch`, so the implementation set is closed and the
   compiler-enforcement guarantee in payoff 1 cannot be bypassed.

## Fill, don't construct

Note the method signature: `fillUpdate(req *updateExportRequest)`, not
`ToUpdateRequest() updateExportRequest`. The request carries fields the patch does
not own — `Name`, `Type`, TLS come from the surrounding argument. A constructor
method would either return a partial request the caller must merge (field-by-field
merging re-creates the original mess) or need the rest of the argument passed in
(the patch learns about its container). Filling keeps ownership honest: the caller
owns the shared fields, each patch owns its own.

## The boundary counter — when the switch must stay

This move has one precondition: **the package that owns the case types must also
legitimately own the output format.** Here both `Patch` and `updateExportRequest`
live in one package (a client whose API surface and wire format are the same
concern), so the method is natural.

When the patch types live in a shared API package and the wire request is one
consumer's private detail, the move is unavailable and wrong:

- Physically: an interface method cannot reference another package's unexported
  type, and exporting the wire type just to enable the method inverts the
  dependency.
- Architecturally: with multiple consumers (CLI, gateway, store), per-consumer
  `fill<X>Request` methods accrete every consumer's serialization onto the domain
  types — interface pollution from the opposite direction.

In that situation the type switch at the consumer's boundary is idiomatic Go — the
honest tax of keeping the domain package transport-ignorant, and precisely the
boundary-adapter exemption in R11's falsifying questions. Then, and only then, the
"tempting wrong fix" above becomes the right ceiling: shrink the switch to pure
dispatch (one `fillKafka(&req, p)`-style converter per case, zero inline
field-fiddling) and stop.

Note this rejection is orthogonal to the juiciness rejection in
`anti-if-dispatch.md` Move 3: there the extraction *could* be written but isn't
worth it; here it *cannot* be written where it belongs, at any price.

The decision test, two questions in order:

1. *Why am I switching on type and unpacking fields?* → the behavior wants to live
   on the types (R11).
2. *Does the types' package own this output format?* → yes: interface method, the
   switch dies. No: thin dispatch switch, and the boundary earns its keep.
