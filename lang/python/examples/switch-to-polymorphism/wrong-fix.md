```python
        case KafkaPatch() as p:
            _fill_kafka(req, p)
        case SyslogPatch() as p:
            _fill_syslog(req, p)
```
