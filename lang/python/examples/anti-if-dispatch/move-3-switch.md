```python
# alert/severity.py — the ONLY site that inspects Severity
class Severity(Enum):
    INFO = auto()
    WARNING = auto()
    CRITICAL = auto()

    def color(self) -> str:
        match self:
            case Severity.INFO:
                return "blue"
            case Severity.WARNING:
                return "yellow"
            case Severity.CRITICAL:
                return "red"
        return ""
```
