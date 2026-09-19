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
