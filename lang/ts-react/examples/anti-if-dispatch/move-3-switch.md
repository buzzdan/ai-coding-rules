```typescript
// alerts/severity.ts — the ONLY site that inspects the Severity union
export function severityColor(s: Severity): string {
  switch (s) {
    case 'info':
      return 'blue'
    case 'warning':
      return 'yellow'
    case 'critical':
      return 'red'
  }
  return ''
}
```
