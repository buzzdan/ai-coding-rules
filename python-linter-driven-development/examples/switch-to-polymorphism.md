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

`Patch` is a `Protocol` with one method (`type()`) and four concrete
implementations, one per export destination. The converter interrogates each
concrete class and shovels its fields into a flat wire request:

```python
def from_update_arg(arg: UpdateArg) -> UpdateExportRequest:
    req = UpdateExportRequest(name=arg.name, type=str(arg.patch.type()))

    match arg.patch:
        case SplunkPatch() as p:
            if p.token is not None:
                req.token = str(p.token)
        case S3Patch() as p:
            req.s3_bucket = p.bucket
            req.s3_key = p.key
            req.s3_region = p.region
            if p.secret is not None:
                req.s3_secret = str(p.secret)
        case KafkaPatch() as p:
            req.kafka_topic = p.topic
            req.kafka_use_sasl = p.use_sasl
            req.kafka_sasl_username = p.username
            req.kafka_key_field = p.key_field
            if p.mechanism is not None:
                req.kafka_sasl_mechanism = str(p.mechanism)
            if p.password is not None:
                req.kafka_sasl_password = str(p.password)
        case SyslogPatch() as p:
            if p.mode is not None:
                req.syslog_mode = str(p.mode)
            if p.rfc is not None:
                req.syslog_rfc = str(p.rfc)
            if p.facility is not None:
                req.syslog_facility = str(p.facility)

    req.set_tls(arg.tls.expand())
    return req
```

Three defects, and only one of them is size:

- **The decision is asked twice (R11).** Whoever constructed `UpdateArg` already
  chose `KafkaPatch` — the value is typed as the protocol *because* that decision
  was made. The class-pattern `match` re-asks it. A type switch over a protocol the
  same package owns is always a second ask; "decide once at the edge" was violated
  the moment the cases appeared.
- **Ask-and-unpack.** The knowledge of *how a Splunk patch serializes* lives in the
  consumer, not on `SplunkPatch`. Each variant's wire mapping has no owner.
- **Silent growth failure.** Adding a `PubSubPatch` and forgetting this `match`
  passes ruff and ty and ships a request carrying only `name` and `type` — a
  runtime no-op with no checker or test to catch it unless someone remembers to
  write one. (Mixed in, an R3 note: the business flow — identity → payload → TLS —
  is buried under `is not None` plumbing repeated nine times.)

## The tempting wrong fix — extract each case body

The reflexive move is Extract Function per case:

```python
        case KafkaPatch() as p:
            _fill_kafka(req, p)
        case SyslogPatch() as p:
            _fill_syslog(req, p)
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

```python
class Patch(Protocol):
    """Implemented by each export-destination patch class.

    fill_update writes the destination-specific fields onto the wire request;
    shared fields (name, type, TLS) belong to the caller.
    """

    def type(self) -> ExportType: ...
    def fill_update(self, req: UpdateExportRequest) -> None: ...
```

The orchestrator collapses to a three-beat story (R3): identity, payload, TLS.

```python
def from_update_arg(arg: UpdateArg) -> UpdateExportRequest:
    req = UpdateExportRequest(name=arg.name, type=str(arg.patch.type()))
    arg.patch.fill_update(req)
    req.set_tls(arg.tls.expand())
    return req
```

Each destination owns its own mapping, in its own module (`splunk.py`, `s3.py`,
`kafka.py`, `syslog.py`):

```python
@dataclass(frozen=True)
class SplunkPatch:
    token: Secret | None = None

    def fill_update(self, req: UpdateExportRequest) -> None:
        req.token = opt_str(self.token)


@dataclass(frozen=True)
class S3Patch:
    bucket: str
    key: str
    region: str
    secret: Secret | None = None

    def fill_update(self, req: UpdateExportRequest) -> None:
        req.s3_bucket = self.bucket
        req.s3_key = self.key
        req.s3_region = self.region
        req.s3_secret = opt_str(self.secret)


@dataclass(frozen=True)
class KafkaPatch:
    topic: str
    use_sasl: bool
    username: str
    key_field: str
    mechanism: SASLMechanism | None = None
    password: Secret | None = None

    def fill_update(self, req: UpdateExportRequest) -> None:
        req.kafka_topic = self.topic
        req.kafka_use_sasl = self.use_sasl
        req.kafka_sasl_username = self.username
        req.kafka_key_field = self.key_field
        req.kafka_sasl_mechanism = opt_str(self.mechanism)
        req.kafka_sasl_password = opt_str(self.password)


