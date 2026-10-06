#### ✅ Inline Runnable Example
```typescript
// Create validated types — each throws RangeError on invalid input
const userId = parseUserId('usr_12345')
const email = parseEmail('alice@example.com')

// Create and use the service
const service = new UserService({ repo, notifier })
await service.createUser({ id: userId, email, name: 'Alice' })
```
In a JSDoc the same lines are an `@example` block; nothing runs it, so the colocated
test that executes the same calls (or the Storybook story, where the repository
already has Storybook — the plugin never adds it) is what keeps it honest.
