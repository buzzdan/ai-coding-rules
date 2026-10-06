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

`Patch` is a discriminated union — four `readonly` object types, one per export
destination, sharing one member, `kind: ExportType`. The converter interrogates the
discriminant and shovels each shape's fields into a flat wire request:

```typescript
export function fromUpdateArg(arg: UpdateArg): UpdateExportRequest {
  const { patch } = arg
  const req: UpdateExportRequest = { name: arg.name, type: patch.kind }

  switch (patch.kind) {
    case 'splunk':
      if (patch.token !== undefined) {
        req.token = patch.token
      }
      break
    case 's3':
      req.s3Bucket = patch.bucket
      req.s3Key = patch.key
      req.s3Region = patch.region
      if (patch.secret !== undefined) {
        req.s3Secret = patch.secret
      }
      break
    case 'kafka':
      req.kafkaTopic = patch.topic
      req.kafkaUseSasl = patch.useSasl
      req.kafkaSaslUsername = patch.username
      req.kafkaKeyField = patch.keyField
      if (patch.mechanism !== undefined) {
        req.kafkaSaslMechanism = patch.mechanism
      }
      if (patch.password !== undefined) {
        req.kafkaSaslPassword = patch.password
      }
      break
    case 'syslog':
      if (patch.mode !== undefined) {
        req.syslogMode = patch.mode
      }
      if (patch.rfc !== undefined) {
        req.syslogRfc = patch.rfc
      }
      if (patch.facility !== undefined) {
        req.syslogFacility = patch.facility
      }
      break
  }

  applyTls(req, arg.tls)
  return req
}
```

Three defects, and only one of them is size:

- **The decision is asked twice (R11).** Whoever constructed `UpdateArg` already
  chose `KafkaPatch` — the value is typed as the union *because* that decision was
  made. The `switch (patch.kind)` re-asks it. A switch over a union the same module
  owns is always a second ask; "decide once at the edge" was violated the moment the
  cases appeared.
- **Ask-and-unpack.** The knowledge of *how a Splunk patch serializes* lives in the
  consumer, not on `SplunkPatch`. Each variant's wire mapping has no owner.
- **Silent growth failure.** Adding `'pubsub'` to `ExportType` and a `PubSubPatch` to
  the union and forgetting this `switch` passes `tsc` and ESLint — a statement
  `switch` with no `assertNever` arm is complete as far as either can tell — and
  ships a request carrying only `name` and `type`: a runtime no-op with no checker or
  test to catch it unless someone remembers to write one. (Mixed in, an R3 note: the
  business flow — identity → payload → TLS — is buried under `!== undefined` guards
  repeated nine times.)

## The tempting wrong fix — extract each case body

The reflexive move is Extract Function per case:

```typescript
    case 'kafka':
      fillKafka(req, patch)
      break
    case 'syslog':
      fillSyslog(req, patch)
      break
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

```typescript
/**
 * Implemented by each export-destination patch.
 *
 * fillUpdate writes the destination-specific fields onto the wire request;
 * shared fields (name, type, TLS) belong to the caller.
 */
export interface Patch {
  readonly kind: ExportType
  fillUpdate(req: UpdateExportRequest): void
}
```

In the before, the four shapes implemented this interface only structurally —
`{ readonly kind: ExportType }` was the member they shared, never written down.
Writing it down and adding `fillUpdate` to it is the move; the union goes, because
nothing narrows on `kind` any more. The implementations are objects made by a
factory, not classes: a patch has no identity and no state beyond the fields it
closes over.

The orchestrator collapses to a three-beat story (R3): identity, payload, TLS.

```typescript
export function fromUpdateArg(arg: UpdateArg): UpdateExportRequest {
  const req: UpdateExportRequest = { name: arg.name, type: arg.patch.kind }
  arg.patch.fillUpdate(req)
  applyTls(req, arg.tls)
  return req
}
```

Each destination owns its own mapping, in its own module (`splunkPatch.ts`,
`s3Patch.ts`, `kafkaPatch.ts`, `syslogPatch.ts`):

```typescript
export function splunkPatch(fields: Readonly<{ token?: Secret }>): Patch {
  return {
    kind: 'splunk',
    fillUpdate(req) {
      req.token = fields.token
    },
  }
}

export interface S3Fields {
  readonly bucket: string
  readonly key: string
  readonly region: string
  readonly secret?: Secret
}

export function s3Patch(fields: S3Fields): Patch {
  return {
    kind: 's3',
    fillUpdate(req) {
      req.s3Bucket = fields.bucket
      req.s3Key = fields.key
      req.s3Region = fields.region
      req.s3Secret = fields.secret
    },
  }
}

export interface KafkaFields {
  readonly topic: string
  readonly useSasl: boolean
  readonly username: string
  readonly keyField: string
  readonly mechanism?: SaslMechanism
  readonly password?: Secret
}

