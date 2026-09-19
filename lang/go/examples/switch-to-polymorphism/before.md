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
