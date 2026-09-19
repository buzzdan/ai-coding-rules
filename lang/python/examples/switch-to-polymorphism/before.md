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
