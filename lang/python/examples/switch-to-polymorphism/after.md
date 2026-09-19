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