@dataclass(frozen=True)
class SyslogPatch:
    mode: SyslogMode | None = None
    rfc: SyslogRFC | None = None
    facility: SyslogFacility | None = None

    def fill_update(self, req: UpdateExportRequest) -> None:
        req.syslog_mode = opt_str(self.mode)
        req.syslog_rfc = opt_str(self.rfc)
        req.syslog_facility = opt_str(self.facility)
```

One tiny helper kills the repeated `is not None` dance that padded every case:

```python
def opt_str(v: object | None) -> str | None:
    """Convert an optional enum or secret to its optional wire-string form."""
    return None if v is None else str(v)
```

An insert path is the same move: `fill_insert(self, req: InsertExportRequest)` on
the same protocol, and `from_insert_arg` becomes the same three-beat story.

## The payoffs

1. **A type check replaces a silent no-op.** A new `PubSubPatch` without
   `fill_update` no longer satisfies `Patch`, so `UpdateArg(patch=PubSubPatch(...))`
   fails ty at the moment of authorship — the strongest catch point Python has.
   (This is R11's exhaustiveness payoff without an `assert_never` arm: protocol
   satisfaction *is* the completeness proof.)
2. **Adding a destination is a new module, not an edit.** `from_update_arg` is frozen
   at three beats; the `match` version grows a hump per destination forever.
3. **The story survives (R3).** The orchestrator states *what* happens; each
   destination's *how* lives one level down, on the class that owns the data.
4. **The protocol is earned, and its set is recorded.** Four production
   implementations — this passes R6's earned-interface test (contrast: a protocol
   whose only second implementer is a test double). Python cannot seal a protocol
   the way a private method would elsewhere; the closed set is recorded instead,
   as a `PATCH_TYPES: tuple[type[Patch], ...] = (SplunkPatch, S3Patch, KafkaPatch,
   SyslogPatch)` that ty checks member by member, and a one-line test that every
   `ExportType` has a class in it.

## Fill, don't construct

Note the method signature: `fill_update(self, req: UpdateExportRequest) -> None`,
not `to_update_request(self) -> UpdateExportRequest`. The request carries fields the
patch does not own — `name`, `type`, TLS come from the surrounding argument. A
constructor method would either return a partial request the caller must merge
(field-by-field merging re-creates the original mess) or need the rest of the
argument passed in (the patch learns about its container). Filling keeps ownership
honest: the caller owns the shared fields, each patch owns its own.

## The boundary counter — when the switch must stay

This move has one precondition: **the package that owns the case types must also
legitimately own the output format.** Here both `Patch` and `updateExportRequest`
live in one package (a client whose API surface and wire format are the same
concern), so the method is natural.

When the patch types live in a shared API package and the wire request is one
consumer's private detail, the move is unavailable and wrong:

- Physically: a method on a domain class cannot take one consumer's private request
  type without importing that consumer — an import cycle, or the domain package
  depending on its client, which inverts the dependency.
- Architecturally: with multiple consumers (CLI, gateway, store), per-consumer
  `fill_<x>_request` methods accrete every consumer's serialization onto the domain
  classes — protocol pollution from the opposite direction.

In that situation the class-pattern `match` at the consumer's boundary is idiomatic
Python — the honest tax of keeping the domain package transport-ignorant, and
precisely the boundary-adapter exemption in R11's falsifying questions. Then, and
only then, the "tempting wrong fix" above becomes the right ceiling: shrink the
`match` to pure dispatch (one `_fill_kafka(req, p)`-style converter per case, zero
inline field-fiddling), close it with `case _: assert_never(patch)`, and stop.

Note this rejection is orthogonal to the juiciness rejection in
`anti-if-dispatch.md` Move 3: there the extraction *could* be written but isn't
worth it; here it *cannot* be written where it belongs, at any price.

The decision test, two questions in order:

1. *Why am I switching on type and unpacking fields?* → the behavior wants to live
   on the types (R11).
2. *Does the types' package own this output format?* → yes: interface method, the
   switch dies. No: thin dispatch switch, and the boundary earns its keep.