export function kafkaPatch(fields: KafkaFields): Patch {
  return {
    kind: 'kafka',
    fillUpdate(req) {
      req.kafkaTopic = fields.topic
      req.kafkaUseSasl = fields.useSasl
      req.kafkaSaslUsername = fields.username
      req.kafkaKeyField = fields.keyField
      req.kafkaSaslMechanism = fields.mechanism
      req.kafkaSaslPassword = fields.password
    },
  }
}

export interface SyslogFields {
  readonly mode?: SyslogMode
  readonly rfc?: SyslogRfc
  readonly facility?: SyslogFacility
}

export function syslogPatch(fields: SyslogFields): Patch {
  return {
    kind: 'syslog',
    fillUpdate(req) {
      req.syslogMode = fields.mode
      req.syslogRfc = fields.rfc
      req.syslogFacility = fields.facility
    },
  }
}
```

No helper is needed for the `!== undefined` dance that padded every case: the
request's destination fields are optional, `undefined` is the declared absence, and
`JSON.stringify` omits a member whose value is `undefined` — so each `fillUpdate`
assigns straight through and the nine guards go.

An insert path is the same move: `fillInsert(req: InsertExportRequest): void` on the
same interface, and `fromInsertArg` becomes the same three-beat story.

## The payoffs

1. **A type error replaces a silent no-op.** A new `pubSubPatch` factory that returns
   `Patch` without `fillUpdate` does not typecheck, and neither does an object handed
   to `UpdateArg.patch` without one — the growth failure moved from "runtime request
   missing its payload" to "`tsc` error at the moment of authorship", the strongest
   catch point TypeScript has. (This is R11's exhaustiveness payoff without an
   `assertNever` arm: interface satisfaction *is* the completeness proof.)
2. **Adding a destination is a new module, not an edit.** `fromUpdateArg` is frozen
   at three beats; the `switch` version grows a hump per destination forever.
3. **The story survives (R3).** The orchestrator states *what* happens; each
   destination's *how* lives one level down, on the object that owns the data.
4. **The interface is earned, and its set is recorded.** Four production
   implementations — this passes R6's earned-interface test (contrast: an interface
   whose only second implementer is a test double). TypeScript cannot seal a
   structural interface — any object with a `kind` and a `fillUpdate` is a `Patch` —
   so the closed set is recorded instead: `kind` is typed `ExportType`, so no factory
   can invent a destination, and `PATCH_FACTORIES`, the object of the four factories
   declared `satisfies Record<ExportType, unknown>`, fails to compile the moment an
   `ExportType` member has no factory.

## Fill, don't construct

Note the method signature: `fillUpdate(req: UpdateExportRequest): void`, not
`toUpdateRequest(): UpdateExportRequest`. The request carries fields the patch does
not own — `name`, `type`, TLS come from the surrounding argument. A constructor
method would either return a partial request the caller must spread together
(`{ ...base, ...patch.toUpdateRequest() }` re-creates the original mess one level up
and hides which side owns a colliding key) or need the rest of the argument passed in
(the patch learns about its container). Filling keeps ownership honest: the caller
owns the shared fields, each patch owns its own.

## The boundary counter — when the switch must stay

This move has one precondition: **the package that owns the case types must also
legitimately own the output format.** Here both `Patch` and `updateExportRequest`
live in one package (a client whose API surface and wire format are the same
concern), so the method is natural.

When the patch types live in a shared API package and the wire request is one
consumer's private detail, the move is unavailable and wrong:

- Physically: a method on a type from the shared client module
  (`src/services/exportsApi.ts`, imported by three pages) cannot take one page's
  private `UpdateExportRequest` without that module importing from `src/pages/` — an
  import cycle at best, and in any case the shared client depending on its consumer,
  which inverts the dependency.
- Architecturally: with multiple consumers (the exports page, cluster settings, the
  onboarding wizard), per-consumer `fill<X>Request` methods accrete every page's
  serialization onto the shared types — interface pollution from the opposite direction.

In that situation the `switch (patch.kind)` at the page's boundary is idiomatic
TypeScript — the honest tax of keeping the shared client transport-ignorant, and
precisely the boundary-adapter exemption in R11's falsifying questions. `Patch` stays
the discriminated union it was in the before; narrowing on `kind` is what the page
needs. Then, and only then, the "tempting wrong fix" above becomes the right ceiling:
shrink the page's `fillUpdate(req, patch)` to pure dispatch (one `fillKafka(req,
patch)`-style converter per case, zero inline field-fiddling), close it with
`default: assertNever(patch)`, and stop.

Note this rejection is orthogonal to the juiciness rejection in
`anti-if-dispatch.md` Move 3: there the extraction *could* be written but isn't
worth it; here it *cannot* be written where it belongs, at any price.

The decision test, two questions in order:

1. *Why am I switching on type and unpacking fields?* → the behavior wants to live
   on the types (R11).
2. *Does the types' package own this output format?* → yes: interface method, the
   switch dies. No: thin dispatch switch, and the boundary earns its keep.
