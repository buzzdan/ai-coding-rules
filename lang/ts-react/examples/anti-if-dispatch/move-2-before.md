```typescript
// ❌ before: if-chain in the middle of business logic
export function render(a: Alert, format: string): string {
  if (format === 'json') {
    return renderJson(a)
  }
  if (format === 'text') {
    return renderText(a)
  }
  return renderMarkdown(a) // silent default — is "yaml" markdown? nobody decided
}
```
