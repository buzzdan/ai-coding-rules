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

In the before, the four shapes implemented this interface only structurally — `{
readonly kind: ExportType }` was the member they shared, never written down. Writing
it down and adding `fillUpdate` to it is the move; the union goes, because nothing
narrows on `kind` any more. The implementations are objects made by a factory, not
classes: a patch has no identity and no state beyond the fields it closes over.

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
