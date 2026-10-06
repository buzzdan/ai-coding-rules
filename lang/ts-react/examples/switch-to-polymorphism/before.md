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
